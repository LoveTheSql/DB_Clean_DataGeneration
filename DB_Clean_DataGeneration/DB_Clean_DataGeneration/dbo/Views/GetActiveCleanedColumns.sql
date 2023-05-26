
CREATE VIEW [dbo].[GetActiveCleanedColumns]
AS

	SELECT DatabaseName, SchemaName, TableName, ColumnName, DataType
	FROM dbo.CleaningColumns
	WHERE IsActive = 1;

