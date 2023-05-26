
CREATE   PROCEDURE [dbo].[GeneratePreview]
AS
BEGIN

	DECLARE @LookupType as Table (ID INT NOT NULL IDENTITY(1,1), DataTypeName VARCHAR(50), Keyword VARCHAR(50), IsInt bit);

	INSERT INTO @LookupType
	select c.DataTypeName, s.value, c.IsInt
	FROM dbo.CleaningDataType c
	CROSS APPLY string_split(c.keywordList,',') s 
	WHERE c.IsActive=1 and LEN(S.value) > 1;

	SELECT *
	FROM 
		(
		SELECT 
				v.ID, v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName,v.ObjectTypeName,v.Status,
				v.DataType, v.GeneratorDataType, l.DataTypeName, l.Keyword, l.Isint,
				ROW_NUMBER() OVER(PARTITION BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName ORDER BY v.DatabaseName,v.SchemaName,v.TableName,v.ColumnName) As ROWID
		FROM	dbo.Validator v
				INNER JOIN @LookupType l 
					ON (v.ColumnName LIKE l.Keyword+'%')
					and (l.isint = 1 or LEFT(v.datatype,7) NOT IN (
					'bigint','binary','bit','decimal','float','geograp','geometr','hierarc','image','int','money','numeric','real','smallin','smallmo','sql_var','tinyint'
					)) 
				LEFT JOIN dbo.ValidatorAlwaysIgnore ai ON v.DatabaseName = ai.DatabaseName and v.SchemaName = ai.SchemaName and v.TableName = ai.TableName and v.ColumnName= ai.ColumnName
		WHERE	v.IsActive=1 and v.ObjectTypeName='column' and v.Status = 'standard'
				and ai.ColumnName is null
		) q
	WHERE q.Rowid = 1
	ORDER BY DatabaseName,SchemaName,TableName,ColumnName;


END
