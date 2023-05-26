


CREATE   FUNCTION [dbo].[udfRemoveIfNotNull] 
(@Value nvarchar(500), @RemoveWord nvarchar(50)) 
RETURNS nvarchar(50)
AS 
BEGIN 
	RETURN 	(CASE WHEN @Value IS NOT NULL THEN @RemoveWord ELSE @RemoveWord END);
END 
