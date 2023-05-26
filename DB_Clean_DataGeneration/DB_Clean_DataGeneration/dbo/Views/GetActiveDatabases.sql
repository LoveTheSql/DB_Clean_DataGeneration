

CREATE VIEW [dbo].[GetActiveDatabases]
AS

	SELECT DatabaseName
	FROM dbo.Validator
	WHERE IsActive = 1 and Status = 'parent';


