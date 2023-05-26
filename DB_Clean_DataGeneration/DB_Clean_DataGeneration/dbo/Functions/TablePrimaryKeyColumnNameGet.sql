
-- =============================================
-- Author:		David Speight
-- Create date: 20230510
-- Description:	Returns the Primary Key COLUMN NAME of a table in the current database.
-- =============================================
CREATE FUNCTION [dbo].[TablePrimaryKeyColumnNameGet]
(
@TableName varchar(250),
@SchemaName varchar(100)
)
RETURNS varchar(250)
AS
BEGIN
	DECLARE @ColumnIDName varchar(250);

	SELECT @ColumnIDName = c.name
	FROM 
		sys.tables t 
		INNER JOIN sys.schemas s on t.schema_id = s.schema_id
		INNER JOIN sys.indexes ix on t.object_id = ix.object_id
		INNER JOIN sys.index_columns ixc ON ix.object_id = ixc.object_id and ix.index_id = ixc.index_id
		INNER JOIN sys.columns c ON ixc.object_id = c.object_id  and ixc.column_id = c.column_id
	WHERE ix.type > 0 and ix.is_primary_key = 1
		and t.name = @TableName
		and s.name = @SchemaName;

	RETURN @ColumnIDName;
END

