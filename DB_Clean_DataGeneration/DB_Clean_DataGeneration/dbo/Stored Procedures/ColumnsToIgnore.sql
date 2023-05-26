CREATE   PROCEDURE [dbo].[ColumnsToIgnore]
@IdList varchar(8000)
AS
BEGIN

	UPDATE dbo.Validator
	SET Status = 'ignore'
	WHERE ID IN (
				SELECT CONVERT(INT,value)
				FROM string_split(@IdList,','));

END
