
CREATE FUNCTION [dbo].[udfRandomFirstName] 
( 
    @Gender VARCHAR(6) 
) 
RETURNS VARCHAR(max) 
AS 
BEGIN 
    IF @Gender IS NULL OR (@Gender <> 'Female' AND @Gender <> 'Male')
        RETURN NULL 
 
	 DECLARE @FirstName varchar(max)
	 
	 SELECT TOP 1 @FirstName = [Name] FROM tFirstNames where Gender = @Gender ORDER BY (SELECT [NewId] FROM GetNewID)
 
    RETURN @FirstName
END 


