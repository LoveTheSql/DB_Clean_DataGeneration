
/*   CLEANING SOLUTION REVISIONS JULY  2023  


Run this script for the latest Stored Proc changes.

INCLUDES PREVIOUS BUG FIXES

1. Function that created PHONE NUMBER will no longer include dashes. This will allow full 10 digit numbers to work with varchar(10) datatype.
2. Initial VALIDATOR GENERATOR will also check the existing live val;idator table for active entries when listing DATAGBASES to re/evaluate.
3. PREVIEW and SUGGESTION sprocs will now eliminate any DATE item when the DataType DATE is set to FALSE.  This will remove some false positives such as FIRSTcreateDATE or LASTmodifiedDATE that were being flagged as FISTNAME/LASTNAME.
4. New SPROCS added to ewasily ADD/REMOVE individual items from the solutuion.

NEW FIXES
1. Add SqlStatmeent column to audit table, to be used when an error is thrown
2. Fixed view that pulls laest log, to ignore the POST tasks if that was the latest entry, and instead pulls the latest FULL cleaning details.
3. This fix adds/updates 2 new datatypes: CLEARDATE and ZERO. CLEARDATE will set all dates in the table.column to '1901-01-01' and ZERO will set all numeric values in the table.column to zero (0).
4. A table to EXCLUDE specific ROWS by ID has been added. This feature is only available using the new sproc: DataCleaningBatched

DataCleaningBatched includes these changes:
-- Sets up batches so that all rows in the same table are grouped together.
-- Executes a SINGLE update statement for a table instead of multiple updates for each column.
-- Excludes Rows in the CleaningRow Exclude table
-- Logs the Tsql statement attempted in the dimAudit table

*/



CREATE TABLE [dbo].[CleaningRowExclude](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[DatabaseName] [varchar](200) NULL,
	[SchemaName] [varchar](50) NULL,
	[TableName] [varchar](200) NULL,
	[IDColumnName] [varchar](200) NULL,
	[ExcludeID] [bigint] NOT NULL,
	[IsActive] [bit] NOT NULL,	
 CONSTRAINT [PK_CleaningRowExclude] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


USE [DB_Clean_DataGeneration]
GO

ALTER TABLE dbo.DimAudit ADD  [SqlStatement] VARCHAR(2000) NULL;
ALTER TABLE dbo.DimAudit ALTER COLUMN [TableName] VARCHAR(250) NULL;
ALTER TABLE dbo.DimAudit ALTER COLUMN [PkgName] VARCHAR(250) NULL;
ALTER TABLE dbo.CleaningColumns ADD  [HasExclusionCsIdList] BIT NULL;
ALTER TABLE dbo.CleaningTemporal ADD ReLink bit null;
GO
UPDATE dbo.CleaningTemporal set ReLink =1;
GO


UPDATE [dbo].[CleaningDataType]
SET KeyWordList = 'REMOVE,NOTE,CLEAN,BLANK,OLD,X,'
WHERE ID = 13;
UPDATE [dbo].[CleaningDataType]
SET DataTypeName = 'CLEARDATE', IsActive=1, KeyWordList = 'CLEAR,CLEARDATE,'
WHERE ID = 52;

UPDATE [dbo].[CleaningDataType]
SET DataTypeName = 'ZERO', IsActive=1, KeyWordList = 'ZERO,RESETNUM,ZERONUMBER,'
WHERE ID = 53;

INSERT INTO [dbo].[CleaningDataType]
(DataTypeName,IsActive,IsPrefered,KeyWordList,IsInt)
SELECT 'ZERO',1,0,'ZERO,RESETNUM,ZERONUMBER,',1
WHERE (SELECT MAX(ID) FROM  [dbo].[CleaningDataType] )= 53;

UPDATE [dbo].[CleaningDataType] SET IsActive=0 WHERE ID >53;

select * FROM  [dbo].[CleaningDataType] 


USE [DB_Clean_DataGeneration]
GO

/****** Object:  UserDefinedFunction [dbo].[udfRandomPhone]    Script Date: 6/9/2023 1:00:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER     FUNCTION [dbo].[udfRandomPhone] 
(@Phone varchar(50)) 
RETURNS varchar(50)
AS 
BEGIN 
	DECLARE @NewPhone varchar(50);
	DECLARE @KeepPreDigits int;
	DECLARE @PhoneLen int;
	SELECT	@Phone			=	dbo.fnRemoveNonNumericChar(@Phone);
	SELECT	@PhoneLen		=	LEN(@Phone);
	SELECT	@KeepPreDigits	=	(CASE WHEN LEFT(@Phone,1) IN (0,1) THEN 4 ELSE 3 END);
	SELECT	@NewPhone		=	(CASE	WHEN LEN(@Phone) > 0 THEN  (CONCAT(LEFT(@Phone,@KeepPreDigits),CONVERT(varchar(8),dbo.udfRandomPIN(3)), CONVERT(varchar(8),dbo.udfRandomPIN(4)))) ELSE @Phone END);
	RETURN	RIGHT(@NewPhone,@PhoneLen);
END 

GO



/****** Object:  UserDefinedFunction [dbo].[tfnFullNameGet]    Script Date: 7/11/2023 12:03:48 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE  OR ALTER     FUNCTION [dbo].[tfnFullNameGet]
(	
@ID bigint, @gender char(1), @Offset int
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT	@ID AS ID, Fname, Lname, Gender
	FROM	dbo.FullNames
	WHERE	ID = (CASE	WHEN @gender in ('F','1') THEN RIGHT((@ID+@Offset),6)+1000000
						ELSE	RIGHT((@ID+@Offset),6) END)
)
GO









CREATE OR ALTER VIEW [dbo].[GetVerificationDetails]
AS

	-- Note: If Debugging WAS NOT set to =1 when cleanign sproc ran, there may be no data in this table.
	SELECT TOP(10000) C.DatabaseName, C.SchemaName, C.TableName, C.ColumnName, S.*
	FROM dbo.CleaningVerificationSample S
	INNER JOIN dbo.CleaningColumns C on S.CleaningColumnID = C.ID
	ORDER BY C.DatabaseName, C.SchemaName, C.TableName, C.ColumnName


GO

/****** Object:  View [dbo].[GetVerificationDetails]    Script Date: 7/11/2023 11:53:56 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE OR ALTER  VIEW [dbo].[GetVerificationDetails]
AS

	-- Note: If Debugging WAS NOT set to =1 when cleaning sproc ran, there may be no data in this table.
	SELECT TOP(10000) C.DatabaseName, C.SchemaName, C.TableName, C.ColumnName, S.*
	FROM dbo.CleaningVerificationSample S
	INNER JOIN dbo.CleaningColumns C on S.CleaningColumnID = C.ID
	ORDER BY C.DatabaseName, C.SchemaName, C.TableName, C.ColumnName;


GO




/****** Object:  View [dbo].[GetLogLatest]    Script Date: 6/19/2023 7:38:54 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER VIEW [dbo].[GetLogLatest]
AS

	SELECT TOP(10000) AuditKey, ParentAuditKey, TableName, PkgName, ExecStartDT, ExecStopDT,  UpdateRowCnt, ErrorRowCnt,  SuccessfulProcessingInd, SqlStatement
	FROM  dbo.dimaudit
	WHERE ParentAuditKey = (SELECT MAX(ParentAuditKey) 
							FROM dbo.dimaudit WHERE TableName NOT LIKE 'DATA CLEANING: PostClean%')
	ORDER BY  AuditKey desc;

GO













USE [DB_Clean_DataGeneration]
GO

/****** Object:  StoredProcedure [dbo].[GeneratePreview]    Script Date: 6/9/2023 12:59:50 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER      PROCEDURE [dbo].[GeneratePreview]
AS
BEGIN

	DECLARE @LookupType as Table (ID INT NOT NULL IDENTITY(1,1), DataTypeName VARCHAR(50), Keyword VARCHAR(50), IsInt bit);
	DECLARE @DateOn INT;

	INSERT INTO @LookupType
	select c.DataTypeName, s.value, c.IsInt
	FROM dbo.CleaningDataType c
	CROSS APPLY string_split(c.keywordList,',') s 
	WHERE c.IsActive=1 and LEN(S.value) > 1;

	SELECT  @DateOn = COUNT(*) FROM @LookupType WHERE DataTypeName = 'DATE';

	SELECT *
	FROM 
		(
		SELECT 
				v.ID, v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName,v.ObjectTypeName,v.Status,
				v.DataType, v.GeneratorDataType, l.DataTypeName, l.Keyword, l.Isint,
				ROW_NUMBER() OVER(PARTITION BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName ORDER BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName) As ROWID
		FROM	dbo.Validator v
				INNER JOIN @LookupType l 
					ON (v.ColumnName LIKE l.Keyword+'%')
					and (l.isint = 1 or LEFT(v.datatype,7) NOT IN (
					'bigint','binary','bit','decimal','float','geograp','geometr','hierarc','image','int','money','numeric','real','smallin','smallmo','sql_var','tinyint'
					)) 
				LEFT JOIN dbo.ValidatorAlwaysIgnore ai ON v.DatabaseName = ai.DatabaseName and v.SchemaName = ai.SchemaName and v.TableName = ai.TableName and v.ColumnName= ai.ColumnName
		WHERE	(v.IsActive=1 and v.ObjectTypeName='column' and v.Status = 'standard' and ai.ColumnName is null)
				AND ((@DateOn = 0 AND NOT (v.ColumnName LIKE '%date%' AND  l.DataTypeName != 'DATE')) OR @DateOn = 1)  -- This excludes FIRSTcreatedDATE, LASTmodifiedDATE, etc.
		) q
	WHERE q.Rowid = 1
	ORDER BY DatabaseName,SchemaName,TableName,ColumnName;


END
GO

/****** Object:  StoredProcedure [dbo].[GenerateSuggestions]    Script Date: 6/9/2023 12:59:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER      PROCEDURE [dbo].[GenerateSuggestions]
AS
BEGIN


DECLARE @LookupType as Table (ID INT NOT NULL IDENTITY(1,1), DataTypeName VARCHAR(50), Keyword VARCHAR(50), IsInt bit);
DECLARE @DateOn INT;
DECLARE @StartID INT;
SELECT @StartID = MAX(ID)
FROM  dbo.CleaningColumns;

	INSERT INTO @LookupType
	select c.DataTypeName, s.value, c.IsInt
	FROM dbo.CleaningDataType c
	CROSS APPLY string_split(c.keywordList,',') s 
	WHERE c.IsActive=1 and LEN(S.value) > 1;

	SELECT  @DateOn = COUNT(*) FROM @LookupType WHERE DataTypeName = 'DATE';

	INSERT INTO dbo.CleaningColumns
	([DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb])
	SELECT q.DatabaseName,q.SchemaName,q.TableName,q.ColumnName,NULL,NULL,DataTypeName,1,1
	FROM 
		(
		SELECT 
				v.ID, v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName,v.ObjectTypeName,v.Status,
				v.DataType, v.GeneratorDataType, 
				ISNULL(v.GeneratorDataType,l.DataTypeName) AS DataTypeName, -- This overrides the AUTO selection
				l.Keyword, l.Isint,
				ROW_NUMBER() OVER(PARTITION BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName ORDER BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName) As ROWID
		FROM	dbo.Validator v
				INNER JOIN @LookupType l 
					ON (v.ColumnName LIKE l.Keyword+'%')
					and (l.isint = 1 or LEFT(v.datatype,7) NOT IN (
					'bigint','binary','bit','decimal','float','geograp','geometr','hierarc','image','int','money','numeric','real','smallin','smallmo','sql_var','tinyint'
					)) 
				LEFT JOIN dbo.ValidatorAlwaysIgnore ai ON v.DatabaseName = ai.DatabaseName and v.SchemaName = ai.SchemaName and v.TableName = ai.TableName and v.ColumnName= ai.ColumnName
		WHERE	(v.IsActive=1 and v.ObjectTypeName='column' and v.Status = 'standard' and ai.ColumnName is null)
				AND ((@DateOn = 0 AND NOT (v.ColumnName LIKE '%date%' AND  l.DataTypeName != 'DATE')) OR @DateOn = 1)
				) q
	-- filter out rows already in our table
	LEFT JOIN dbo.CleaningColumns c ON 
			q.DatabaseName = c.DatabaseName and
			q.SchemaName = c.SchemaName and
			q.TableName = c.TableName and
			q.ColumnName = c.ColumnName
	WHERE c.ColumnName IS NULL and q.Rowid = 1	
	ORDER BY DatabaseName,SchemaName,TableName,ColumnName;





		-- Lookup ID Column  (Mark missing/multiple CREATED WITHOUT ID COLUMN REVIEW)

		DECLARE @PkIdUpdateSql varchar(3000);
		DECLARE @iTableLoop int;

		SELECT @iTableLoop = 1 + COUNT(*) 
		FROM
			( SELECT COUNT(*) As TableCount from dbo.CleaningColumns where IDColumnName is null GROUP BY DatabaseName, SchemaName, TableName )q
		
		While @iTableLoop > 0
		BEGIN
			SELECT @PkIdUpdateSql = CONCAT(
					'UPDATE c
					SET IDColumnname = q.IDColumnname		
					FROM dbo.CleaningColumns c
					INNER JOIN 
					(SELECT ''',DatabaseName,''' as DatabaseName, ''',TableName,''' as TableName, ''',SchemaName,''' as SchemaName,
							ISNULL(',DatabaseName,'.dbo.TablePrimaryKeyColumnNameGet(''',TableName,''',''',SchemaName,'''),''ID'') as IDColumnname) q
					ON c.DatabaseName = q.DatabaseName and c.TableName = q.TableName and c.SchemaName = q.SchemaName
					')
			FROM dbo.CleaningColumns 
			WHERE IDColumnName is null;

			EXEC(@PkIdUpdateSql);
			SELECT @iTableLoop = @iTableLoop -1, @PkIdUpdateSql='';
		END;

		

	-- Lookup Gender Column  (Mark multiple CREATED BUT MULTI GENDER COLUMNS FOUND - REVIEW)
	UPDATE c
	SET GenderRefColumnName = z.GenderRefColumnName
	FROM dbo.CleaningColumns c
	INNER JOIN 
				(SELECT v.DatabaseName, v.SchemaName, v.TableName, v.ColumnName, 
					( CASE COUNT(*) WHEN 1 THEN v.ColumnName ELSE 'MULTI-FOUND' END) As GenderRefColumnName
				FROM dbo.Validator v
				INNER JOIN (
							SELECT DatabaseName, SchemaName, TableName 
							FROM dbo.CleaningColumns 
							WHERE (ColumnName like '%name%') and (GenderRefColumnName is null or LEN(GenderRefColumnName) < 2)
							GROUP BY DatabaseName, SchemaName, TableName) q
						ON v.DatabaseName = q.DatabaseName and  v.SchemaName = q.SchemaName and v.TableName = q.TableName
				WHERE V.ColumnName LIKE '%GENDER%' or V.ColumnName LIKE '%SEX%'
				GROUP BY v.DatabaseName, v.SchemaName, v.TableName, v.ColumnName) z
		ON c.DatabaseName = z.DatabaseName and  c.SchemaName = z.SchemaName and c.TableName = z.TableName
 WHERE (c.GenderRefColumnName is null or LEN(c.GenderRefColumnName) < 2)
	and (c.ColumnName like '%name%');
				
select * FROM dbo.CleaningColumns  WHERE  LEN(GenderRefColumnName) > 1;

	UPDATE v
	SET Status = (Case when v.IsActive = 1 then 'cleaning' else 'clean-inactive' end)
	FROM dbo.Validator  AS v
		INNER JOIN dbo.CleaningColumns AS c
			ON v.DatabaseName  = c.DatabaseName
			AND v.SchemaName = C.SchemaName
			AND v.TableName = c.TableName
			AND v.ColumnName = c.ColumnName;
	SELECT *
	FROM  dbo.CleaningColumns
	WHERE ID > @StartID
	ORDER BY DatabaseName, SchemaName, TableName, ColumnName;

END
GO








USE [DB_Clean_DataGeneration]
GO

/****** Object:  StoredProcedure [dbo].[CleaningColumnRemoveNow]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER         PROCEDURE [dbo].[CleaningColumnRemoveNow] 
@DatabaseName varchar(200),
@SchemaName varchar(100),
@TableName varchar(200),
@ColumnName varchar(200),
@IDColumnName varchar(200)
AS
BEGIN

	DECLARE @ResultsAction varchar(2500)='RESULTS: ';
	DECLARE @ExistsCount int = 0;

	IF (SELECT COUNT(*) FROM dbo.Validator
			WHERE	DatabaseName = @DatabaseName
				AND	SchemaName = @SchemaName
				AND TableName = @TableName
				AND ColumnName = @ColumnName) = 0
	BEGIN
		SELECT @ResultsAction = @ResultsAction + ' THIS ACTION IS TEMPORARY ONLY. The VALIDATOR table is out of sync with the database. Consider running an update on it.'
	END;

	-- REMOVE FROM dbo.CleaningColumns
	SELECT	@ExistsCount = COUNT(*)
	FROM	dbo.CleaningColumns
	WHERE	DatabaseName = @DatabaseName
		AND	SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName = @ColumnName;

	IF @ExistsCount > 0
	BEGIN
		UPDATE	dbo.CleaningColumns
		SET		IsActive = 0
		WHERE	DatabaseName = @DatabaseName
				AND	SchemaName = @SchemaName
				AND TableName = @TableName
				AND ColumnName = @ColumnName;

		SELECT @ResultsAction = @ResultsAction + ' Column DEACTIVATED in the dbo.CleaningColumns table.'
	END
	ELSE
	BEGIN
			SELECT @ResultsAction = @ResultsAction + ' Column was NOT FOUND in the dbo.CleaningColumns table.'
	END;

	-- ADD to dbo.ValidatorAlwaysIgnore
	SELECT	@ExistsCount = COUNT(*)
	FROM	dbo.ValidatorAlwaysIgnore
	WHERE	DatabaseName = @DatabaseName
		AND	SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName = @ColumnName;

	IF @ExistsCount > 0
	BEGIN
		SELECT @ResultsAction = @ResultsAction + ' Column ALREADY EXISTS in the dbo.ValidatorAlwaysIgnore table.'
	END
	ELSE
	BEGIN
		INSERT INTO dbo.ValidatorAlwaysIgnore
		([DatabaseName], [SchemaName], [TableName], [ColumnName], [dtCreated])
		VALUES( @DatabaseName,@SchemaName, @TableName,@ColumnName,getutcdate());

		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @ResultsAction = @ResultsAction + ' Column ADDED to the dbo.ValidatorAlwaysIgnore table.'
		END
		ELSE
		BEGIN
			SELECT @ResultsAction = @ResultsAction + ' ERROR adding column to the dbo.ValidatorAlwaysIgnore table.'
		END;
	END;

	PRINT @ResultsAction;
	SELECT @ResultsAction;
END;
GO

/****** Object:  StoredProcedure [dbo].[CleaningColumnAddNow]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER           PROCEDURE [dbo].[CleaningColumnAddNow] 
@DatabaseName varchar(200),
@SchemaName varchar(100),
@TableName varchar(200),
@ColumnName varchar(200),
@IDColumnName varchar(200),
@DataType varchar(50)
AS
BEGIN

	DECLARE @ResultsAction varchar(2500)='RESULTS: ';
	DECLARE @ExistsCount int = 0;

	IF (SELECT COUNT(*) FROM dbo.Validator
			WHERE	DatabaseName = @DatabaseName
				AND	SchemaName = @SchemaName
				AND TableName = @TableName
				AND ColumnName = @ColumnName) = 0
	BEGIN
		SELECT @ResultsAction = @ResultsAction + ' THIS ACTION IS TEMPORARY ONLY. The VALIDATOR table is out of sync with the database. Consider running an update on it.'
	END;

	IF (SELECT COUNT(*) FROM dbo.GetDataTypes WHERE DataTypeName = @DataType) = 0
	BEGIN
		SELECT @ResultsAction = @ResultsAction + ' Column NOT ADDED. Datatype invalid.'
		SELECT  'DATATYPE DOES NOT EXIST. Select from the following list:';
		SELECT * FROM dbo.GetDataTypes ;
	END
	ELSE
	BEGIN
			-- ADD or UPDATE dbo.CleaningColumns
			SELECT	@ExistsCount = COUNT(*)
			FROM	dbo.CleaningColumns
			WHERE	DatabaseName = @DatabaseName
				AND	SchemaName = @SchemaName
				AND TableName = @TableName
				AND ColumnName = @ColumnName;

			IF @ExistsCount > 0
			BEGIN
				UPDATE	dbo.CleaningColumns
				SET		IDColumnName = @IDColumnName,
						DataType = @DataType,
						IsActive = 1
				WHERE	DatabaseName = @DatabaseName
						AND	SchemaName = @SchemaName
						AND TableName = @TableName
						AND ColumnName = @ColumnName;

				SELECT @ResultsAction = @ResultsAction + ' Column already EXISTS in the dbo.CleaningColumns table. IsActive reset.'
			END
			ELSE
			BEGIN
				INSERT INTO dbo.CleaningColumns
				([DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb])
				VALUES
				(@DatabaseName, @SchemaName, @TableName, @ColumnName, NULL, @IDColumnName, @DataType, 1, 1);
				SELECT @ResultsAction = @ResultsAction + ' Column was ADDED to the dbo.CleaningColumns table.'
			END;

			-- REMOVE from dbo.ValidatorAlwaysIgnore
			DELETE FROM dbo.ValidatorAlwaysIgnore
			WHERE	DatabaseName = @DatabaseName
				AND	SchemaName = @SchemaName
				AND TableName = @TableName
				AND ColumnName = @ColumnName;

			IF @@ROWCOUNT > 0
			BEGIN
				SELECT @ResultsAction = @ResultsAction + ' Column REMOVED from the dbo.ValidatorAlwaysIgnore table.'
			END;	 

	END;
	PRINT @ResultsAction;
	SELECT @ResultsAction;
END;


GO

/****** Object:  StoredProcedure [dbo].[GeneratePreview]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER      PROCEDURE [dbo].[GeneratePreview]
AS
BEGIN

	DECLARE @LookupType as Table (ID INT NOT NULL IDENTITY(1,1), DataTypeName VARCHAR(50), Keyword VARCHAR(50), IsInt bit);
	DECLARE @DateOn INT;

	INSERT INTO @LookupType
	select c.DataTypeName, s.value, c.IsInt
	FROM dbo.CleaningDataType c
	CROSS APPLY string_split(c.keywordList,',') s 
	WHERE c.IsActive=1 and LEN(S.value) > 1;

	SELECT  @DateOn = COUNT(*) FROM @LookupType WHERE DataTypeName = 'DATE';

	SELECT *
	FROM 
		(
		SELECT 
				v.ID, v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName,v.ObjectTypeName,v.Status,
				v.DataType, v.GeneratorDataType, l.DataTypeName, l.Keyword, l.Isint,
				ROW_NUMBER() OVER(PARTITION BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName ORDER BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName) As ROWID
		FROM	dbo.Validator v
				INNER JOIN @LookupType l 
					ON (v.ColumnName LIKE l.Keyword+'%')
					and (l.isint = 1 or LEFT(v.datatype,7) NOT IN (
					'bigint','binary','bit','decimal','float','geograp','geometr','hierarc','image','int','money','numeric','real','smallin','smallmo','sql_var','tinyint'
					)) 
				LEFT JOIN dbo.ValidatorAlwaysIgnore ai ON v.DatabaseName = ai.DatabaseName and v.SchemaName = ai.SchemaName and v.TableName = ai.TableName and v.ColumnName= ai.ColumnName
		WHERE	(v.IsActive=1 and v.ObjectTypeName='column' and v.Status = 'standard' and ai.ColumnName is null)
				AND ((@DateOn = 0 AND NOT (v.ColumnName LIKE '%date%' AND  l.DataTypeName != 'DATE')) OR @DateOn = 1)  -- This excludes FIRSTcreatedDATE, LASTmodifiedDATE, etc.
		) q
	WHERE q.Rowid = 1
	ORDER BY DatabaseName,SchemaName,TableName,ColumnName;


END
GO

/****** Object:  StoredProcedure [dbo].[ColumnsToAlwaysIgnore]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER        PROCEDURE [dbo].[ColumnsToAlwaysIgnore]
@IdList varchar(8000)
AS
BEGIN

	-- Uses a LISt of IDs from the current version stored in the VALIDATOR table.
	-- RUN dbo.GeneratePreview to get deatils and find itmes to exclude

	
	INSERT INTO dbo.ValidatorAlwaysIgnore
	SELECT	DatabaseName, SchemaName, TableName, ColumnName, getutcdate()
	FROM	dbo.Validator v
	WHERE	ID IN (	SELECT CONVERT(INT,value)
					FROM string_split(@IdList,','))
			AND NOT EXISTS (	SELECT	*
								FROM	dbo.ValidatorAlwaysIgnore
								WHERE	DatabaseName =v.DatabaseName 
										and SchemaName = v.SchemaName 
										and TableName = v.TableName 
										and ColumnName = v.ColumnName);

	UPDATE c
	SET IsActive = 0
	FROM		dbo.CleaningColumns AS c
	INNER JOIN	dbo.ValidatorAlwaysIgnore AS v 
				ON	c.DatabaseName = v.DatabaseName
					and c.SchemaName = v.SchemaName 
					and c.TableName = v.TableName 
					and c.ColumnName = v.ColumnName
	WHERE c.IsActive = 1


END
GO

/****** Object:  StoredProcedure [dbo].[GenerateSuggestions]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER      PROCEDURE [dbo].[GenerateSuggestions]
AS
BEGIN


DECLARE @LookupType as Table (ID INT NOT NULL IDENTITY(1,1), DataTypeName VARCHAR(50), Keyword VARCHAR(50), IsInt bit);
DECLARE @DateOn INT;
DECLARE @StartID INT;
SELECT @StartID = MAX(ID)
FROM  dbo.CleaningColumns;

	INSERT INTO @LookupType
	select c.DataTypeName, s.value, c.IsInt
	FROM dbo.CleaningDataType c
	CROSS APPLY string_split(c.keywordList,',') s 
	WHERE c.IsActive=1 and LEN(S.value) > 1;

	SELECT  @DateOn = COUNT(*) FROM @LookupType WHERE DataTypeName = 'DATE';

	INSERT INTO dbo.CleaningColumns
	([DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb])
	SELECT q.DatabaseName,q.SchemaName,q.TableName,q.ColumnName,NULL,NULL,DataTypeName,1,1
	FROM 
		(
		SELECT 
				v.ID, v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName,v.ObjectTypeName,v.Status,
				v.DataType, v.GeneratorDataType, 
				ISNULL(v.GeneratorDataType,l.DataTypeName) AS DataTypeName, -- This overrides the AUTO selection
				l.Keyword, l.Isint,
				ROW_NUMBER() OVER(PARTITION BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName ORDER BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName) As ROWID
		FROM	dbo.Validator v
				INNER JOIN @LookupType l 
					ON (v.ColumnName LIKE l.Keyword+'%')
					and (l.isint = 1 or LEFT(v.datatype,7) NOT IN (
					'bigint','binary','bit','decimal','float','geograp','geometr','hierarc','image','int','money','numeric','real','smallin','smallmo','sql_var','tinyint'
					)) 
				LEFT JOIN dbo.ValidatorAlwaysIgnore ai ON v.DatabaseName = ai.DatabaseName and v.SchemaName = ai.SchemaName and v.TableName = ai.TableName and v.ColumnName= ai.ColumnName
		WHERE	(v.IsActive=1 and v.ObjectTypeName='column' and v.Status = 'standard' and ai.ColumnName is null)
				AND ((@DateOn = 0 AND NOT (v.ColumnName LIKE '%date%' AND  l.DataTypeName != 'DATE')) OR @DateOn = 1)
				) q
	-- filter out rows already in our table
	LEFT JOIN dbo.CleaningColumns c ON 
			q.DatabaseName = c.DatabaseName and
			q.SchemaName = c.SchemaName and
			q.TableName = c.TableName and
			q.ColumnName = c.ColumnName
	WHERE c.ColumnName IS NULL and q.Rowid = 1	
	ORDER BY DatabaseName,SchemaName,TableName,ColumnName;





		-- Lookup ID Column  (Mark missing/multiple CREATED WITHOUT ID COLUMN REVIEW)

		DECLARE @PkIdUpdateSql varchar(3000);
		DECLARE @iTableLoop int;

		SELECT @iTableLoop = 1 + COUNT(*) 
		FROM
			( SELECT COUNT(*) As TableCount from dbo.CleaningColumns where IDColumnName is null GROUP BY DatabaseName, SchemaName, TableName )q
		
		While @iTableLoop > 0
		BEGIN
			SELECT @PkIdUpdateSql = CONCAT(
					'UPDATE c
					SET IDColumnname = q.IDColumnname		
					FROM dbo.CleaningColumns c
					INNER JOIN 
					(SELECT ''',DatabaseName,''' as DatabaseName, ''',TableName,''' as TableName, ''',SchemaName,''' as SchemaName,
							ISNULL(',DatabaseName,'.dbo.TablePrimaryKeyColumnNameGet(''',TableName,''',''',SchemaName,'''),''ID'') as IDColumnname) q
					ON c.DatabaseName = q.DatabaseName and c.TableName = q.TableName and c.SchemaName = q.SchemaName
					')
			FROM dbo.CleaningColumns 
			WHERE IDColumnName is null;

			EXEC(@PkIdUpdateSql);
			SELECT @iTableLoop = @iTableLoop -1, @PkIdUpdateSql='';
		END;

		

	-- Lookup Gender Column  (Mark multiple CREATED BUT MULTI GENDER COLUMNS FOUND - REVIEW)
	UPDATE c
	SET GenderRefColumnName = z.GenderRefColumnName
	FROM dbo.CleaningColumns c
	INNER JOIN 
				(SELECT v.DatabaseName, v.SchemaName, v.TableName, v.ColumnName, 
					( CASE COUNT(*) WHEN 1 THEN v.ColumnName ELSE 'MULTI-FOUND' END) As GenderRefColumnName
				FROM dbo.Validator v
				INNER JOIN (
							SELECT DatabaseName, SchemaName, TableName 
							FROM dbo.CleaningColumns 
							WHERE (ColumnName like '%name%') and (GenderRefColumnName is null or LEN(GenderRefColumnName) < 2)
							GROUP BY DatabaseName, SchemaName, TableName) q
						ON v.DatabaseName = q.DatabaseName and  v.SchemaName = q.SchemaName and v.TableName = q.TableName
				WHERE V.ColumnName LIKE '%GENDER%' or V.ColumnName LIKE '%SEX%'
				GROUP BY v.DatabaseName, v.SchemaName, v.TableName, v.ColumnName) z
		ON c.DatabaseName = z.DatabaseName and  c.SchemaName = z.SchemaName and c.TableName = z.TableName
 WHERE (c.GenderRefColumnName is null or LEN(c.GenderRefColumnName) < 2)
	and (c.ColumnName like '%name%');
				
select * FROM dbo.CleaningColumns  WHERE  LEN(GenderRefColumnName) > 1;

	UPDATE v
	SET Status = (Case when v.IsActive = 1 then 'cleaning' else 'clean-inactive' end)
	FROM dbo.Validator  AS v
		INNER JOIN dbo.CleaningColumns AS c
			ON v.DatabaseName  = c.DatabaseName
			AND v.SchemaName = C.SchemaName
			AND v.TableName = c.TableName
			AND v.ColumnName = c.ColumnName;
	SELECT *
	FROM  dbo.CleaningColumns
	WHERE ID > @StartID
	ORDER BY DatabaseName, SchemaName, TableName, ColumnName;

END
GO

/****** Object:  StoredProcedure [dbo].[GeneratorUpdateBaseColumns]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER      PROCEDURE [dbo].[GeneratorUpdateBaseColumns] 
AS
BEGIN 

	/*
		Remove columns where the database is exclude
	*/

	DELETE FROM dbo.Validator
	WHERE ObjectTypeName in ('table','column')
	and DatabaseName in (
						SELECT DatabaseName 
						FROM dbo.Validator 
						WHERE ObjectTypeName = 'database' and status = 'exclude');

	/*
		Check for new TABLES from our ACTIVE databases we may wish to consider
	*/

	DECLARE @tblLoop INT = 0;
	DECLARE @tblSql nvarchar(3000);
	DECLARE @dbTable as TABLE (ID INT IDENTITY(1,1), DatabaseName VARCHAR(250))

	INSERT INTO @dbTable
	SELECT DatabaseName
	FROM dbo.Validator
	WHERE ObjectTypeName = 'database' and IsActive=1 and Status != 'exclude'
	UNION
	SELECT DISTINCT DatabaseName
	FROM dbo.CleaningColumns
	WHERE IsActive=1

	SELECT @tblLoop =  MAX(ID) FROM @dbTable;

	WHILE @tblLoop > 0
	BEGIN
		SELECT @tblSql = CONCAT('INSERT INTO dbo.Validator
									([DatabaseName], [SchemaName], [TableName], [ColumnName], [ObjectTypeName], [Status], [DataType], [IsActive], [dtCreated], [dtLastModified])
									SELECT ''',DatabaseName,''', sc.name, tbl.name, null, ''table'',''parent'',null,1,getutcdate(),getutcdate()  
									FROM  ',DatabaseName,'.sys.tables tbl 
									inner join ',DatabaseName,'.sys.schemas sc on tbl.schema_id = sc.schema_id
									left join DB_Clean_DataGeneration.dbo.Validator v on tbl.name = v.TableName and sc.name = v.SchemaName
									WHERE v.TableName is null
									;')
		FROM @dbTable
		WHERE ID = @tblLoop;

		BEGIN TRY
			EXEC(@tblSql)
		END TRY
		BEGIN CATCH
			PRINT @tblSql;
		END CATCH;

		-- reset variables
		SELECT	@tblLoop = @tblLoop - 1,
				@tblSql ='';
	END;

	/*
		Populate the VALIDATOR with a list of COLUMNS from the tables we wish to consider
	*/


	DECLARE @cLoop INT = 0;
	DECLARE @cSql nvarchar(3000);
	DECLARE @cdbTable as TABLE (ID INT IDENTITY(1,1), DatabaseName VARCHAR(250))

	INSERT INTO @cdbTable
	SELECT DatabaseName
	FROM dbo.Validator
	WHERE ObjectTypeName = 'database' and IsActive=1 and Status != 'exclude'
	UNION
	SELECT DISTINCT DatabaseName
	FROM dbo.CleaningColumns
	WHERE IsActive=1

	SELECT @cLoop =  MAX(ID) FROM @cdbTable;

	WHILE @cLoop > 0
	BEGIN
		SELECT @cSql =
	
		CONCAT('INSERT INTO dbo.Validator
									([DatabaseName], [SchemaName], [TableName], [ColumnName], [ObjectTypeName], [Status], [DataType], [IsActive], [dtCreated], [dtLastModified])
									SELECT ''',DatabaseName,''', sc.name,  tbl.name, c.name,  ''column'',''standard'',
					(CASE	WHEN t.Name in (''decimal'',''numeric'') THEN CONCAT(t.Name,''('',c.max_length,'','', c.precision,'')'')
							WHEN t.Name in (''sql_variant'',''hierachyid'',''varbinary'',''varchar'',''binary'',''char'',''nvarchar'',''nchar'') THEN CONCAT(t.Name,''('',REPLACE(c.max_length,''-1'',''max''),'')'')
							ELSE t.Name END),
							1,getutcdate(),getutcdate()
					FROM ',DatabaseName,'.sys.tables tbl
					INNER JOIN ',DatabaseName,'.sys.schemas sc ON Tbl.schema_id = Sc.schema_id
					INNER JOIN ',DatabaseName,'.sys.columns c ON tbl.object_id = c.object_id
					INNER JOIN ',DatabaseName,'.sys.types t ON c.user_type_id = t.user_type_id
					LEFT JOIN DB_Clean_DataGeneration.dbo.tfnValidatorTableExcluded(''',DatabaseName,''') fn ON fn.SchemaName = sc.name and fn.TableName = tbl.name
					LEFT JOIN DB_Clean_DataGeneration.dbo.Validator v  ON v.SchemaName = sc.name and v.TableName = tbl.name and v.ColumnName = c.name
					WHERE fn.TableName IS NULL
					and v.ColumnName is null;')
		FROM @cdbTable
		WHERE ID = @cLoop;

		BEGIN TRY
			EXEC(@cSql)
		END TRY
		BEGIN CATCH
			PRINT @cSql;
		END CATCH;

		-- reset variables
		SELECT	@cLoop = @cLoop - 1,
				@cSql ='';
	END;

END
GO

/****** Object:  StoredProcedure [dbo].[DataCleaning]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 20210929
-- EXEC dbo.DataCleaning
-- 20230425:  Updated:
--						dbo.FullNames AS DG ON RIGHT(C.',@curIDColumnName,',6) = DG.ID
--						changed to --
--						dbo.FullNames AS DG ON RIGHT(CONVERT(VARCHAR(50),C.',@curIDColumnName,'),6) = DG.ID
-- EXEC dbo.DataCleaning 'qatest8@CoventBridge.com','DEVOPS','david.speight@coventbridge.com',1,0,1
-- =============================================
CREATE OR ALTER        PROCEDURE [dbo].[DataCleaning]
@email varchar(100) = 'qatest@CoventBridge.com',			-- set this to the email you want to replace all email addresses in the database with.
@AgentProfile varchar(100) = 'DEVOPS',						-- SQL Agent profile account to be used to send failure alert email from.
@RecipientEmail varchar(200) = 'DEVOPS@CoventBridge.com',	-- Email address to send the failure alert to.
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
			' FROM [',DatabaseName,'].[',SchemaName,'].[',TableName,']  WHERE LEN(CONVERT(VARCHAR(500),[',ColumnName,'])) > 0;')
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
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Load Sample Data','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N', @SqlDynamic);
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
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Triggers Load ERROR','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
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
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
		VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Disabled ERROR', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
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
			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
			VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Unlink Failure', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
		END CATCH

		BEGIN TRY
			EXEC(@dtsql);
		END TRY
		BEGIN CATCH
			PRINT(@dtsql)
			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
			VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Data Delete Failure', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
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
	IF @curDataType IN ( 'REMOVE','NOTE','CLEAN','X','CLEAR','BLANK','OLD')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT('UPDATE ',@curTablePath,' SET [',@curColumnName,'] = ''CLEANED'' WHERE [',@curColumnName,'] IS NOT NULL;');
	END;
	IF @curDataType IN ( 'CLEAR','CLEARDATE')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT('UPDATE ',@curTablePath,' SET [',@curColumnName,'] = ''1901-01-01'' WHERE [',@curColumnName,'] IS NOT NULL;');
	END;
	IF @curDataType IN ( 'ZERO','RESETNUM','ZERONUMBER')
	BEGIN
		SELECT @SqlDynamic	=	CONCAT('UPDATE ',@curTablePath,' SET [',@curColumnName,'] = 0 WHERE [',@curColumnName,'] IS NOT NULL;');
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
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT],  [ExecStopDT], [ErrorRowCnt], [SuccessfulProcessingInd], [SqlStatement])
		VALUES (@ParentAuditKey, RIGHT(CONCAT(@curTablePath,'.',@curColumnName),50),'DATA CLEANING: Clean Rows', @PkgGUID, @dtStartTime,  getutcdate(), @curRowCount, 'N', @SqlDynamic);
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
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
		VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Enabled ERROR', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
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
								INNER JOIN [',C.DatabaseName,'].[',C.SChemaName,'].[',C.TableName,'] AS E ON V.RowID = E.',C.IDColumnName,'
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
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Sample Data','Ver Update failure', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N', @SqlDynamic);
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





GO

/****** Object:  StoredProcedure [dbo].[CleaningRowExcludeAdd]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER     PROCEDURE [dbo].[CleaningRowExcludeAdd] 
@DatabaseName varchar(200),
@SchemaName varchar(100),
@TableName varchar(200),
@IDColumnName varchar(200),
@ExcludeID bigint
AS
BEGIN

	DECLARE @ResultsAction varchar(2500)='RESULTS: ';
	DECLARE @ExistsCount int = 0;

	IF (SELECT COUNT(*) FROM dbo.CleaningRowExclude
			WHERE	DatabaseName = @DatabaseName
				AND	SchemaName = @SchemaName
				AND TableName = @TableName
				AND IDColumnName = @IDColumnName
				AND ExcludeID = @ExcludeID) > 0
	BEGIN
		SELECT @ResultsAction = ' An exclusion rule already exists for this ID.'
	END
	ELSE
	BEGIN
		INSERT INTO dbo.CleaningRowExclude
		SELECT @DatabaseName,@SchemaName,@TableName,@IDColumnName,@ExcludeID,1;

		SELECT @ResultsAction = ' Exclusion rule created.';
	END;

	SELECT @ResultsAction;
END;


GO

/****** Object:  StoredProcedure [dbo].[CleaningTableRemoveAllColumnsNow]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		David Speight
-- Create date: 2023
-- =============================================
CREATE OR ALTER    PROCEDURE [dbo].[CleaningTableRemoveAllColumnsNow] 
@DatabaseName varchar(200),
@SchemaName varchar(100),
@TableName varchar(200)
AS
BEGIN

	DECLARE @ResultsAction varchar(2500)='RESULTS: ';
	DECLARE @ExistsCount int = 0;
	DECLARE @RowCount int = 0;
	

	-- REMOVE FROM dbo.CleaningColumns
	SELECT	@ExistsCount = COUNT(*)
	FROM	dbo.CleaningColumns
	WHERE	DatabaseName = @DatabaseName
		AND	SchemaName = @SchemaName
		AND TableName = @TableName;

	IF @ExistsCount > 0
	BEGIN
		UPDATE	dbo.CleaningColumns
		SET		IsActive = 0
		WHERE	DatabaseName = @DatabaseName
				AND	SchemaName = @SchemaName
				AND TableName = @TableName;
		SELECT @RowCount = @@ROWCOUNT;

		SELECT @ResultsAction = CONCAT(@ResultsAction,' Total of ',@RowCount,' Columns for table ',@TableName,'  DEACTIVATED in the dbo.CleaningColumns table.');
	END
	ELSE
	BEGIN
			SELECT @ResultsAction = @ResultsAction + ' Table was NOT FOUND in the dbo.CleaningColumns table.';
	END;

	-- ADD to dbo.ValidatorAlwaysIgnore
	INSERT INTO   dbo.ValidatorAlwaysIgnore
	SELECT DatabaseName, SChemaName, TableName, ColumnName, getutcdate()
	FROM dbo.Validator AS V
	WHERE DatabaseName = @DatabaseName
		AND	SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName IS NOT NULL
		AND NOT EXISTS (SELECT DatabaseName, SChemaName, TableName, ColumnName 
						FROM dbo.ValidatorAlwaysIgnore
						WHERE DatabaseName = V.DatabaseName
						AND	SchemaName = V.SchemaName
						AND TableName = V.TableName
						AND ColumnName = V.ColumnName);
	SELECT @RowCount = @@ROWCOUNT;	

	IF @RowCount > 0
	BEGIN
		SELECT @ResultsAction = CONCAT(@ResultsAction,' Total of ',@RowCount,' Columns for table ',@TableName,'  ADDED to the dbo.ValidatorAlwaysIgnore table.');
	END
	ELSE
	BEGIN
		SELECT @ResultsAction = @ResultsAction + ' No new columns added to the dbo.ValidatorAlwaysIgnore table.'
	END;
	

	PRINT @ResultsAction;
	SELECT @ResultsAction;
END;

GO

/****** Object:  StoredProcedure [dbo].[DataCleaningBatched]    Script Date: 7/11/2023 11:57:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 20210929
-- EXEC dbo.DataCleaning
-- 20230620:  Updated:
--						Run UPDATE statements in BATCHES for each table instead of for each column.
--						Exclude rows that are defined in the new table: CleaningRowExclude
--						
-- EXEC dbo.DataCleaningBatched 'qatest8@CoventBridge.com','DEVOPS','david.speight@coventbridge.com',1,0,1
-- =============================================
CREATE OR ALTER          PROCEDURE [dbo].[DataCleaningBatched]
@email varchar(100) = 'qatest@CoventBridge.com',			-- set this to the email you want to replace all email addresses in the database with.
@AgentProfile varchar(100) = 'DEVOPS',						-- SQL Agent profile account to be used to send failure alert email from.
@RecipientEmail varchar(200) = 'DEVOPS@CoventBridge.com',	-- Email address to send the failure alert to.
@DebuggerON bit = 0,
@LocalHostIsQa int = 0,										-- WARNING:  This will RUN, even on PROD if set to 1.
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
	BEGIN -- QA ON  (to line 731)

		DECLARE @ParentAuditKey int;
		DECLARE @currAuditKey int;
		DECLARE @PkgGUID uniqueidentifier;
		DECLARE @iCurrID INT;
		DECLARE @iLoopMaxID INT;
		DECLARE @SqlDynamic VARCHAR(8000); 
		DECLARE @curDatabase varchar(200);
		DECLARE @curSchemaName varchar(50);
		DECLARE @curTableName varchar(200);
		DECLARE @curColumnName varchar(200);
		DECLARE @curGenderRefColumnName varchar(200);
		DECLARE @curIDColumnName varchar(200);
		DECLARE @curDataType varchar(50);
		DECLARE @curUsesGenerationDb bit;
		DECLARE @curHasExclusionCsIdList bit;
		DECLARE @curExclusionCsIdList varchar(2500);
		DECLARE @curTablePath varchar(605);
		DECLARE @curRowCount int;
		DECLARE @dtStartTime datetime;
		DECLARE @iRandom int;

		DECLARE @iCurrBatchID INT;
		DECLARE @iCurrBatchMaxOrderID INT;
		DECLARE @iCurrBatchOrderID INT;
		DECLARE @TsqlUpdateHeader varchar(50) = 'UPDATE C SET ';
		DECLARE @TsqlUpdateColumnSelect varchar(4000);
		DECLARE @TsqlUpdateFrom varchar(500);
		DECLARE @TsqlUpdateColumnWhere varchar(3500);
		
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
											[UsesGenerationDb] [bit] NULL,
											[HasExclusionCsIdList] bit NULL,
											[BatchID] [int] NULL,
											[OrderID] [int] NULL,
											[MaxOrderID] [int])

		DECLARE @tDatabases AS TABLE (		[ID] [int] IDENTITY(1,1) NOT NULL,
											[DatabaseName] [varchar](200) NULL)

		INSERT INTO @CleaningColumns
		SELECT [ID], [DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb], [HasExclusionCsIdList], 0, 0, 0
		FROM dbo.CleaningColumns
		WHERE DatabaseName IN (SELECT name from master.sys.databases where state_desc = 'ONLINE')  -- Only process items when database is online
			AND IsActive = 1
		ORDER BY [DatabaseName], [SchemaName], [TableName], [ColumnName]

		INSERT INTO @tDatabases (DatabaseName)
		SELECT DISTINCT DatabaseName
		FROM @CleaningColumns;

		-- SET UP BATCHING
		-- Note that the main table LOOPs from start of temp table, so we will order batches in like manner.
		SELECT	@iCurrID	= 0, 
				@iCurrBatchID = 0,
				@iCurrBatchOrderID = 0,
				@curDatabase = '',
				@curSchemaName = '',
				@curTableName = '',
				@iLoopMaxID = MAX(ID) FROM @CleaningColumns;		

		WHILE @iCurrID < @iLoopMaxID   
		BEGIN
			SELECT @iCurrID = @iCurrID + 1;

			IF (	SELECT	count(*) FROM @CleaningColumns
					WHERE ID = @iCurrID AND DatabaseName = @curDatabase AND SchemaName = @curSchemaName AND TableName =@curTableName ) > 0
			BEGIN
				-- Configre for SAME batch
				SELECT @iCurrBatchOrderID = @iCurrBatchOrderID+1
			END
			ELSE
			BEGIN
				-- Set MAXID on previous batch before incrementing
				UPDATE @CleaningColumns
				SET MaxOrderID = @iCurrBatchOrderID
				WHERE BatchID = @iCurrBatchID;
				-- Set to NEW batch
				SELECT	@iCurrBatchID = @iCurrBatchID+1,
						@iCurrBatchOrderID = 1;

				SELECT	@curDatabase = DatabaseName,
						@curSchemaName = SchemaName,
						@curTableName = TableName
				FROM	@CleaningColumns
				WHERE ID = @iCurrID;
			END

			UPDATE @CleaningColumns
			SET BatchID = @iCurrBatchID,
				OrderID = @iCurrBatchOrderID
			WHERE ID = @iCurrID;
		END; -- SETUP BATCHES WHILE LOOP END

		-- Set MAXID on last batch 
		UPDATE @CleaningColumns
		SET MaxOrderID = @iCurrBatchOrderID
		WHERE BatchID = @iCurrBatchID;

		SELECT @iCurrID	= 0, 
				@iCurrBatchID = 0,
				@iCurrBatchOrderID = 0,
				@curDatabase = '',
				@curSchemaName = '',
				@curTableName = '';



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
			SELECT	@iCurrID	=	@iCurrID + 1, @SqlDynamic='', @curExclusionCsIdList = '', @curIDColumnName=0;
			SELECT	@SqlDynamic	=	CONCAT(
					'INSERT INTO dbo.CleaningVerificationSample (CleaningColumnID, OriginalSampleData, RowID) 
					  SELECT TOP(1) ',C.CleaningColumnID, ', CONVERT(NVARCHAR(500),[',C.ColumnName,']), ', C.IDColumnName,    
					' FROM [',C.DatabaseName,'].[',C.SchemaName,'].[',C.TableName,']  
					  WHERE LEN(CONVERT(VARCHAR(500),[',ColumnName,'])) > 0'),
					 @curExclusionCsIdList =  ISNULL(E.curExclusionCsIdList,''),
					 @curIDColumnName = C.IDColumnName
			FROM @CleaningColumns as C 
				LEFT JOIN (	SELECT DatabaseName, SchemaName, TableName, STRING_AGG(ExcludeId,',') AS curExclusionCsIdList 
							FROM	dbo.CleaningRowExclude
							GROUP BY DatabaseName, SchemaName, TableName
							) AS E
							ON E.DatabaseName = C.DatabaseName AND E.SchemaName = C.SchemaName AND E.TableName = C.TableName
			WHERE ID = @iCurrID;
			IF LEN(@curExclusionCsIdList) > 1
			BEGIN
				SELECT	@SqlDynamic	= 	CONCAT(@SqlDynamic,' AND ',@curIDColumnName,' NOT IN (',@curExclusionCsIdList,');');
			END;


			BEGIN TRY
				EXEC(@SqlDynamic);
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Load Sample Data','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				PRINT(@SqlDynamic);
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Load Sample Data','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N', @SqlDynamic);
			END CATCH
		END; -- VERIFICATION SET UP WHILE LOOP END

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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Triggers Loaded','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Triggers Load ERROR','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
			END CATCH
		END; -- TRIGGER FIND WHILE LOOP END

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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Disabled', @PkgGUID, getutcdate(), 'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Disabled ERROR', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
			END CATCH
		END; -- TRIGGER DISABLE WHILE LOOP END


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
					HistoryTableName varchar(250),
					Relink bit);
			DECLARE @tCount int = 0;
			DECLARE @ttSql varchar(2500);
			DECLARE @dtSql varchar(2500);

			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
			VALUES (@ParentAuditKey, 'DATA CLEANING: Begin-Temporal','Deleting History Tables', @PkgGUID, getutcdate(), 'Y');

			INSERT INTO @tTemporalHistory
			SELECT DatabaseName, TableSchema, TableName, HistorySchema, HistoryTableName, ReLink
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
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Unlink Failure', @PkgGUID, getutcdate(), 'N', @ttsql);
				END CATCH

				BEGIN TRY
					EXEC(@dtsql);
				END TRY
				BEGIN CATCH
					PRINT(@dtsql)
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Data Delete Failure', @PkgGUID, getutcdate(), 'N', @ttsql);
				END CATCH;

				SELECT @tCount = @tCount - 1, @ttSql = '';
			END; -- TEMPORAL TABLE WHILE LOOP END
		END; -- CLEAN TEMPORAL TABLES (IF)


		/*
		==========================================
		MAIN SECTION FOR CLEANING THE DATA
		JULY 2023 UPDATE: Worked to Batch updates for same table together.
		==========================================
		*/
		--  Audit and error logging
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Begin-Tables','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'Y');
		
		SELECT	@iCurrID	= 0, 
				@TsqlUpdateColumnSelect='',
				@TsqlUpdateFrom='',
				@TsqlUpdateColumnWhere='',
				@SqlDynamic='',
				@iLoopMaxID = MAX(ID) 
		FROM @CleaningColumns;
		
		
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
					@curExclusionCsIdList	=	'',
					@curHasExclusionCsIdList=	0,
					@curTablePath			=	'',
					@curRowCount			=	0;

			SELECT	@curDatabase			=	DatabaseName,
					@curSchemaName			=	SchemaName,
					@curTableName			=	TableName,
					@curColumnName			=	ColumnName,
					@curGenderRefColumnName	=	(CASE WHEN GenderRefColumnName = 'Email' THEN '0'  WHEN LEN(GenderRefColumnName) > 1 THEN CONCAT('C.',GenderRefColumnName) ELSE '0' END),
					@curIDColumnName		=	IDColumnName,
					@curDataType			=	DataType,
					@curUsesGenerationDb	=	UsesGenerationDb,
					@curHasExclusionCsIdList=	HasExclusionCsIdList,
					@curTablePath			=	CONCAT('[',DatabaseName,'].[',SchemaName,'].[',TableName,']'),
					@dtStartTime			=	getutcdate(),
					@iRandom				=	LEFT(DATEPART(s,getutcdate()),1),  -- Num 0-9 with 0-5 hit most often
					@iCurrBatchID			=	BatchID,
					@iCurrBatchOrderID		=	OrderID,
					@iCurrBatchMaxOrderID	=	MaxOrderID
			FROM @CleaningColumns
			WHERE ID = @iCurrID;

			-- TSQL HEADER: Already set in variable as 'UPDATE C SET '
			-- SET UP THE FROM CLAUSE
			IF @iCurrBatchOrderID = 1
			BEGIN
				SELECT	@TsqlUpdateFrom		=	CONCAT(' FROM ',@curTablePath,' AS C ');
			END;
			IF (CHARINDEX('APPLY',@TsqlUpdateFrom) = 0) AND 
					(@curDataType IN ('USERNAME','USER','LOGIN','LOGON','USR','USRNAME','PASSWORD','PASS','PWD','PWORD','PWRD','PSWD','FIRSTNAME','FNAME','FIRST','LASTNAME','LNAME','LAST','FULLNAME'))
				BEGIN
					SELECT	@TsqlUpdateFrom	=	CONCAT(@TsqlUpdateFrom,' CROSS APPLY dbo.tfnFullNameGet(C.',@curIDColumnName,',''',ISNULL(@curGenderRefColumnName,'0'),''',',@iRandom,') AS N  ');
				END;
			-- Add comma if this is the second+ column in a list
			IF @iCurrBatchOrderID > 1
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,', '),
						@TsqlUpdateColumnWhere		=	CONCAT(@TsqlUpdateColumnWhere,' OR LEN(C.[',@curColumnName,']) > 0 ')
			END;
			ELSE -- When OrderID  = 1
			BEGIN 
				IF  @curHasExclusionCsIdList = 1
				BEGIN
					SELECT @curExclusionCsIdList = STRING_AGG(ExcludeId,',')
					FROM [dbo].[CleaningRowExclude]
					WHERE DatabaseName = @curDatabase AND SchemaName = @curSchemaName AND TableName = @curTableName AND IDColumnName = @curIDColumnName;

					SELECT	@TsqlUpdateColumnWhere		=	CONCAT(' WHERE (C.',@curIDColumnName,' NOT IN (',@curExclusionCsIdList,')) AND ( LEN(C.[',@curColumnName,']) > 0 ')
				END
				ELSE
				BEGIN
					SELECT	@TsqlUpdateColumnWhere		=	CONCAT(' WHERE ( LEN(C.[',@curColumnName,']) > 0 ')
				END;	
			END;

			--Complile the SELECT/SET STATEMENT for  COLUMN.
			-- BATCH 01 UPDATES: UserName: 
			IF @curDataType IN ('USERNAME','USER','LOGIN','LOGON','USR','USRNAME')
			BEGIN
				IF @curGenderRefColumnName = 'Email'
				BEGIN
					-- This condition CLEANS for a LOGIN/USERNAME scenario that use an EMAIL address for logon.
					SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Lname,',@iRandom,'),LEFT(N.Fname,2),''@web.com'','''') ');
				END
				ELSE
				BEGIN
					SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Lname,',@iRandom,'),LEFT(N.Fname,2),'''') ');
				END;
			END;

			-- BATCH 2 UPDATES: Password
			IF @curDataType IN ( 'PASSWORD','PASS','PWD','PWORD','PWRD','PSWD' )
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Lname,2),LEFT(N.Fname,2),dbo.fnPasswordGenerator(7),'''') ');
			END;
			
			-- BATCH 03 UPDATES: Email
			IF @curDataType IN ( 'EMAIL','MAIL','E-MAIL','WEBMAIL')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = ''',@email,''' ');
			END;

			-- BATCH 04 UPDATES: DOB as datetime
			IF @curDataType IN ( 'DOB','DATE','DOD','BIRTH','BIRTHDATE','BIRTHDAY','DEATH','DAY','CREATED','UPDATED' )
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	(CASE WHEN [',@curColumnName,'] IS NULL THEN [',@curColumnName,'] ELSE dbo.udfRandomDOBgenerator()  END)' );
			END;

			-- BATCH 05 UPDATES: [SSNID] SSN & Other IDs as Numberic -- MASK all but last 2
			IF @curDataType IN ( 'SSNID', 'SSNINT')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	(999999900+',@iRandom,'+CONVERT(int,RIGHT([',@curColumnName,'],2))) ');
			END;

			-- BATCH 06 UPDATES: [SSNCHAR]  SSN & Other IDs as varchar 
			IF @curDataType IN ('SSN', 'SSNCHAR' )
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	(''999999',@iRandom,'''+RIGHT([',@curColumnName,'],2) ) ');
			END;

			-- BATCH 07 UPDATES: [FIRSTNAME] FirstName with/without Gender Column
			IF @curDataType IN ('FIRSTNAME','FNAME','FIRST')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	N.FName ');
			END;

			-- BATCH 09 UPDATES: [LASTNAME]
			IF @curDataType IN ( 'LASTNAME','LNAME','LAST')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	N.LName ');
			END;

			-- BATCH 10 UPDATES: [FULLNAME]
			IF @curDataType = 'FULLNAME'
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Fname,18),'' '',LEFT(N.Lname,30),'''') ');
			END;

			-- BATCH 11 UPDATES: [ADDRESS1]
			IF @curDataType IN ('ADDRESS','ADDRESS1','ADR','ADDR','ADDR1')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomAddress1([',@curColumnName,']) ');
			END;

			--BATCH 12 UPDATES: [ADDRESS2] also 3/4 use UNIT+ ID#
			IF @curDataType IN ('ADDRESS2','ADDRESS3','ADDRESS4')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomAddress2(LEFT([',@curColumnName,'],30)) ');
			END;	
			
			-- BATCH 13 UPDATES: [TRUNCATE] Tables to delete all data
			IF @curDataType IN ( 'REMOVE','NOTE','CLEAN','X','CLEAR','BLANK','OLD')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = ''CLEANED'' ');
			END;
			IF @curDataType IN ( 'CLEAR','CLEARDATE')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = ''1901-01-01'' ');
			END;
			IF @curDataType IN ( 'ZERO','RESETNUM','ZERONUMBER')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = 0 ');
			END;

			-- BATCH 14 UPDATES: [PHONE]
			IF @curDataType IN ('PHONE','PHONECHAR')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomPhone([',@curColumnName,']) ');
			END;

			-- BATCH 15a UPDATES: [PHONEINT]
			IF @curDataType IN ('PHONEINT','PHONEID')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	REPLACE(dbo.udfRandomPhone([',@curColumnName,']),''-'','''') ');
			END;

			-- BATCH 15b UPDATES: [PHONENUM]
			IF @curDataType IN ('PHONENUM','PHONE10')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',(  RIGHT((REPLACE(dbo.udfRandomPhone([',@curColumnName,']),''-'','''')),10)   ),'''') ');
			END;

			-- BATCH 16 UPDATES: [PINn]
			IF LEFT(@curDataType,3) = 'PIN'
			BEGIN    -- ie PIN4 = 4  PIN12 = 12
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomPin(',REPLACE(@curDataType,'PIN',''),')  ');
			END;

			IF @iCurrBatchOrderID = @iCurrBatchMaxOrderID
			BEGIN
				-- Set last parentheses on WHERE clause
				SELECT @TsqlUpdateColumnWhere		=	CONCAT(@TsqlUpdateColumnWhere,' );');
				-- EXECUTE STATEMENT and RESET Tsql
				SELECT @SqlDynamic = CONCAT(@TsqlUpdateHeader,@TsqlUpdateColumnSelect,@TsqlUpdateFrom,@TsqlUpdateColumnWhere);	

				BEGIN TRY
					EXEC(@SqlDynamic);
					SELECT @curRowCount = @@ROWCOUNT;
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, RIGHT(CONCAT(@curTablePath,'.',@curColumnName),50),'DATA CLEANING: Clean Rows', @PkgGUID, @dtStartTime, getutcdate(), @curRowCount,  'Y', LEFT(@SqlDynamic,2000));
				END TRY
				BEGIN CATCH 
					SELECT @curRowCount = @@ROWCOUNT;
					PRINT(@SqlDynamic);
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT],  [ExecStopDT], [ErrorRowCnt], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, RIGHT(CONCAT(@curTablePath,'.',@curColumnName),50),'DATA CLEANING: Clean Rows', @PkgGUID, @dtStartTime,  getutcdate(), @curRowCount, 'N', LEFT(@SqlDynamic,2000));
				END CATCH;
				SELECT @TsqlUpdateColumnSelect='',@TsqlUpdateFrom='',@TsqlUpdateColumnWhere='',@SqlDynamic='';
			END;
			----- [MAIN LOOP END]
		END; --------- MAIN LOOP END (Line 369)		

		/*
		==========================================
		TEMPORAL TABLES RELINKING - Added June 2023
		==========================================
		*/

		If @CleanTemporalTables = 1
		BEGIN
			DECLARE @ReLink bit;
			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
			VALUES (@ParentAuditKey, 'DATA CLEANING: PostClean-Temporal','BEGIN History Table Linking', @PkgGUID, getutcdate(), 'Y');

			SELECT @tCount = MAX(ID) FROM @tTemporalHistory;

			WHILE @tCount > 0
			BEGIN
				SELECT	@ttSql = CONCAT('ALTER TABLE ',DatabaseName,'.',TableSchema,'.',TableName,' SET (SYSTEM_VERSIONING = ON
							(HISTORY_TABLE=',HistorySchema,'.',HistoryTableName,',DATA_CONSISTENCY_CHECK=OFF))'),
						@ReLink = Relink
				FROM @tTemporalHistory
				WHERE ID = @tCount;

				IF @Relink = 1
				BEGIN
					BEGIN TRY
						PRINT(@ttsql)
						EXEC(@ttsql);
						WAITFOR DELAY '00:00:01';
						INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
						VALUES (@ParentAuditKey, 'DATA CLEANING: PostClean-Temporal','History Relinked', @PkgGUID, getutcdate(), 'Y', @ttsql);
					END TRY
					BEGIN CATCH
						PRINT(@ttsql)
						INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
						VALUES (@ParentAuditKey, 'DATA CLEANING: PostClean-Temporal','Relink Failure', @PkgGUID, getutcdate(), 'N', @ttsql);
					END CATCH;
				END;

				SELECT @tCount = @tCount - 1, @ttSql = '', @ReLink=0;
			END; -- TEMPORAL TABLE WHILE LOOP END
		END; -- CLEAN TEMPORAL TABLES (IF)


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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Enabled', @PkgGUID, getutcdate(), 'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Enabled ERROR', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
				SELECT @curRowCount =	@curRowCount + 1;
			END CATCH
		END; -- TRIGGER ENABLE WHILE LOOP END

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
										INNER JOIN [',C.DatabaseName,'].[',C.SChemaName,'].[',C.TableName,'] AS E ON V.RowID = E.',C.IDColumnName,'
										WHERE V.ID = ',@iCurrID,';')
			FROM dbo.CleaningVerificationSample V
			INNER JOIN dbo.CleaningColumns C ON V.CleaningColumnID = C.ID  -- @CleaningColumns changed to dbo.CleaningColumns
			WHERE V.ID = @iCurrID;

			BEGIN TRY
				EXEC(@SqlDynamic);
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Sample Data','Verification Updated', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Sample Data','Ver Update failure', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N', @SqlDynamic);
			END CATCH
			SELECT @curRowCount = 0;
		END; -- VERIFICATION WHILE LOOP END

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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Email Errors','FAILED to send email alert', @PkgGUID, getutcdate(), getutcdate(), 0,  'N', LEFT(@Body,2000));
			END CATCH;
		END; -- Success / Failure Actions

	END -- QA ON (line 48)

	IF @DebuggerON = 1
	BEGIN		
		SELECT * from dbo.CleaningVerificationSample		
		SELECT * FROM dbo.DimAudit WHERE ParentAuditKey = @ParentAuditKey ORDER BY 1 DESC;
		SELECT * from dbo.CleaningTriggers;
	END;

END -- END SPROC


GO




USE [DB_Clean_DataGeneration]
GO
/****** Object:  StoredProcedure [dbo].[DataCleaningBatched]    Script Date: 6/19/2023 9:03:59 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		David Speight
-- Create date: 20210929
-- EXEC dbo.DataCleaning
-- 20230620:  Updated:
--						Run UPDATE statements in BATCHES for each table instead of for each column.
--						Exclude rows that are defined in the new table: CleaningRowExclude
--						
-- EXEC dbo.DataCleaningBatched 'qatest8@CoventBridge.com','DEVOPS','david.speight@coventbridge.com',1,0,1
-- =============================================
CREATE OR ALTER       PROCEDURE [dbo].[DataCleaningBatched]
@email varchar(100) = 'qatest@CoventBridge.com',			-- set this to the email you want to replace all email addresses in the database with.
@AgentProfile varchar(100) = 'DEVOPS',						-- SQL Agent profile account to be used to send failure alert email from.
@RecipientEmail varchar(200) = 'DEVOPS@CoventBridge.com',	-- Email address to send the failure alert to.
@DebuggerON bit = 0,
@LocalHostIsQa int = 0,										-- WARNING:  This will RUN, even on PROD if set to 1.
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
	BEGIN -- QA ON  (to line 731)

		DECLARE @ParentAuditKey int;
		DECLARE @currAuditKey int;
		DECLARE @PkgGUID uniqueidentifier;
		DECLARE @iCurrID INT;
		DECLARE @iLoopMaxID INT;
		DECLARE @SqlDynamic VARCHAR(8000); 
		DECLARE @curDatabase varchar(200);
		DECLARE @curSchemaName varchar(50);
		DECLARE @curTableName varchar(200);
		DECLARE @curColumnName varchar(200);
		DECLARE @curGenderRefColumnName varchar(200);
		DECLARE @curIDColumnName varchar(200);
		DECLARE @curDataType varchar(50);
		DECLARE @curUsesGenerationDb bit;
		DECLARE @curHasExclusionCsIdList bit;
		DECLARE @curExclusionCsIdList varchar(2500);
		DECLARE @curTablePath varchar(605);
		DECLARE @curRowCount int;
		DECLARE @dtStartTime datetime;
		DECLARE @iRandom int;

		DECLARE @iCurrBatchID INT;
		DECLARE @iCurrBatchMaxOrderID INT;
		DECLARE @iCurrBatchOrderID INT;
		DECLARE @TsqlUpdateHeader varchar(50) = 'UPDATE C SET ';
		DECLARE @TsqlUpdateColumnSelect varchar(4000);
		DECLARE @TsqlUpdateFrom varchar(500);
		DECLARE @TsqlUpdateColumnWhere varchar(3500);
		
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
											[UsesGenerationDb] [bit] NULL,
											[HasExclusionCsIdList] bit NULL,
											[BatchID] [int] NULL,
											[OrderID] [int] NULL,
											[MaxOrderID] [int])

		DECLARE @tDatabases AS TABLE (		[ID] [int] IDENTITY(1,1) NOT NULL,
											[DatabaseName] [varchar](200) NULL)

		INSERT INTO @CleaningColumns
		SELECT [ID], [DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb], [HasExclusionCsIdList], 0, 0, 0
		FROM dbo.CleaningColumns
		WHERE DatabaseName IN (SELECT name from master.sys.databases where state_desc = 'ONLINE')  -- Only process items when database is online
			AND IsActive = 1
		ORDER BY [DatabaseName], [SchemaName], [TableName], [ColumnName]

		INSERT INTO @tDatabases (DatabaseName)
		SELECT DISTINCT DatabaseName
		FROM @CleaningColumns;

		-- SET UP BATCHING
		-- Note that the main table LOOPs from start of temp table, so we will order batches in like manner.
		SELECT	@iCurrID	= 0, 
				@iCurrBatchID = 0,
				@iCurrBatchOrderID = 0,
				@curDatabase = '',
				@curSchemaName = '',
				@curTableName = '',
				@iLoopMaxID = MAX(ID) FROM @CleaningColumns;		

		WHILE @iCurrID < @iLoopMaxID   
		BEGIN
			SELECT @iCurrID = @iCurrID + 1;

			IF (	SELECT	count(*) FROM @CleaningColumns
					WHERE ID = @iCurrID AND DatabaseName = @curDatabase AND SchemaName = @curSchemaName AND TableName =@curTableName ) > 0
			BEGIN
				-- Configre for SAME batch
				SELECT @iCurrBatchOrderID = @iCurrBatchOrderID+1
			END
			ELSE
			BEGIN
				-- Set MAXID on previous batch before incrementing
				UPDATE @CleaningColumns
				SET MaxOrderID = @iCurrBatchOrderID
				WHERE BatchID = @iCurrBatchID;
				-- Set to NEW batch
				SELECT	@iCurrBatchID = @iCurrBatchID+1,
						@iCurrBatchOrderID = 1;

				SELECT	@curDatabase = DatabaseName,
						@curSchemaName = SchemaName,
						@curTableName = TableName
				FROM	@CleaningColumns
				WHERE ID = @iCurrID;
			END

			UPDATE @CleaningColumns
			SET BatchID = @iCurrBatchID,
				OrderID = @iCurrBatchOrderID
			WHERE ID = @iCurrID;
		END; -- SETUP BATCHES WHILE LOOP END

		-- Set MAXID on last batch 
		UPDATE @CleaningColumns
		SET MaxOrderID = @iCurrBatchOrderID
		WHERE BatchID = @iCurrBatchID;

		SELECT @iCurrID	= 0, 
				@iCurrBatchID = 0,
				@iCurrBatchOrderID = 0,
				@curDatabase = '',
				@curSchemaName = '',
				@curTableName = '';



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
			SELECT	@iCurrID	=	@iCurrID + 1, @SqlDynamic='', @curExclusionCsIdList = '', @curIDColumnName=0;
			SELECT	@SqlDynamic	=	CONCAT(
					'INSERT INTO dbo.CleaningVerificationSample (CleaningColumnID, OriginalSampleData, RowID) 
					  SELECT TOP(1) ',C.CleaningColumnID, ', CONVERT(NVARCHAR(500),[',C.ColumnName,']), ', C.IDColumnName,    
					' FROM [',C.DatabaseName,'].[',C.SchemaName,'].[',C.TableName,']  
					  WHERE LEN(CONVERT(VARCHAR(500),[',ColumnName,'])) > 0'),
					 @curExclusionCsIdList =  ISNULL(E.curExclusionCsIdList,''),
					 @curIDColumnName = C.IDColumnName
			FROM @CleaningColumns as C 
				-- 202306: This will make sure we don't pull rows that are excluded from the cleaning.
				LEFT JOIN (	SELECT DatabaseName, SchemaName, TableName, STRING_AGG(ExcludeId,',') AS curExclusionCsIdList 
							FROM	dbo.CleaningRowExclude
							GROUP BY DatabaseName, SchemaName, TableName
							) AS E
							ON E.DatabaseName = C.DatabaseName AND E.SchemaName = C.SchemaName AND E.TableName = C.TableName
			WHERE ID = @iCurrID;
			IF LEN(@curExclusionCsIdList) > 1
			BEGIN
				SELECT	@SqlDynamic	= 	CONCAT(@SqlDynamic,' AND ',@curIDColumnName,' NOT IN (',@curExclusionCsIdList,');');
			END;

			BEGIN TRY
				EXEC(@SqlDynamic);
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Load Sample Data','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				PRINT(@SqlDynamic);
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Load Sample Data','DATA CLEANING: Verification', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N', @SqlDynamic);
			END CATCH
		END; -- VERIFICATION SET UP WHILE LOOP END

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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Triggers Loaded','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Triggers Load ERROR','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
			END CATCH
		END; -- TRIGGER FIND WHILE LOOP END

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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Disabled', @PkgGUID, getutcdate(), 'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Disabled ERROR', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
			END CATCH
		END; -- TRIGGER DISABLE WHILE LOOP END


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
					HistoryTableName varchar(250),
					Relink bit);
			DECLARE @tCount int = 0;
			DECLARE @ttSql varchar(2500);
			DECLARE @dtSql varchar(2500);

			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
			VALUES (@ParentAuditKey, 'DATA CLEANING: Begin-Temporal','Deleting History Tables', @PkgGUID, getutcdate(), 'Y');

			INSERT INTO @tTemporalHistory
			SELECT DatabaseName, TableSchema, TableName, HistorySchema, HistoryTableName, ReLink
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
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Unlink Failure', @PkgGUID, getutcdate(), 'N', @ttsql);
				END CATCH

				BEGIN TRY
					EXEC(@dtsql);
				END TRY
				BEGIN CATCH
					PRINT(@dtsql)
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, 'DATA CLEANING: Temporal','Data Delete Failure', @PkgGUID, getutcdate(), 'N', @ttsql);
				END CATCH;

				SELECT @tCount = @tCount - 1, @ttSql = '';
			END; -- TEMPORAL TABLE WHILE LOOP END
		END; -- CLEAN TEMPORAL TABLES (IF)


		/*
		==========================================
		MAIN SECTION FOR CLEANING THE DATA
		JULY 2023 UPDATE: Worked to Batch updates for same table together.
		==========================================
		*/
		--  Audit and error logging
		INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
		VALUES (@ParentAuditKey, 'DATA CLEANING: Begin-Tables','DATA CLEANING: DBClean-Start', @PkgGUID, getutcdate(), 'Y');
		
		SELECT	@iCurrID	= 0, 
				@TsqlUpdateColumnSelect='',
				@TsqlUpdateFrom='',
				@TsqlUpdateColumnWhere='',
				@SqlDynamic='',
				@iLoopMaxID = MAX(ID) 
		FROM @CleaningColumns;
		
		
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
					@curExclusionCsIdList	=	'',
					@curHasExclusionCsIdList=	0,
					@curTablePath			=	'',
					@curRowCount			=	0;

			SELECT	@curDatabase			=	DatabaseName,
					@curSchemaName			=	SchemaName,
					@curTableName			=	TableName,
					@curColumnName			=	ColumnName,
					@curGenderRefColumnName	=	(CASE WHEN GenderRefColumnName = 'Email' THEN '0'  WHEN LEN(GenderRefColumnName) > 1 THEN CONCAT('C.',GenderRefColumnName) ELSE '0' END),
					@curIDColumnName		=	IDColumnName,
					@curDataType			=	DataType,
					@curUsesGenerationDb	=	UsesGenerationDb,
					@curHasExclusionCsIdList=	HasExclusionCsIdList,
					@curTablePath			=	CONCAT('[',DatabaseName,'].[',SchemaName,'].[',TableName,']'),
					@dtStartTime			=	getutcdate(),
					@iRandom				=	LEFT(DATEPART(s,getutcdate()),1),  -- Num 0-9 with 0-5 hit most often
					@iCurrBatchID			=	BatchID,
					@iCurrBatchOrderID		=	OrderID,
					@iCurrBatchMaxOrderID	=	MaxOrderID
			FROM @CleaningColumns
			WHERE ID = @iCurrID;

			-- TSQL HEADER: Already set in variable as 'UPDATE C SET '
			-- SET UP THE FROM CLAUSE
			IF @iCurrBatchOrderID = 1
			BEGIN
				SELECT	@TsqlUpdateFrom		=	CONCAT(' FROM ',@curTablePath,' AS C ');
			END;
			IF (CHARINDEX('APPLY',@TsqlUpdateFrom) = 0) AND 
					(@curDataType IN ('USERNAME','USER','LOGIN','LOGON','USR','USRNAME','PASSWORD','PASS','PWD','PWORD','PWRD','PSWD','FIRSTNAME','FNAME','FIRST','LASTNAME','LNAME','LAST','FULLNAME'))
				BEGIN
					SELECT	@TsqlUpdateFrom	=	CONCAT(@TsqlUpdateFrom,' CROSS APPLY dbo.tfnFullNameGet(C.',@curIDColumnName,',''',ISNULL(@curGenderRefColumnName,'0'),''',',@iRandom,') AS N  ');
				END;
			-- Add comma if this is the second+ column in a list
			IF @iCurrBatchOrderID > 1
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,', '),
						@TsqlUpdateColumnWhere		=	CONCAT(@TsqlUpdateColumnWhere,' OR LEN(C.[',@curColumnName,']) > 0 ')
			END;
			ELSE -- When OrderID  = 1
			BEGIN 
				IF  @curHasExclusionCsIdList = 1
				BEGIN
					SELECT @curExclusionCsIdList = STRING_AGG(ExcludeId,',')
					FROM [dbo].[CleaningRowExclude]
					WHERE DatabaseName = @curDatabase AND SchemaName = @curSchemaName AND TableName = @curTableName AND IDColumnName = @curIDColumnName;

					SELECT	@TsqlUpdateColumnWhere		=	CONCAT(' WHERE (C.',@curIDColumnName,' NOT IN (',@curExclusionCsIdList,')) AND ( LEN(C.[',@curColumnName,']) > 0 ')
				END
				ELSE
				BEGIN
					SELECT	@TsqlUpdateColumnWhere		=	CONCAT(' WHERE ( LEN(C.[',@curColumnName,']) > 0 ')
				END;	
			END;

			--Complile the SELECT/SET STATEMENT for  COLUMN.
			-- BATCH 01 UPDATES: UserName: 
			IF @curDataType IN ('USERNAME','USER','LOGIN','LOGON','USR','USRNAME')
			BEGIN
				IF @curGenderRefColumnName = 'Email'
				BEGIN
					-- This condition CLEANS for a LOGIN/USERNAME scenario that use an EMAIL address for logon.
					SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Lname,',@iRandom,'),LEFT(N.Fname,2),''@web.com'','''') ');
				END
				ELSE
				BEGIN
					SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Lname,',@iRandom,'),LEFT(N.Fname,2),'''') ');
				END;
			END;

			-- BATCH 2 UPDATES: Password
			IF @curDataType IN ( 'PASSWORD','PASS','PWD','PWORD','PWRD','PSWD' )
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Lname,2),LEFT(N.Fname,2),dbo.fnPasswordGenerator(7),'''') ');
			END;
			
			-- BATCH 03 UPDATES: Email
			IF @curDataType IN ( 'EMAIL','MAIL','E-MAIL','WEBMAIL')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = ''',@email,''' ');
			END;

			-- BATCH 04 UPDATES: DOB as datetime
			IF @curDataType IN ( 'DOB','DATE','DOD','BIRTH','BIRTHDATE','BIRTHDAY','DEATH','DAY','CREATED','UPDATED' )
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	(CASE WHEN [',@curColumnName,'] IS NULL THEN [',@curColumnName,'] ELSE dbo.udfRandomDOBgenerator()  END)' );
			END;

			-- BATCH 05 UPDATES: [SSNID] SSN & Other IDs as Numberic -- MASK all but last 2
			IF @curDataType IN ( 'SSNID', 'SSNINT')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	(999999900+',@iRandom,'+CONVERT(int,RIGHT([',@curColumnName,'],2))) ');
			END;

			-- BATCH 06 UPDATES: [SSNCHAR]  SSN & Other IDs as varchar 
			IF @curDataType IN ('SSN', 'SSNCHAR' )
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	(''999999',@iRandom,'''+RIGHT([',@curColumnName,'],2) ) ');
			END;

			-- BATCH 07 UPDATES: [FIRSTNAME] FirstName with/without Gender Column
			IF @curDataType IN ('FIRSTNAME','FNAME','FIRST')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	N.FName ');
			END;

			-- BATCH 09 UPDATES: [LASTNAME]
			IF @curDataType IN ( 'LASTNAME','LNAME','LAST')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	N.LName ');
			END;

			-- BATCH 10 UPDATES: [FULLNAME]
			IF @curDataType = 'FULLNAME'
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',LEFT(N.Fname,18),'' '',LEFT(N.Lname,30),'''') ');
			END;

			-- BATCH 11 UPDATES: [ADDRESS1]
			IF @curDataType IN ('ADDRESS','ADDRESS1','ADR','ADDR','ADDR1')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomAddress1([',@curColumnName,']) ');
			END;

			--BATCH 12 UPDATES: [ADDRESS2] also 3/4 use UNIT+ ID#
			IF @curDataType IN ('ADDRESS2','ADDRESS3','ADDRESS4')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomAddress2(LEFT([',@curColumnName,'],30)) ');
			END;	
			
			-- BATCH 13 UPDATES: [TRUNCATE] Tables to delete all data
			IF @curDataType IN ( 'REMOVE','NOTE','CLEAN','X','CLEAR','BLANK','OLD')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = ''CLEANED'' ');
			END;
			IF @curDataType IN ( 'CLEAR','CLEARDATE')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = ''1901-01-01'' ');
			END;
			IF @curDataType IN ( 'ZERO','RESETNUM','ZERONUMBER')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] = 0 ');
			END;

			-- BATCH 14 UPDATES: [PHONE]
			IF @curDataType IN ('PHONE','PHONECHAR')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomPhone([',@curColumnName,']) ');
			END;

			-- BATCH 15a UPDATES: [PHONEINT]
			IF @curDataType IN ('PHONEINT','PHONEID')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	REPLACE(dbo.udfRandomPhone([',@curColumnName,']),''-'','''') ');
			END;

			-- BATCH 15b UPDATES: [PHONENUM]
			IF @curDataType IN ('PHONENUM','PHONE10')
			BEGIN
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	CONCAT('''',(  RIGHT((REPLACE(dbo.udfRandomPhone([',@curColumnName,']),''-'','''')),10)   ),'''') ');
			END;

			-- BATCH 16 UPDATES: [PINn]
			IF LEFT(@curDataType,3) = 'PIN'
			BEGIN    -- ie PIN4 = 4  PIN12 = 12
				SELECT	@TsqlUpdateColumnSelect		=	CONCAT(@TsqlUpdateColumnSelect,' [',@curColumnName,'] =	dbo.udfRandomPin(',REPLACE(@curDataType,'PIN',''),')  ');
			END;

			IF @iCurrBatchOrderID = @iCurrBatchMaxOrderID
			BEGIN
				-- Set last parentheses on WHERE clause
				SELECT @TsqlUpdateColumnWhere		=	CONCAT(@TsqlUpdateColumnWhere,' );');
				-- EXECUTE STATEMENT and RESET Tsql
				SELECT @SqlDynamic = CONCAT(@TsqlUpdateHeader,@TsqlUpdateColumnSelect,@TsqlUpdateFrom,@TsqlUpdateColumnWhere);	

				BEGIN TRY
					EXEC(@SqlDynamic);
					SELECT @curRowCount = @@ROWCOUNT;
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, @curTablePath,'DATA CLEANING: Clean Rows', @PkgGUID, @dtStartTime, getutcdate(), @curRowCount,  'Y', LEFT(@SqlDynamic,2000));
				END TRY
				BEGIN CATCH 
					SELECT @curRowCount = @@ROWCOUNT;
					PRINT(@SqlDynamic);
					INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT],  [ExecStopDT], [ErrorRowCnt], [SuccessfulProcessingInd], [SqlStatement])
					VALUES (@ParentAuditKey, @curTablePath,'DATA CLEANING: Clean Rows', @PkgGUID, @dtStartTime,  getutcdate(), @curRowCount, 'N', LEFT(@SqlDynamic,2000));
				END CATCH;
				SELECT @TsqlUpdateColumnSelect='',@TsqlUpdateFrom='',@TsqlUpdateColumnWhere='',@SqlDynamic='';
			END;
			----- [MAIN LOOP END]
		END; --------- MAIN LOOP END (Line 369)



		/*
		==========================================
		TEMPORAL TABLES RELINKING - Added June 2023
		==========================================
		*/

		If @CleanTemporalTables = 1
		BEGIN
			DECLARE @ReLink bit;
			INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
			VALUES (@ParentAuditKey, 'DATA CLEANING: PostClean-Temporal','BEGIN History Table Linking', @PkgGUID, getutcdate(), 'Y');

			SELECT @tCount = MAX(ID) FROM @tTemporalHistory;

			WHILE @tCount > 0
			BEGIN
				SELECT	@ttSql = CONCAT('ALTER TABLE ',DatabaseName,'.',TableSchema,'.',TableName,' SET (SYSTEM_VERSIONING = ON
							(HISTORY_TABLE=',HistorySchema,'.',HistoryTableName,',DATA_CONSISTENCY_CHECK=OFF))'),
						@ReLink = Relink
				FROM @tTemporalHistory
				WHERE ID = @tCount;

				IF @Relink = 1
				BEGIN
					BEGIN TRY
						PRINT(@ttsql)
						EXEC(@ttsql);
						WAITFOR DELAY '00:00:01';
						INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
						VALUES (@ParentAuditKey, 'DATA CLEANING: PostClean-Temporal','History Relinked', @PkgGUID, getutcdate(), 'Y', @ttsql);
					END TRY
					BEGIN CATCH
						PRINT(@ttsql)
						INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
						VALUES (@ParentAuditKey, 'DATA CLEANING: PostClean-Temporal','Relink Failure', @PkgGUID, getutcdate(), 'N', @ttsql);
					END CATCH;
				END;

				SELECT @tCount = @tCount - 1, @ttSql = '', @ReLink=0;
			END; -- TEMPORAL TABLE WHILE LOOP END
		END; -- CLEAN TEMPORAL TABLES (IF)



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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Enabled', @PkgGUID, getutcdate(), 'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @SqlDynamic = RIGHT(@SqlDynamic,50);
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, @SqlDynamic,'DATA CLEANING: Trigger Enabled ERROR', @PkgGUID, getutcdate(), 'N', @SqlDynamic);
				SELECT @curRowCount =	@curRowCount + 1;
			END CATCH
		END; -- TRIGGER ENABLE WHILE LOOP END

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
										INNER JOIN [',C.DatabaseName,'].[',C.SChemaName,'].[',C.TableName,'] AS E ON V.RowID = E.',C.IDColumnName,'
										WHERE V.ID = ',@iCurrID,';')
			FROM dbo.CleaningVerificationSample V
			INNER JOIN dbo.CleaningColumns C ON V.CleaningColumnID = C.ID  -- @CleaningColumns changed to dbo.CleaningColumns
			WHERE V.ID = @iCurrID;

			BEGIN TRY
				EXEC(@SqlDynamic);
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Sample Data','Verification Updated', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'Y', @SqlDynamic);
			END TRY
			BEGIN CATCH
				--  Audit and error logging
				SELECT @curRowCount = @@ROWCOUNT;
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Sample Data','Ver Update failure', @PkgGUID, getutcdate(), getutcdate(), @curRowCount,  'N', @SqlDynamic);
			END CATCH
			SELECT @curRowCount = 0;
		END; -- VERIFICATION WHILE LOOP END

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
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [ExecStopDT], [UpdateRowCnt], [SuccessfulProcessingInd], [SqlStatement])
				VALUES (@ParentAuditKey, 'DATA CLEANING: Email Errors','FAILED to send email alert', @PkgGUID, getutcdate(), getutcdate(), 0,  'N', LEFT(@Body,2000));
			END CATCH;
		END; -- Success / Failure Actions

	END -- QA ON (line 48)

	IF @DebuggerON = 1
	BEGIN		
		SELECT * from dbo.CleaningVerificationSample		
		SELECT * FROM dbo.DimAudit WHERE ParentAuditKey = @ParentAuditKey ORDER BY 1 DESC;
		SELECT * from dbo.CleaningTriggers;
	END;

END -- END SPROC

GO












