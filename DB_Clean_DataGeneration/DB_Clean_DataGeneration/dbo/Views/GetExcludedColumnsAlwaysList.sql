

CREATE VIEW [dbo].[GetExcludedColumnsAlwaysList]
AS

	SELECT  DatabaseName, SchemaName, TableName, ColumnName
	FROM dbo.ValidatorAlwaysIgnore;


