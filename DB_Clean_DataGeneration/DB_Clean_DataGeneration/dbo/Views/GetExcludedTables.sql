

CREATE VIEW [dbo].[GetExcludedTables]
AS

	SELECT DatabaseName, SchemaName, TableName
	FROM dbo.Validator
	WHERE IsActive = 1 and Status = 'exclude';


