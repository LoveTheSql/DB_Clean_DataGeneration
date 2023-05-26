-- =============================================
-- Author:		David Speight
-- Create date: 20210929
-- EXEC dbo.DataCleaning
-- 20230425:  Updated:
--						dbo.FullNames AS DG ON RIGHT(C.',@curIDColumnName,',6) = DG.ID
--						changed to --
--						dbo.FullNames AS DG ON RIGHT(CONVERT(VARCHAR(50),C.',@curIDColumnName,'),6) = DG.ID
-- EXEC dbo.DataCleaning 'qatest8@fakeweb.com','DEVOPS','Myname@mycompany.com',1,0,1
-- =============================================
CREATE     PROCEDURE [dbo].[DataCleaning]
@email varchar(100) = 'qatest@fakeweb.com',					-- set this to the email you want to replace all email addresses in the database with.
@AgentProfile varchar(100) = 'MyAgentMailProfile',			-- SQL Agent profile account to be used to send failure alert email from.
@RecipientEmail varchar(200) = 'Myname@mycompany.com',		-- Email address to send the failure alert to.
@DebuggerON bit = 0,
@LocalHostIsQa int = 0,									-- WARNING:  This will RUN, even on PROD if set to 1.
@CleanTemporalTables bit = 1								-- This DISABLES the HISTORY table, DELETES all history records allows the main table to be cleaned without records logged.
AS
BEGIN

SET NOCOUNT ON;

DECLARE @Servername VARCHAR(250);
-- This is needed for databases running on AWS RDS since  @@SERVERNAME returns the EC2 instnace name and not the actual server anme.
SELECT @Servername = ClusterName from ServerAnalysis.Analysis.PerfLocation where ServerName = @@SERVERNAME;

-- ONLY PERFORM THIS TASK ON DEV or QA
IF (CHARINDEX('DEV',@Servername,1) + CHARINDEX('QA',@Servername,1)  + CHARINDEX('IMPL',@Servername,1)   + @LocalHostIsQa) = 0
BEGIN
	PRINT 'THIS ACTION CANNOT BE PERFORMED ON A PRODUCTION DATABASE!'
	SELECT 'THIS ACTION CANNOT BE PERFORMED ON A PRODUCTION DATABASE!'
	RAISERROR( 'THIS ACTION CANNOT BE PERFORMED ON A PRODUCTION DATABASE!',0,1) WITH NOWAIT;
RETURN;
END
ELSE
BEGIN

DECLARE @ParentAuditKey int;
DECLARE @currAuditKey int;
DECLARE @PkgGUID uniqueidentifier;
DECLARE @iCurrID INT;
DECLARE @iLoopMaxID INT;
DECLARE @SqlDynamic NVARCHAR(1000); 
DECLARE @curDatabase varchar(200);
DECLARE @curSchemaName varchar(50);
DECLARE @curTableName varchar(200);
DECLARE @curColumnName varchar(200);
DECLARE @curGenderRefColumnName varchar(200);
DECLARE @curIDColumnName varchar(200);
DECLARE @curDataType varchar(50);
DECLARE @curUsesGenerationDb bit;
DECLARE @curTablePath varchar(605);
DECLARE @curRowCount int;
DECLARE @dtStartTime datetime;
DECLARE @iRandom int;

		
SELECT @PkgGUID = NEWID();

-- Start Audit and error logging
INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
VALUES (1, 'DATA CLEANING: DBClean-Start','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'P');
SELECT @ParentAuditKey = SCOPE_IDENTITY();
UPDATE dbo.DimAudit  SET ParentAuditKey = @ParentAuditKey WHERE AuditKey = @ParentAuditKey;

-- GET A LIST OF ALL DATABASES, TABLES, COLUMNS that need cleaning
-- This is a scaled down list from the table in the DB with only ACTIVE items and ONLINE databases.
DECLARE @CleaningColumns AS TABLE (
									[ID] [int] IDENTITY(1,1) NOT NULL,	-- This is the TEMP ID we use for looping.
									[CleaningColumnID] [int] NULL,		-- This is the REAL ID in the database, used for debugging only.
									[DatabaseName] [varchar](200) NULL,
									[SchemaName] [varchar](50) NULL,
									[TableName] [varchar](200) NULL,	
									[ColumnName] [varchar](200) NULL,
									[GenderRefColumnName] [varchar](200) NULL,
									[IDColumnName] [varchar](200) NULL,
									[DataType] [varchar](50) NULL,
									[IsActive] [bit] NULL,
									[UsesGenerationDb] [bit] NULL)

DECLARE @tDatabases AS TABLE (		[ID] [int] IDENTITY(1,1) NOT NULL,
									[DatabaseName] [varchar](200) NULL)

INSERT INTO @CleaningColumns
SELECT [ID], [DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb]
FROM dbo.CleaningColumns
WHERE DatabaseName IN (SELECT name from master.sys.databases where state_desc = 'ONLINE')  -- Only process items when database is online
	AND IsActive = 1
ORDER BY [DatabaseName], [SchemaName], [TableName], [ColumnName]

INSERT INTO @tDatabases (DatabaseName)
SELECT DISTINCT DatabaseName
FROM @CleaningColumns;

/*
==========================================
VERIFICATION SECTION INITIAL
==========================================
*/		

-- Reset Loop Counters
SELECT	@iCurrID	= 0, 
		@iLoopMaxID = MAX(ID) FROM @CleaningColumns;
-- RESET TABLE
TRUNCATE TABLE dbo.CleaningVerificationSample;
-- LOOP to load sample ORIGINAL data into the Verification table.
	
WHILE @iCurrID < @iLoopMaxID
BEGIN
	SELECT	@iCurrID	=	@iCurrID + 1, @SqlDynamic='';
	SELECT	@SqlDynamic	=	CONCAT(
			'INSERT INTO dbo.CleaningVerificationSample (CleaningColumnID, OriginalSampleData, RowID) 
			SELECT TOP(1) ',CleaningColumnID, ', CONVERT(NVARCHAR(500),[',ColumnName,']), ', IDColumnName,    
			' FROM ',DatabaseName,'.',SchemaName,'.',TableName,'  WHERE LEN(CONVERT(VARCHAR(500),[',ColumnName,'])) > 0;')
	FROM @CleaningColumns
	WHERE ID = @iCurrID

	BEGIN TRY
		EXEC(@SqlDynamic);
		--  Audit and error logging
		SELECT @curRowCount = @@ROWCOUNT;
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Load Sample Data','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'Y');
	END TRY
	BEGIN CATCH
		--  Audit and error logging
		SELECT @curRowCount = @@ROWCOUNT;
		PRINT(@SqlDynamic);
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Load Sample Data','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N');
	END CATCH
END;

/*
==========================================
TRIGGER SECTION INITIAL
==========================================
*/
-- FIND ALL ACTIVE TRIGGERS
TRUNCATE TABLE dbo.CleaningTriggers
SELECT	@iCurrID	= 0, 
		@iLoopMaxID = MAX(ID) FROM @tDatabases;

WHILE @iCurrID < @iLoopMaxID
BEGIN
	SELECT	@iCurrID		=	@iCurrID + 1, @SqlDynamic='', @curDatabase='';
	SELECT	@curDatabase	=	DatabaseName
	FROM @tDatabases
	WHERE ID = @iCurrID;
	-- Create statements to enable/disable triggers, load them into the temp table
	SELECT	@SqlDynamic		=	CONCAT(
	'INSERT INTO dbo.CleaningTriggers (TriggerDisableTsql, TriggerEnableTsql) 
	SELECT (''ALTER TABLE [',@curDatabase,'].[''+s.name+''].[''+t.name+''] DISABLE TRIGGER [''+',@curDatabase,'.dbo.sysobjects.name+''];'') AS TriggerDisableTsql,
	(''ALTER TABLE [',@curDatabase,'].[''+s.name+''].[''+t.name+''] ENABLE TRIGGER [''+',@curDatabase,'.dbo.sysobjects.name+''];'') AS TriggerEnableTsql
	FROM ',@curDatabase,'.dbo.sysobjects 
	INNER JOIN ',@curDatabase,'.sys.tables t ON sysobjects.parent_obj = t.object_id 
	INNER JOIN ',@curDatabase,'.sys.schemas s ON t.schema_id = s.schema_id 
	WHERE ',@curDatabase,'.dbo.sysobjects.type = ''TR'' 
	AND ',@curDatabase,'.dbo.sysobjects.name NOT IN (SELECT name FROM ',@curDatabase,'.sys.triggers WHERE is_disabled = 1)');


	BEGIN TRY
		EXEC(@SqlDynamic);
		--  Audit and error logging
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Triggers Loaded','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'Y');
	END TRY
	BEGIN CATCH
		--  Audit and error logging
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Triggers Load ERROR','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'N');
	END CATCH

END;

-- DISABLE THE TRIGGERS
SELECT	@iCurrID	= 0, 
		@iLoopMaxID = MAX(ID) FROM dbo.CleaningTriggers;

WHILE @iCurrID < @iLoopMaxID
BEGIN
	SELECT	@iCurrID		=	@iCurrID + 1, @SqlDynamic='', @curDatabase='';
	SELECT	@SqlDynamic		=	TriggerDisableTsql
	FROM	dbo.CleaningTriggers
	WHERE ID = @iCurrID;

	BEGIN TRY
		EXEC(@SqlDynamic);
		--  Audit and error logging
		SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Disabled', @PkgGUID, getutcdate(), 'Y');
	END TRY
	BEGIN CATCH
		--  Audit and error logging
		SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Disabled ERROR', @PkgGUID, getutcdate(), 'N');
	END CATCH
END;


/*
==========================================
TEMPORAL TABLES INITIAL - Added May 2023
==========================================
*/

If @CleanTemporalTables = 1
BEGIN


	DECLARE @tTemporalHistory AS TABLE
		(	ID INT NOT NULL IDENTITY(1,1), 
			DatabaseName varchar(250), 
			TableSchema varchar(100), 
			TableName varchar(250),
			HistorySchema varchar(100), 
			HistoryTableName varchar(250));
	DECLARE @tCount int = 0;
	DECLARE @ttSql varchar(2500);
	DECLARE @dtSql varchar(2500);

	INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
	VALUES (@ParentAuditKey, 'DATA CLEANING: Begin-Temporal','Deleting History Tables', @PkgGUID, getutcdate(), 'Y');

	INSERT INTO @tTemporalHistory
	SELECT DatabaseName, TableSchema, TableName, HistorySchema, HistoryTableName
	FROM dbo.CleaningTemporal 
	WHERE IsActive = 1;

	SELECT @tCount = MAX(ID) FROM @tTemporalHistory;

	WHILE @tCount > 0
	BEGIN
		SELECT	@ttSql = CONCAT('ALTER TABLE ',DatabaseName,'.',TableSchema,'.',TableName,' SET (SYSTEM_VERSIONING = OFF);'),
				@dtSql = CONCAT('DELETE FROM ',DatabaseName,'.',HistorySchema,'.',HistoryTableName,' WHERE 1 = 1;')
		FROM @tTemporalHistory
		WHERE ID = @tCount;

		BEGIN TRY
			EXEC(@ttsql);
			WAITFOR DELAY '00:00:01';
		END TRY
		BEGIN CATCH
			PRINT(@ttsql)
			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
			VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Unlink Failure', @PkgGUID, getutcdate(), 'N');
		END CATCH

		BEGIN TRY
			EXEC(@dtsql);
		END TRY
		BEGIN CATCH
			PRINT(@dtsql)
			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
			VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Data Delete Failure', @PkgGUID, getutcdate(), 'N');
		END CATCH


		SELECT @tCount = @tCount - 1, @ttSql = '';
	END;

END;


/*
==========================================
MAIN SECTION FOR CLEANING THE DATA
==========================================
*/
--  Audit and error logging
INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
VALUES (@ParentAuditKey, 'DATA CLEANING: Begin-Tables','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'Y');
		
SELECT	@iCurrID	= 0, 
		@iLoopMaxID = MAX(ID) FROM @CleaningColumns;
		
----- [MAIN LOOP BEGIN]
WHILE @iCurrID < @iLoopMaxID   
BEGIN			
	SELECT	@iCurrID				=	@iCurrID + 1,
			@SqlDynamic				=	'', 
			@curDatabase			=	'',
			@curSchemaName			=	'',
			@curTableName			=	'',
			@curColumnName			=	'',
			@curGenderRefColumnName	=	'',
			@curIDColumnName		=	'',
			@curDataType			=	'',
			@curUsesGenerationDb	=	0,
			@curTablePath			=	'',
			@curRowCount			=	0;

	SELECT	@curDatabase			=	DatabaseName,
			@curSchemaName			=	SchemaName,
			@curTableName			=	TableName,
			@curColumnName			=	ColumnName,
			@curGenderRefColumnName	=	GenderRefColumnName,
			@curIDColumnName		=	IDColumnName,
			@curDataType			=	DataType,
			@curUsesGenerationDb	=	UsesGenerationDb,
			@curTablePath			=	CONCAT('[',DatabaseName,'].[',SchemaName,'].[',TableName,']'),
			@dtStartTime			=	getutcdate(),
			@iRandom				=	LEFT(DATEPART(s,getutcdate()),1)  -- Num 0-9 with 0-5 hit most often
	FROM @CleaningColumns
	WHERE ID = @iCurrID;

	-- BATCH 01 UPDATES: UserName: 
	IF @curDataType IN ('USERNAME','USER','LOGIN','LOGON','USR','USRNAME')
	BEGIN
		-- SELECT @SqlDynamic	=	

		IF @curGenderRefColumnName = 'Email'
		BEGIN
			-- This condition CLEANS for a LOGIN/USERNAME scenario that use an EMAIL address for logon.
			SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C 
				SET [',@curColumnName,'] =	CONCAT('''',LEFT(DG.Lname,',@iRandom,'),LEFT(DG.Fname,2),''@web.com'','''') 
				FROM ',@curTablePath,' AS C 
				INNER JOIN 
				dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)) = DG.ID
				WHERE LEN(C.[',@curColumnName,']) > 0;');

		END
		ELSE
		BEGIN
			SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	CONCAT('''',LEFT(DG.Lname,',@iRandom,'),LEFT(DG.Fname,2),'''')
				FROM ',@curTablePath,' AS C
				INNER JOIN
				dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)) = DG.ID
				WHERE LEN(C.[',@curColumnName,']) > 0;');
		END;
	END;

	-- BATCH 2 UPDATES: Password
	IF @curDataType IN ( 'PASSWORD','PASS','PWD','PWORD','PWRD','PSWD' )
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	CONCAT('''',LEFT(DG.Lname,2),LEFT(DG.Fname,2),dbo.fnPasswordGenerator(7),'''')
				FROM ',@curTablePath,' AS C
				INNER JOIN
				dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)) = DG.ID
				WHERE LEN(C.[',@curColumnName,']) > 1;');
	END;
			
	-- BATCH 03 UPDATES: Email
	IF @curDataType IN ( 'EMAIL','MAIL','E-MAIL','WEBMAIL')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT('UPDATE ',@curTablePath,' SET [',@curColumnName,'] = ''',@email,''' WHERE LEN([',@curColumnName,']) > 1;');
	END;

	-- BATCH 04 UPDATES: DOB as datetime
	IF @curDataType IN ( 'DOB','DATE','DOD','BIRTH','BIRTHDATE','BIRTHDAY','DEATH','DAY','CREATED','UPDATED' )
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	(CASE WHEN [',@curColumnName,'] IS NULL THEN [',@curColumnName,'] ELSE dbo.udfRandomDOBgenerator()  END)
				FROM ',@curTablePath,' AS C
				INNER JOIN
				dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)) = DG.ID
				WHERE C.[',@curColumnName,'] IS NOT NULL;');
	END;

	-- BATCH 05 UPDATES: [SSNID] SSN & Other IDs as Numberic -- MASK all but last 2
	IF @curDataType IN ( 'SSNID', 'SSNINT')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	(999999900+',@iRandom,'+CONVERT(int,RIGHT([',@curColumnName,'],2))) 
				FROM ',@curTablePath,' AS C
				INNER JOIN
				dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)) = DG.ID
				WHERE C.[',@curColumnName,'] IS NOT NULL;');
	END;


	-- BATCH 06 UPDATES: [SSNCHAR]  SSN & Other IDs as varchar 
	IF @curDataType IN ('SSN', 'SSNCHAR' )
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	(''999999',@iRandom,'''+RIGHT([',@curColumnName,'],2) ) 
				FROM ',@curTablePath,' AS C
				INNER JOIN
				dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)) = DG.ID
				WHERE LEN(C.[',@curColumnName,']) > 0;');
	END;

	-- BATCH 07 UPDATES: [FIRSTNAME] FirstName with/without Gender Column
	IF @curDataType IN ('FIRSTNAME','FNAME','FIRST')
	BEGIN
		IF LEN(@curGenderRefColumnName) > 1
		BEGIN
			SELECT @SqlDynamic	=	
				CONCAT( -- FEMALE GENDER
					'UPDATE C
					SET [',@curColumnName,'] =	DG.FName
					FROM ',@curTablePath,' AS C
					INNER JOIN
					dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)+1000000+',@iRandom,') = DG.ID 
					WHERE (C.[',@curColumnName,'] IS NOT NULL AND LEN(C.[',@curColumnName,']) > 0)							
						AND (CONVERT(varchar(6), C.[',@curGenderRefColumnName,']) IN (''1'',''F'',''female'') ) ;')
				+
				CONCAT( -- MALE GENDER
					'UPDATE C
					SET [',@curColumnName,'] =	DG.FName
					FROM ',@curTablePath,' AS C
					INNER JOIN
					dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)+',@iRandom,') = DG.ID 
					WHERE (C.[',@curColumnName,'] IS NOT NULL AND LEN(C.[',@curColumnName,']) > 0)
						AND (CONVERT(varchar(6), C.[',@curGenderRefColumnName,']) NOT IN (''1'',''F'',''female'') OR C.[',@curGenderRefColumnName,'] IS NULL) ;');
		END
		ELSE
		BEGIN
			SELECT @SqlDynamic	=	
				CONCAT( -- RANDOM GENDER
					'UPDATE C
					SET [',@curColumnName,'] =	DG.FName
					FROM ',@curTablePath,' AS C
					INNER JOIN
					dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)+',@iRandom,') = DG.ID    
					WHERE C.[',@curColumnName,'] IS NOT NULL AND LEN(C.[',@curColumnName,']) > 0;');
		END
	END;


	-- BATCH 09 UPDATES: [LASTNAME]
	IF @curDataType IN ( 'LASTNAME','LNAME','LAST')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	DG.LName
				FROM ',@curTablePath,' AS C
				INNER JOIN
				dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)+',@iRandom,') = DG.ID
				WHERE LEN(C.[',@curColumnName,']) > 0;');
	END;

	-- BATCH 10 UPDATES: [FULLNAME]
	IF @curDataType = 'FULLNAME'
	BEGIN
		IF LEN(@curGenderRefColumnName) > 1
		BEGIN
			-- FEMALE NAMES
			SELECT @SqlDynamic	=	
				CONCAT( -- FEMALE NAMES
					'UPDATE C
					SET [',@curColumnName,'] =	CONCAT('''',LEFT(DG.Fname,18),'' '',LEFT(DG.Lname,30),'''')
					FROM ',@curTablePath,' AS C
					INNER JOIN
					dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)+1000000+',@iRandom,') = DG.ID 
					WHERE (LEN(C.[',@curColumnName,']) > 0)
						AND (CONVERT(varchar(6), C.[',@curGenderRefColumnName,']) IN (''1'',''F'',''female'') );')
				+
				CONCAT( -- MALE NAMES
					'UPDATE C
					SET [',@curColumnName,'] =	CONCAT('''',LEFT(DG.Fname,18),'' '',LEFT(DG.Lname,30),'''')
					FROM ',@curTablePath,' AS C
					INNER JOIN
					dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)+',@iRandom,') = DG.ID 
					WHERE (LEN(C.[',@curColumnName,']) > 0)
						AND (CONVERT(varchar(6), C.[',@curGenderRefColumnName,']) NOT IN (''1'',''F'',''female'') OR C.[',@curGenderRefColumnName,'] IS NULL);');
		END
		ELSE
		BEGIN  -- RANDOM GENDER
			SELECT @SqlDynamic	=	CONCAT(
					'UPDATE C
					SET [',@curColumnName,'] =	CONCAT('''',LEFT(DG.Fname,18),'' '',LEFT(DG.Lname,30),'''')
					FROM ',@curTablePath,' AS C
					INNER JOIN
					dbo.FullNames AS DG ON (RIGHT(C.',@curIDColumnName,',6)+',@iRandom,') = DG.ID   
					WHERE LEN(C.[',@curColumnName,']) > 0;');
		END;
	END;

	-- BATCH 11 UPDATES: [ADDRESS1]
	IF @curDataType IN ('ADDRESS','ADDRESS1','ADR','ADDR','ADDR1')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	dbo.udfRandomAddress1([',@curColumnName,'])
				FROM ',@curTablePath,' AS C
				WHERE LEN(C.[',@curColumnName,']) > 0;');
	END;

	--BATCH 12 UPDATES: [ADDRESS2] also 3/4 use UNIT+ ID#
	IF @curDataType IN ('ADDRESS2','ADDRESS3','ADDRESS4')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	dbo.udfRandomAddress2(LEFT([',@curColumnName,'],30))
				FROM ',@curTablePath,' AS C
				WHERE LEN(C.[',@curColumnName,']) > 0;')
	END;	


	-- BATCH 13 UPDATES: [TRUNCATE] Tables to delete all data
	IF @curDataType IN ( 'TRUNCATE','REMOVE','CLEAN','DELETE','X','CLEAR','BLANK')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT('UPDATE ',@curTablePath,' SET [',@curColumnName,'] = ''CLEANED'' WHERE [',@curColumnName,'] IS NOT NULL;');
	END;

	-- BATCH 14 UPDATES: [PHONE]
	IF @curDataType IN ('PHONE','PHONECHAR')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	dbo.udfRandomPhone([',@curColumnName,'])
				FROM ',@curTablePath,' AS C
				WHERE LEN(C.[',@curColumnName,']) > 0;')
	END;


	-- BATCH 15a UPDATES: [PHONEINT]
	IF @curDataType IN ('PHONEINT','PHONEID')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	REPLACE(dbo.udfRandomPhone([',@curColumnName,']),''-'','''')
				FROM ',@curTablePath,' AS C
				WHERE C.[',@curColumnName,'] IS NOT NULL;');
	END;

	-- BATCH 15b UPDATES: [PHONENUM]
	IF @curDataType IN ('PHONENUM','PHONE10')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	CONCAT('''',(  RIGHT((REPLACE(dbo.udfRandomPhone([',@curColumnName,']),''-'','''')),10)   ),'''')
				FROM ',@curTablePath,' AS C
				WHERE C.[',@curColumnName,'] IS NOT NULL;');
	END;

	-- BATCH 16 UPDATES: [PINn]
	IF LEFT(@curDataType,3) = 'PIN'
	BEGIN    -- ie PIN4 = 4  PIN12 = 12
		SELECT @curDataType	=	(CASE WHEN LEN(@curDataType) > 3 THEN @curDataType ELSE 'PIN4' END);
		SELECT @SqlDynamic	=	CONCAT(
				'UPDATE C
				SET [',@curColumnName,'] =	dbo.udfRandomPin(',REPLACE(@curDataType,'PIN',''),')  
				FROM ',@curTablePath,' AS C
				WHERE C.[',@curColumnName,'] IS NOT NULL;');
	END;

	BEGIN TRY
		EXEC(@SqlDynamic);
		SELECT @curRowCount = @@ROWCOUNT;
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, RIGHT(CONCAT(@curTablePath,'.',@curColumnName),50),'DATA CLEANING: Clean Rows', @PkgGUID, @dtStartTime, getutcdate(), @curRowCount,  'Y');
	END TRY
	BEGIN CATCH 
		SELECT @curRowCount = @@ROWCOUNT;
		PRINT(@SqlDynamic);
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT],  [ExecStopDT], [ErrorRowCnt], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, RIGHT(CONCAT(@curTablePath,'.',@curColumnName),50),'DATA CLEANING: Clean Rows', @PkgGUID, @dtStartTime,  getutcdate(), @curRowCount, 'N');
	END CATCH;

----- [MAIN LOOP END]
END; --------- MAIN LOOP END



/*
			==========================================
				TRIGGER SECTION RE-ENABLE
			==========================================
*/
-- ENABLE THE TRIGGERS
SELECT	@iCurrID	= 0, 
		@curRowCount = 0,  -- Used to count errors here
		@iLoopMaxID = MAX(ID) FROM dbo.CleaningTriggers;

WHILE @iCurrID < @iLoopMaxID
BEGIN
	SELECT	@iCurrID		=	@iCurrID + 1, @SqlDynamic='', @curDatabase='';
	SELECT	@SqlDynamic		=	TriggerEnableTsql
	FROM	dbo.CleaningTriggers
	WHERE ID = @iCurrID;

	BEGIN TRY
		EXEC(@SqlDynamic);
		--  Audit and error logging
		SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Enabled', @PkgGUID, getutcdate(), 'Y');
	END TRY
	BEGIN CATCH
		--  Audit and error logging
		SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Enabled ERROR', @PkgGUID, getutcdate(), 'N');
		SELECT @curRowCount =	@curRowCount + 1;
	END CATCH
END;

IF @curRowCount = 0 
BEGIN
	IF @DebuggerON = 0
	BEGIN
		TRUNCATE TABLE dbo.CleaningTriggers;
	END;
END
ELSE
BEGIN
	SELECT @curRowCount = 0 ;
END;

		
/*
==========================================
VERIFICATION SECTION FINAL
==========================================
*/		

-- Reset Loop Counters
SELECT	@iCurrID	= 0, 
		@iLoopMaxID = MAX(ID) FROM dbo.CleaningVerificationSample;
-- LOOP to load sample ORIGINAL data into the Verification table.	
WHILE @iCurrID < @iLoopMaxID
BEGIN
	SELECT	@iCurrID	=	@iCurrID + 1, @SqlDynamic='';
	SELECT	@SqlDynamic	=	CONCAT(
								'UPDATE V
								SET ChangedSampleData = CONVERT(NVARCHAR(500),[',C.ColumnName,'])
								FROM dbo.CleaningVerificationSample AS V
								INNER JOIN ',C.DatabaseName,'.',C.SChemaName,'.',C.TableName,' AS E ON V.RowID = E.',C.IDColumnName,'
								WHERE V.ID = ',@iCurrID,';')
	FROM dbo.CleaningVerificationSample V
	INNER JOIN dbo.CleaningColumns C ON V.CleaningColumnID = C.ID  -- @CleaningColumns changed to dbo.CleaningColumns
	WHERE V.ID = @iCurrID;

	BEGIN TRY
		EXEC(@SqlDynamic);
		--  Audit and error logging
		SELECT @curRowCount = @@ROWCOUNT;
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Sample Data','Verification Updated', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'Y');
	END TRY
	BEGIN CATCH
		--  Audit and error logging
		SELECT @curRowCount = @@ROWCOUNT;
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Sample Data','Ver Update failure', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N');
	END CATCH
	SELECT @curRowCount = 0;
END;

UPDATE dbo.CleaningVerificationSample
SET Pass =	(CASE	
					WHEN  ChangedSampleData = 'CLEANED' THEN 1
					WHEN  OriginalSampleData = ChangedSampleData THEN 0 
					ELSE 1 END)

-- Do not truncate table if Errors persist.
-- Bug fix 20230501
UPDATE dbo.CleaningVerificationSample
SET Pass=1
WHERE RowID = 0;

SELECT @curRowCount = COUNT(*) FROM dbo.CleaningVerificationSample WHERE Pass = 0;
IF @curRowCount = 0
BEGIN
	IF @DebuggerON = 0
	BEGIN
		TRUNCATE TABLE dbo.CleaningVerificationSample;
	END;
END
ELSE
BEGIN
	INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd])
	VALUES (@ParentAuditKey, 'DATA CLEANING: Verification Errors','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N');
END;


-- Success / Failure Actions
IF ((SELECT COUNT(*) FROM dbo.DimAudit WHERE ParentAuditKey=@ParentAuditKey AND SuccessfulProcessingInd='N')=0)
BEGIN
	UPDATE dbo.DimAudit  
	SET ExecStopDT = getutcdate(),SuccessfulProcessingInd = 'Y' 
	WHERE	(AuditKey = @ParentAuditKey );
	-- ELSE send email with Failed Steps table
END
ELSE
BEGIN
	UPDATE dbo.DimAudit  
	SET ExecStopDT = getutcdate(),SuccessfulProcessingInd = 'N' 
	WHERE	(AuditKey = @ParentAuditKey );

	DECLARE @Body NVARCHAR(2500) = '';
	SELECT @Body = CONCAT(@Servername, ' Data cleaning steps failed.');

	BEGIN TRY
		EXEC msdb.dbo.sp_send_dbmail
			@profile_name = @AgentProfile,
			@recipients = @RecipientEmail,
			@body = @Body,
			@subject = @Body ,
			@body_format = 'HTML'; 
	END TRY
	BEGIN CATCH
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Email Errors','FAILED to send email alert', @PkgGUID, getutcdate(), getutcdate(), 0,  'N');
	END CATCH;
END;

END;
IF @DebuggerON = 1
BEGIN
		
SELECT * from dbo.CleaningVerificationSample		
SELECT * FROM dbo.DimAudit WHERE ParentAuditKey = @ParentAuditKey ORDER BY 1 DESC;
SELECT * from dbo.CleaningTriggers;
END;

END





