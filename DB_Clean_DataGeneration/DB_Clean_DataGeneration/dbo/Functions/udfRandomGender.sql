

CREATE FUNCTION [dbo].[udfRandomGender] 
() 
RETURNS VARCHAR(10) 
AS 
BEGIN 
 	 DECLARE @Gender varchar(10)
	 
	 SELECT TOP 1 @Gender = Gender FROM ( SELECT DISTINCT Gender FROM tFirstNames ) T ORDER BY (SELECT [NewId] FROM GetNewID)
 
    RETURN @Gender
END 


