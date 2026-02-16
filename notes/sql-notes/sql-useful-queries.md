## **Check Table Sizes**
```
SELECT 
    t.name AS TableName,
    s.name AS SchemaName,
    p.rows,
    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
    CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB, 
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,
    CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.object_id = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    t.name NOT LIKE 'dt%' 
    AND t.is_ms_shipped = 0
    AND i.object_id > 255 
GROUP BY 
    t.name, s.name, p.rows
ORDER BY 
    TotalSpaceMB DESC, t.name
```

## **Check which sessions are using the most tempDB**

```
sp_who2
SELECT 
    session_id, 
    SUM(internal_objects_alloc_page_count + user_objects_alloc_page_count) * 8 AS total_kb_used
FROM sys.dm_db_session_space_usage
GROUP BY session_id
ORDER BY total_kb_used DESC;
```

## **Update Job info dynamically based on dbo.sysjobs** 
```
DECLARE @name VARCHAR(200)

DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM msdb.dbo.sysjobs
OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @name  
WHILE @@FETCH_STATUS = 0  
BEGIN  
      EXEC msdb.dbo.sp_update_job 
	 @job_name = @name,
	 @notify_level_email = 2,
	@notify_email_operator_name = N'DBA Team',
	@notify_page_operator_name = N'';
--comment out following line to disable netsend
--, @notify_netsend_operator_name = N''
--comment out following line to disable writing entry into Windows application log
--, @notify_level_eventlog = 0
      FETCH NEXT FROM db_cursor INTO @name 
END 
CLOSE db_cursor  
DEALLOCATE db_cursor;
```

## **Check all stored procedures for Object references**
```
USE [master]
GO

/****** Object:  StoredProcedure [dbo].[SHSP_ObjectRefCheck]    Script Date: 16/02/2026 16:32:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[SHSP_ObjectRefCheck]
      @ObjectRef         VARCHAR(150),
      @IncludeDefinition bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#Results') IS NOT NULL
        DROP TABLE #Results;

    CREATE TABLE #Results
    (
          [Database] SYSNAME
        , ObjectName SYSNAME
        , TypeDesc   NVARCHAR(60)
        , ModifyDate DATETIME
        , ObjectId   INT
        , Definition NVARCHAR(MAX) NULL
    );

    DECLARE @sql NVARCHAR(MAX) = N'';

    ;WITH DBs AS (
        SELECT name
        FROM sys.databases
        WHERE database_id > 4
          AND state = 0
    )
    SELECT @sql = @sql + '
    INSERT INTO #Results ([Database], ObjectName, TypeDesc, ModifyDate, ObjectId, Definition)
    SELECT
          ''' + name + ''' AS [Database]
        , o.name
        , o.type_desc
        , o.modify_date
        , m.object_id
        ' + CASE WHEN @IncludeDefinition = 1
                 THEN ', m.definition'
                 ELSE ', NULL'
            END + '
    FROM ' + QUOTENAME(name) + '.sys.sql_modules m
    INNER JOIN ' + QUOTENAME(name) + '.sys.objects o
        ON m.object_id = o.object_id
    WHERE o.type IN (''P'', ''V'', ''FN'', ''IF'', ''TF'')
      AND m.definition LIKE ''%'' + @ObjectRef + ''%'';
    '
    FROM DBs;

    EXEC sp_executesql
          @sql
        , N'@ObjectRef VARCHAR(150)'
        , @ObjectRef = @ObjectRef;

    SELECT *
    FROM #Results
    ORDER BY [Database], ObjectName;
END
GO

ALTER AUTHORIZATION ON [dbo].[SHSP_ObjectRefCheck] TO  SCHEMA OWNER 
GO
```

## **Change column collation for whole table** 
```
DECLARE @sql NVARCHAR(MAX);
DECLARE @colName SYSNAME;
DECLARE @dataType varchar(max);
DECLARE @length varchar(max);

DECLARE dbCursor CURSOR FOR
    SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'AHT_React4TenancyImportData'
	AND DATA_TYPE IN ('varchar','char'); -- Does not consider nvarchar, text, ntext
										 -- String does not concatenate with MAX
										 -- Use IF statement and CAST
OPEN dbCursor;
FETCH NEXT FROM dbCursor INTO @colName, @datatype, @length;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = 'ALTER TABLE [dbo].[AHT_React4TenancyImportData]
                ALTER COLUMN [' + @colName + '] '+@datatype +'('+@length+') COLLATE Latin1_General_CI_AS';
    PRINT @sql; -- For debugging
    EXEC(@sql);

    FETCH NEXT FROM dbCursor INTO @colName, @datatype, @length;
END

CLOSE dbCursor;
DEALLOCATE dbCursor;
```
## Check last backup times
```
SELECT   d.name,
         d.recovery_model_desc,
         MAX(b.backup_finish_date) AS backup_finish_date
FROM     master.sys.databases d
         LEFT OUTER JOIN msdb..backupset b
         ON       b.database_name = d.name
         AND      b.type          = 'L'
GROUP BY d.name, d.recovery_model_desc
ORDER BY backup_finish_date DESC
```
