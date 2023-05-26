
-- =============================================
-- Author:		David Speight
-- Create date: 20210929
-- EXEC dbo.DataCleaning2021
-- =============================================
CREATE    PROCEDURE [dbo].[DataCleaningObjectInsert]
@DatabaseName varchar(200),
@SchemaName varchar(50),
@TableName varchar(200),	
@ColumnName varchar(200),
@GenderRefColumnName varchar(200),
@IDColumnName varchar(200),
@DataType varchar(50),				-- USERNAME,PASSWORD,EMAIL,DOB,SSNID,SSNCHAR,FIRSTNAME,LASTNAME,FULLNAME,ADDRESS1,ADDRESS2,TRUNCATE,PHONE,PINn,REMOVE
@IsActive bit = 1,
@UsesGenerationDb bit = 0
AS
BEGIN

INSERT INTO dbo.CleaningColumns
([DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb])
VALUES (@DatabaseName, @SchemaName, @TableName, @ColumnName, @GenderRefColumnName, @IDColumnName, @DataType, @IsActive, @UsesGenerationDb);

END
