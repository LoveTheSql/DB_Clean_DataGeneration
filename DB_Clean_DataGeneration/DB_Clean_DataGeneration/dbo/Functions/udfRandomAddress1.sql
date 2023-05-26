


CREATE   FUNCTION [dbo].[udfRandomAddress1] 
(@Address1 varchar(500)) 
RETURNS varchar(500)
AS 
BEGIN 
	DECLARE @NewAddress1 varchar(50);
	SELECT @NewAddress1		=	dbo.fnRemoveNumericChar(@Address1);
	SELECT @NewAddress1		=	(CASE	WHEN LEN(@Address1) > 0 THEN CONCAT(CONVERT(varchar(8),dbo.udfRandomPIN(4)),' ',LEFT(RTRIM(LTRIM(@NewAddress1)),2),'sample St.') ELSE @Address1 END);
	RETURN @NewAddress1;
END
