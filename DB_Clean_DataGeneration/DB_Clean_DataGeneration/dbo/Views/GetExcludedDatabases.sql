
CREATE VIEW [dbo].[GetExcludedDatabases]
AS

	SELECT DatabaseName
	FROM dbo.Validator
	WHERE IsActive = 1 and Status = 'exclude';


