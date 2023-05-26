

CREATE   FUNCTION [dbo].[fnRemoveNumericChar] 
(@strText varchar(500)) 
RETURNS varchar(500)
AS 
BEGIN 

	DECLARE @NumRange as varchar(50) = '%[0-9]%';
    WHILE PatIndex(@NumRange, @strText) > 0
        SET @strText = Stuff(@strText, PatIndex(@NumRange, @strText), 1, '');
    RETURN @strText;

END;
