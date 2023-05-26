

CREATE   FUNCTION [dbo].[fnPasswordGenerator] 
(@len INT) -- Length of Password
RETURNS varchar(100)
AS
BEGIN
	DECLARE @char CHAR = ''
	DECLARE @charI INT = 0
	DECLARE @password VARCHAR(100) = ''
	WHILE @len > 0
	BEGIN
	SET @charI = ROUND((select rndResult from dbo.rnfView)*100,0)
	SET @char = CHAR(@charI)
 
	IF @charI > 48 AND @charI < 122
	BEGIN
	SET @password += @char
	SET @len = @len - 1
	END
	END
	RETURN @password
END
