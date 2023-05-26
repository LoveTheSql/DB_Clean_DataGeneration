



CREATE   FUNCTION [dbo].[udfRandomDOB] 
(@DOB date) 
RETURNS date
AS 
BEGIN 
	DECLARE @newDOB date
	SELECT @newDOB	=	 DATEADD(day, dbo.udfRandomPIN(2), DATEADD(year, 5-dbo.udfRandomPIN(2), getutcdate()));
	RETURN @newDOB;
END 
