
CREATE   PROCEDURE [dbo].[GeneratorUpdateBaseColumns] 
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
