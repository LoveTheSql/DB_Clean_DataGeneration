

CREATE   FUNCTION [dbo].[udfRandomPIN] 
(@digits int) 
RETURNS int
AS 
BEGIN 
	DECLARE @PIN INT;
	SELECT @PIN	=	LEFT(CAST(rndResult*1000000000+999999 AS INT),@digits) FROM dbo.rnfView;
	RETURN @PIN;
END 
