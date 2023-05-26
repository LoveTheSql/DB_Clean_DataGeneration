CREATE     PROCEDURE [dbo].[TemporalListAddNew]
AS
BEGIN

	-- ADD NEW
	DECLARE @iCount INT = 0;
	DECLARE @tSql varchar(4000);
	DECLARE @DatabaseName varchar(250);
	SELECT @DatabaseName = ''

	DECLARE @tDatabases AS TABLE (		[ID] [int] IDENTITY(1,1) NOT NULL,
									[DatabaseName] [varchar](200) NULL);

	INSERT INTO @tDatabases (DatabaseName)
	SELECT DISTINCT DatabaseName
	FROM dbo.CleaningColumns
	WHERE  IsActive=1;

	SELECT @iCount = MAX(ID) FROM @tDatabases;

	WHILE @iCount > 0
	BEGIN
		SELECT @DatabaseName = DatabaseName
		FROM @tDatabases
		WHERE ID = @iCount;

		SELECT @tSql = CONCAT(
		'INSERT INTO dbo.CleaningTemporal (DatabaseName,TableSchema,TableName,HistorySchema,HistoryTableName,IsActive)
		SELECT ''',@DatabaseName,''', schema_name(t.schema_id), t.name, schema_name(h.schema_id), h.name,1
		FROM ',@DatabaseName,'.sys.tables t inner join ',@DatabaseName,'.sys.tables h on t.history_table_id = h.object_id
		WHERE t.temporal_type = 2
		and not exists (	SELECT * 
								FROM dbo.CleaningTemporal
								WHERE	DatabaseName = ''',@DatabaseName,'''
									AND	TableSchema = schema_name(t.schema_id)
									AND TableName = t.name
									AND HistorySchema = schema_name(h.schema_id)
									AND HistoryTableName = h.name)')

		EXEC(@tSql)

		SELECT @iCount = @iCount - 1, @DatabaseName = '', @tSql = '';
	END

	SELECT * FROM dbo.CleaningTemporal;
END

