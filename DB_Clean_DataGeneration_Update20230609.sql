
/*   CLEANING SOLUTION REVISIONS JUNE 2023  


Run this script for the latest Stored Proc changes.

BUG FIXES

1. Function that created PHONE NUMBER will no longer include dashes. This will allow full 10 digit numbers to work with varchar(10) datatype.

2. Initial VALIDATOR GENERATOR will also check the existing live val;idator table for active entries when listing DATAGBASES to re/evaluate.

3. PREVIEW and SUGGESTION sprocs will now eliminate any DATE item when the DataType DATE is set to FALSE.  This will remove some false positives such as FIRSTcreateDATE or LASTmodifiedDATE that were being flagged as FISTNAME/LASTNAME.

4. New SPROCS added to ewasily ADD/REMOVE individual items from the solutuion.

*/



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
	SELECT @Phone			=	dbo.fnRemoveNonNumericChar(@Phone);
	SELECT @KeepPreDigits	=	(CASE WHEN LEFT(@Phone,1) IN (0,1) THEN 4 ELSE 3 END);
	SELECT @NewPhone		=	(CASE	WHEN LEN(@Phone) > 0 THEN  (CONCAT(LEFT(@Phone,@KeepPreDigits),CONVERT(varchar(8),dbo.udfRandomPIN(3)), CONVERT(varchar(8),dbo.udfRandomPIN(4)))) ELSE @Phone END);
	RETURN @NewPhone;
END 
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

/****** Object:  StoredProcedure [dbo].[CleaningColumnRemoveNow]    Script Date: 6/9/2023 12:59:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE  OR ALTER          PROCEDURE [dbo].[CleaningColumnRemoveNow] 
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

/****** Object:  StoredProcedure [dbo].[CleaningColumnAddNow]    Script Date: 6/9/2023 12:59:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   OR ALTER         PROCEDURE [dbo].[CleaningColumnAddNow] 
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

USE [DB_Clean_DataGeneration]
GO
/****** Object:  StoredProcedure [dbo].[GeneratorUpdateBaseColumns]    Script Date: 6/9/2023 1:11:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER     PROCEDURE [dbo].[GeneratorUpdateBaseColumns] 
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

USE [DB_Clean_DataGeneration]
GO

/****** Object:  StoredProcedure [dbo].[ColumnsToAlwaysIgnore]    Script Date: 6/9/2023 1:26:11 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE       PROCEDURE [dbo].[ColumnsToAlwaysIgnore]
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




