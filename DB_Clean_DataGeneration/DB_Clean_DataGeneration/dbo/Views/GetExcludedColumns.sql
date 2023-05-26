
CREATE VIEW [dbo].[GetExcludedColumns]
AS

	SELECT  DatabaseName, SchemaName, TableName, ColumnName
	FROM dbo.Validator
	WHERE IsActive = 1 and Status in ('exclude','ignore');


