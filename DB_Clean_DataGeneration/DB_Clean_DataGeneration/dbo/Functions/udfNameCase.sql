
CREATE FUNCTION [dbo].[udfNameCase] 
( 
    @strIn VARCHAR(255) 
) 
RETURNS VARCHAR(255) 
AS 
BEGIN 
    IF @strIn IS NULL 
        RETURN NULL 
 
    DECLARE 
        @strOut VARCHAR(255), 
        @i INT, 
        @Up BIT, 
        @c VARCHAR(2) 
 
    SELECT 
        @strOut = '', 
        @i = 0,  
        @Up = 1 
 
    WHILE @i <= DATALENGTH(@strIn) 
    BEGIN 
        SET @c = SUBSTRING(@strIn,@i,1) 
        IF @c IN (' ','-','''') 
        BEGIN 
            SET @strOut = @strOut + @c 
            SET @Up = 1 
        END 
        ELSE 
        BEGIN 
            IF @up = 1 
                SET @c = UPPER(@c) 
            ELSE 
                SET @c = LOWER(@c) 
 
            SET @strOut = @strOut + @c 
            SET @Up = 0 
        END 
        SET @i = @i + 1 
    END 
    RETURN @strOut 
END 
