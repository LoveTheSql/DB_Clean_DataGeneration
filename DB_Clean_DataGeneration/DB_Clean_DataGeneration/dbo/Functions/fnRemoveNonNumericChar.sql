


CREATE   FUNCTION [dbo].[fnRemoveNonNumericChar] 
(@strText varchar(500)) 
RETURNS varchar(500)
AS 
BEGIN 

	WHILE PATINDEX('%[^0-9]%', @strText) > 0
    BEGIN
        SET @strText = STUFF(@strText, PATINDEX('%[^0-9]%', @strText), 1, '')
    END
    RETURN @strText

END;
