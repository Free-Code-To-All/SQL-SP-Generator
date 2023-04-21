SET NOCOUNT ON
DECLARE @tableName VARCHAR(100)
DECLARE @sql VARCHAR(MAX) = ''

DECLARE tableCursor CURSOR FOR
SELECT name 
FROM sys.tables
where name not like '%diagram%'
order by name

OPEN tableCursor

FETCH NEXT FROM tableCursor INTO @tableName

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @columnsList NVARCHAR(MAX)
    SET @columnsList = ''

    DECLARE @primaryKey NVARCHAR(MAX)
    SET @primaryKey = ''

    SELECT @columnsList = @columnsList + '[' + name + '],' FROM sys.columns 
    WHERE object_id = OBJECT_ID(@tableName)
	AND is_identity = 0

    --SELECT @primaryKey = @primaryKey + '[' + name + '],' FROM sys.columns
    --WHERE object_id = OBJECT_ID(@tableName) AND is_identity = 1

	SELECT @primaryKey = @primaryKey + '[' + c.name + '],' 
	FROM sys.indexes i
	INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
	INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
	WHERE i.is_primary_key = 1 AND i.object_id = OBJECT_ID(@tableName)
	ORDER BY C.column_id

	IF LEN(@columnsList)>1
		SET @columnsList = LEFT(@columnsList, LEN(@columnsList) - 1)
    IF LEN(@primaryKey)>1
		SET @primaryKey = LEFT(@primaryKey, LEN(@primaryKey) - 1)

    DECLARE @insertParams NVARCHAR(MAX)
    SET @insertParams = ''

    DECLARE @updateParams NVARCHAR(MAX)
    SET @updateParams = ''

    SELECT @insertParams = @insertParams + '[' + name + '],' 
	FROM sys.columns 
    WHERE object_id = OBJECT_ID(@tableName)
	AND is_identity = 0

    SELECT @updateParams = @updateParams + '[' + name + ']=@' + name + ',' 
	FROM sys.columns C
    WHERE object_id = OBJECT_ID(@tableName)
	AND is_identity = 0
	ORDER BY C.column_id

    IF LEN(@insertParams)>1
		SET @insertParams = LEFT(@insertParams, LEN(@insertParams) - 1)
	SET @insertParams = UPPER(REPLACE(REPLACE('@' + REPLACE(@insertParams, ',', ', @'), '[', ''), ']', '')) 
    IF LEN(@updateParams)>1
		SET @updateParams = LEFT(@updateParams, LEN(@updateParams) - 1)

    DECLARE @insertParamsWithType NVARCHAR(MAX)
    SET @insertParamsWithType = ''

    DECLARE @updateParamsWithType NVARCHAR(MAX)
    SET @updateParamsWithType = ''

    SELECT @insertParamsWithType = @insertParamsWithType + '[' + c.name + '] ' + t.name + ',' 
	FROM sys.columns c join sys.types t ON c.system_type_id = t.system_type_id
    WHERE object_id = OBJECT_ID(@tableName)
	AND is_identity = 0
	ORDER BY C.column_id

    SELECT @updateParamsWithType = @updateParamsWithType + '[' + c.name + '] ' + t.name + ',' 
	FROM sys.columns c join sys.types t ON c.system_type_id = t.system_type_id
    WHERE object_id = OBJECT_ID(@tableName)
	ORDER BY C.column_id

	SET @insertParamsWithType = '@'+UPPER(REPLACE(REPLACE(REPLACE(REPLACE(LEFT(@insertParamsWithType, LEN(@insertParamsWithType) - 1), ',', ','+char(13)+'@'), 'varchar','varchar(max)'), '[',''), ']',''))
    SET @updateParamsWithType = '@'+UPPER(REPLACE(REPLACE(REPLACE(REPLACE(LEFT(@updateParamsWithType, LEN(@updateParamsWithType) - 1), ',', ','+char(13)+'@'), 'varchar','varchar(max)'), '[',''), ']',''))

    SET @sql =  N'
/* '+@tableName+' Select All */
CREATE OR ALTER PROCEDURE dbo.SP_' + @tableName + '_SelectAll
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRAN
		SELECT * 
		FROM dbo.' + @tableName + '
	COMMIT
END
				
GO
				
'

    SET @sql = @sql + N'
/* '+@tableName+' Select By ID */
CREATE OR ALTER PROCEDURE dbo.SP_' + @tableName + '_SelectByID
@ID INT
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRAN
		SELECT * 
		FROM dbo.' + @tableName + ' 
		WHERE ' + @primaryKey + ' = @ID
	COMMIT
END
				
GO
	'

    SET @sql = @sql + N'
/* '+@tableName+' Insert */
CREATE OR ALTER PROCEDURE dbo.SP_' + @tableName + '_Insert(
' + @insertParamsWithType + ' 
)
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRAN
		INSERT INTO dbo.' + @tableName + '(' + @columnsList + ') 
		VALUES (' + @insertParams + ') 
		SELECT SCOPE_IDENTITY()
	COMMIT
END
				
GO
	'

    SET @sql = @sql + N'
/* '+@tableName+' Update */
CREATE OR ALTER PROCEDURE dbo.SP_' + @tableName + '_Update(
' + @updateParamsWithType + ' 
)
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRAN
		UPDATE dbo.' + @tableName + ' 
		SET ' + @updateParams + ' 
		WHERE ' + @primaryKey + ' = @'+ UPPER(REPLACE(REPLACE(@primaryKey, '[', ''), ']', '')) +'
	COMMIT
END
				
GO
		'

    --PRINT @sql

    SET @sql = @sql + N'
/* '+@tableName+' Delete */
CREATE OR ALTER PROCEDURE dbo.SP_' + @tableName + '_Delete
@'+ UPPER(REPLACE(REPLACE(@primaryKey, '[', ''), ']', '')) +' INT
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRAN
		DELETE FROM dbo.' + @tableName + ' 
		WHERE ' + @primaryKey + ' = @'+ UPPER(REPLACE(REPLACE(@primaryKey, '[', ''), ']', '')) +'
	COMMIT
END
				
GO
	'
   PRINT @sql

    FETCH NEXT FROM tableCursor INTO @tableName
END

CLOSE tableCursor
DEALLOCATE tableCursor