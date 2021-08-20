/*
Find any text
Useful for trying to determine what table stores particular information

SP_Find_any_text.sql

written by: Aaron Johnson
Inspired by: Stacy Berger
Ideas: 
Flag for if you look in views too (default to no) - done
Make it so that you can search every database on the server - looking into it.
use "like" instead of "="... perhaps flag that as an option too...
*/


GO


--create procedure SP_Find_any_text @lookup nvarchar(50) = NULL, @views nvarchar(1) = NULL
alter procedure SP_Find_any_text @lookup nvarchar(50) = NULL, @views nvarchar(1) = NULL
as

set nocount on
BEGIN


declare @match nvarchar(50), @scope nvarchar(50), @dbSQL nvarchar(max)

set @match = @lookup
set @scope = case
               when @views in ('Y','y') then '''VIEW'''
               when @views in ('B','b','X','x') then '''VIEW'' or  table_type = ''BASE TABLE'''
               else '''BASE TABLE'''
            end
set @dbSQL =  '
    --USE ? -- coment to restrict to current database
    insert into #databases
    select
        c.TABLE_CATALOG as [Database]
      , c.TABLE_SCHEMA as Schema_nm
      , t.table_type as Table_Type
      , c.table_name as Table_Name
      , c.column_name as Column_Name
      , case
          when c.data_type like ''%char%'' then c.data_type + ''('' + cast(c.character_maximum_length as varchar) + '')''
            else c.data_type
          end as Data_Type

    from information_schema.columns c
    join information_schema.tables t on c.table_name = t.table_name
    left outer join information_schema.key_column_usage k on c.table_schema = k.table_schema and c.table_schema = k.constraint_schema and c.table_name = k.table_name and c.column_name = k.column_name
    where 1 = 1
      and table_type = '+ @scope

--print @scope
--print @dbSQL

IF OBJECT_ID('tempdb..#databases') IS NOT NULL
    DROP TABLE #databases

create table #databases ([Database] varchar(255), Schema_nm varchar(255), Table_Type varchar(255), Table_Name varchar(255), Column_Name varchar(255), Data_Type varchar(255))
--EXEC sp_MSforeachdb @command1 = @dbSQL -- uncoment for all databases
EXEC sp_executesql @dbSQL -- coment for all databases

/*
select * 
from #databases
where 1 = 1
 --and [Database] not in ('tempdb','msdb','master')
 order by column_name
 */

DECLARE @sql VARCHAR(4000) 

IF OBJECT_ID('tempdb..#text_search') IS NOT NULL
    DROP TABLE #text_search  

CREATE TABLE #text_search (table_Name VARCHAR(200),column_name varchar(200), records INT)  
DECLARE tableNameCursor CURSOR  
 FOR  
SELECT 
     distinct Schema_nm,table_name
   , Column_Name 
from #databases  
JOIN sysObjects ON table_name = name  
WHERE 1 = 1
  and type = 'U' 
  and data_type like '%VARCHAR%'  
ORDER BY table_name   
  
OPEN tableNameCursor  
DECLARE @Schema_nm varchar(200),@table_Name VARCHAR(200), @column_name varchar(200)  
 FETCH NEXT FROM tableNameCursor INTO @Schema_nm,@table_Name,@column_name  
 WHILE (@@FETCH_STATUS = 0)  
  BEGIN  
  SELECT @sql =   
  'insert into #text_search (table_Name, column_name, records)  
  select '''+ @Schema_nm+'.'+@table_Name +''', '''+ @column_Name +''', count(*)  
  from ['+ @Schema_nm + '].['+ @table_Name +'] where ['+ @column_name +'] = ''' + @lookup + ''''  
  --PRINT (@sql)  
  EXEC (@sql)  
  
  FETCH NEXT FROM tableNameCursor INTO  @Schema_nm,@table_Name,@column_name   
  END   
  
CLOSE tableNameCursor  
DEALLOCATE tableNameCursor

SELECT * FROM #text_search WHERE records > 0  

DROP TABLE #text_search
DROP TABLE #databases
END