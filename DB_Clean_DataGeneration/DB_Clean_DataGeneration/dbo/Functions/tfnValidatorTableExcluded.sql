
CREATE   FUNCTION [dbo].[tfnValidatorTableExcluded]
(	
@DatabaseName varchar(250)
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT	DatabaseName, SchemaName, TableName
	FROM	dbo.Validator
	WHERE	DatabaseName = @DatabaseName
			and ObjectTypeName = 'table' 
			and Status = 'exclude'
)
