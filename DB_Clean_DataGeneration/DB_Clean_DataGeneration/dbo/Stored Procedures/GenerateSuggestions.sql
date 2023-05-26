

CREATE   PROCEDURE [dbo].[GenerateSuggestions]
AS
BEGIN


DECLARE @LookupType as Table (ID INT NOT NULL IDENTITY(1,1), DataTypeName VARCHAR(50), Keyword VARCHAR(50), IsInt bit);
DECLARE @StartID INT;
SELECT @StartID = MAX(ID)
FROM  dbo.CleaningColumns;

	INSERT INTO @LookupType
	select c.DataTypeName, s.value, c.IsInt
	FROM dbo.CleaningDataType c
	CROSS APPLY string_split(c.keywordList,',') s 
	WHERE c.IsActive=1 and LEN(S.value) > 1;

	INSERT INTO dbo.CleaningColumns
	([DatabaseName], [SchemaName], [TableName], [ColumnName], [GenderRefColumnName], [IDColumnName], [DataType], [IsActive], [UsesGenerationDb])
	SELECT q.DatabaseName,q.SchemaName,q.TableName,q.ColumnName,NULL,NULL,DataTypeName,1,1
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
	-- filter out rows already in our table
	LEFT JOIN dbo.CleaningColumns c ON 
			q.DatabaseName = c.DatabaseName and
			q.SchemaName = c.SchemaName and
			q.TableName = c.TableName and
			q.ColumnName = c.ColumnName
	WHERE c.ColumnName IS NULL and q.Rowid = 1	
	ORDER BY DatabaseName,SchemaName,TableName,ColumnName;





		-- Lookup ID Column  (Mark missing/multiple CREATED WITHOUT ID COLUMN REVIEW)

		DECLARE @PkIdUpdateSql varchar(3000);
		DECLARE @iTableLoop int;

		SELECT @iTableLoop = 1 + COUNT(*) 
		FROM
			( SELECT COUNT(*) As TableCount from dbo.CleaningColumns where IDColumnName is null GROUP BY DatabaseName, SchemaName, TableName )q
		
		While @iTableLoop > 0
		BEGIN
			SELECT @PkIdUpdateSql = CONCAT(
					'UPDATE c
					SET IDColumnname = q.IDColumnname		
					FROM dbo.CleaningColumns c
					INNER JOIN 
					(SELECT ''',DatabaseName,''' as DatabaseName, ''',TableName,''' as TableName, ''',SchemaName,''' as SchemaName,
							ISNULL(',DatabaseName,'.dbo.TablePrimaryKeyColumnNameGet(''',TableName,''',''',SchemaName,'''),''ID'') as IDColumnname) q
					ON c.DatabaseName = q.DatabaseName and c.TableName = q.TableName and c.SchemaName = q.SchemaName
					')
			FROM dbo.CleaningColumns 
			WHERE IDColumnName is null;

			EXEC(@PkIdUpdateSql);
			SELECT @iTableLoop = @iTableLoop -1, @PkIdUpdateSql='';
		END;

		

	-- Lookup Gender Column  (Mark multiple CREATED BUT MULTI GENDER COLUMNS FOUND - REVIEW)
	UPDATE c
	SET GenderRefColumnName = z.GenderRefColumnName
	FROM dbo.CleaningColumns c
	INNER JOIN 
				(SELECT v.DatabaseName, v.SchemaName, v.TableName, v.ColumnName, 
					( CASE COUNT(*) WHEN 1 THEN v.ColumnName ELSE 'MULTI-FOUND' END) As GenderRefColumnName
				FROM dbo.Validator v
				INNER JOIN (
							SELECT DatabaseName, SchemaName, TableName 
							FROM dbo.CleaningColumns 
							WHERE (ColumnName like '%name%') and (GenderRefColumnName is null or LEN(GenderRefColumnName) < 2)
							GROUP BY DatabaseName, SchemaName, TableName) q
						ON v.DatabaseName = q.DatabaseName and  v.SchemaName = q.SchemaName and v.TableName = q.TableName
				WHERE V.ColumnName LIKE '%GENDER%' or V.ColumnName LIKE '%SEX%'
				GROUP BY v.DatabaseName, v.SchemaName, v.TableName, v.ColumnName) z
		ON c.DatabaseName = z.DatabaseName and  c.SchemaName = z.SchemaName and c.TableName = z.TableName
 WHERE (c.GenderRefColumnName is null or LEN(c.GenderRefColumnName) < 2)
	and (c.ColumnName like '%name%');
				
select * FROM dbo.CleaningColumns  WHERE  LEN(GenderRefColumnName) > 1;

	UPDATE v
	SET Status = (Case when v.IsActive = 1 then 'cleaning' else 'clean-inactive' end)
	FROM dbo.Validator  AS v
		INNER JOIN dbo.CleaningColumns AS c
			ON v.DatabaseName  = c.DatabaseName
			AND v.SchemaName = C.SchemaName
			AND v.TableName = c.TableName
			AND v.ColumnName = c.ColumnName;
	SELECT *
	FROM  dbo.CleaningColumns
	WHERE ID > @StartID
	ORDER BY DatabaseName, SchemaName, TableName, ColumnName;

END
