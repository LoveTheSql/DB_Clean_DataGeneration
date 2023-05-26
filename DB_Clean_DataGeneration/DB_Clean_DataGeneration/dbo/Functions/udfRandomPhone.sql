

CREATE   FUNCTION [dbo].[udfRandomPhone] 
(@Phone varchar(50)) 
RETURNS varchar(50)
AS 
BEGIN 
	DECLARE @NewPhone varchar(50);
	DECLARE @KeepPreDigits int;
	SELECT @Phone			=	dbo.fnRemoveNonNumericChar(@Phone);
	SELECT @KeepPreDigits	=	(CASE WHEN LEFT(@Phone,1) IN (0,1) THEN 4 ELSE 3 END);
	SELECT @NewPhone		=	(CASE	WHEN LEN(@Phone) > 0 THEN  (CONCAT(LEFT(@Phone,@KeepPreDigits),'-',CONVERT(varchar(8),dbo.udfRandomPIN(3)),'-', CONVERT(varchar(8),dbo.udfRandomPIN(4)))) ELSE @Phone END);
	RETURN @NewPhone;
END 
