

CREATE   FUNCTION [dbo].[udfRandomAddress2] 
(@NewAddress varchar(30)) 
RETURNS varchar(30)
AS 
BEGIN 
	SELECT @NewAddress	=	 (CASE	WHEN LEN(@NewAddress) > 0 THEN CONCAT('Unit ',CONVERT(varchar(8),dbo.udfRandomPIN(3))) ELSE @NewAddress END);
	RETURN @NewAddress;
END 
