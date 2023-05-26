
CREATE FUNCTION [dbo].[udfRandomLastName] 
() 
RETURNS VARCHAR(max) 
AS 
BEGIN 
 	 DECLARE @LastName varchar(max)
	 
	 SELECT TOP 1 @LastName = [Name] FROM tLastNames ORDER BY (SELECT [NewId] FROM GetNewID)
 
    RETURN @LastName
END 

