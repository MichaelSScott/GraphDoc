﻿CREATE FUNCTION [GraphDoc].[udf_cs_DepTable]
(
	@BaseObjectName nvarchar(255)	-- A single stored procedure name
)
/* 
	The return table here is defined like the user-defined table type udtt_DependencyGraph.
	As yet a udf can't return a udtt so we're stuck with doing it this way.
	Assumption is that object requested will be on the same server as the calling routine.
	An object might feasibly have namesakes in the database in different schemas or with different
	object types. In that case the caller will get all of them returned.
*/
RETURNS @returntable TABLE
(
	  ServerName nvarchar(255)
	, DBName nvarchar(255)
	, BaseObjectName nvarchar(255)
	, BaseObjectType nvarchar(255)
	, ParentObjectName nvarchar(255)
	, ParentObjectType nvarchar(255)
	, ThisObjectSchemaName nvarchar(255)
	, ThisObjectName nvarchar(255)
	, ThisObjectType nvarchar(255)
	, Level smallint
	, referenced_database_name nvarchar(255)
	, referenced_server_name nvarchar(255)
	, srcdest tinyint
	, loc int
)
AS
BEGIN
	-- 
	with Dependants ( BaseObjectName , BaseObjectType, ParentName, ParentType
		, ThisObjectSchemaName, ThisObjectID, ThisObjectName , ThisObjectType , Level 
		, referenced_database_name, referenced_server_name) 
	as 
    ( select  -- Base level objects
		  base.name		 as BaseObjectName 
        , base.type_desc as BaseObjectType
		, parent.name	 as ParentName
		, parent.type_desc	as ParentType
        , s.name		 as ThisObjectSchemaName
        , base.object_id as ThisObjectID 
        , base.name		 as ThisObjectName
        , base.type_desc as ThisObjectType
        , 0				 as Level 
		, ed.referenced_database_name
		, ed.referenced_server_name
		from sys.objects base -- The left joins are just there to ensure the returned data types are correct
			join sys.schemas s on s.schema_id = base.schema_id
			left join sys.sql_expression_dependencies ed on ed.referenced_id = base.object_id
			left join sys.objects parent on parent.object_id = ed.referencing_id 
		where base.type in ('P') 
		and base.name = @BaseObjectName

		UNION ALL -- Child objects in the same database.
		select main.BaseObjectName 
			, main.BaseObjectType
			, parent.name as ParentName
			, parent.type_desc as ParentType
			, s.name 
			, thisObj.object_id	as ThisObjectID 
			, thisObj.name		as ThisObjectName
			, thisObj.type_desc	as ThisObjectType
			, Level + 1 
			, ed.referenced_database_name
			, ed.referenced_server_name
		from  sys.objects thisObj
			join sys.schemas s on s.schema_id = thisObj.schema_id
			join sys.sql_expression_dependencies ed on ed.referenced_entity_name = thisObj.name 	
			join sys.objects parent on parent.object_id = ed.referencing_id 
			join Dependants as main on parent.object_id = main.ThisObjectID and parent.object_id <> thisObj.object_id 
		where thisObj.type in ( 'P', 'U', 'V', 'FN', 'IF', 'TF') 
		and parent.type  = 'P'  

		
		UNION ALL -- objects referenced in other databases
		select  main.BaseObjectName 
			, main.BaseObjectType
			, parent.name as ParentName
			, parent.type_desc as ParentType
			, ed.referenced_schema_name 
			, ed.referenced_id 
			, ed.referenced_entity_name 
			, ed.referenced_class_desc 
			, Level + 1
			, ed.referenced_database_name
			, ed.referenced_server_name
		from sys.sql_expression_dependencies ed
			join sys.objects parent on parent.object_id = ed.referencing_id 
			join Dependants as main on parent.object_id = main.ThisObjectID 
		where ed.referenced_id is null 
			and parent.type in ( 'P', 'U', 'V', 'FN', 'IF', 'TF')
			and ed.referenced_database_name is not null
	)   
	INSERT @returntable
	select  @@Servername AS ServerName
		, DB_NAME() AS DBName 
		, BaseObjectName 
		, BaseObjectType
		, ParentName 
		, ParentType
		, ThisObjectSchemaName
		, p.ThisObjectName
		, p.ThisObjectType 
		, Level 
		, referenced_database_name
		, referenced_server_name
		, 1 as srcdest -- default table CRUD to 1(=R)
		, 0 as loc
	from Dependants as p 

	-- Take a stab at setting the CRUD matrix for each table in each procedure.
	-- Put found proc names into a table .
	DECLARE @ObjTable TABLE (line int, ParentName nvarchar(255), ObjName nvarchar(255))
	INSERT INTO @ObjTable
	SELECT dense_rank() over( order by ParentObjectName), ParentObjectName, ThisObjectName 
		FROM (select distinct ParentObjectName, ThisObjectName 
				from @returntable 
				where ParentObjectType = 'SQL_STORED_PROCEDURE'
			) x

	/*
		For each proc, load its text and look for lines with dependent table names in.
		Build a reference of tablenames and the crud operations they undergo.
		Fairly crude, and won't work over split lines but should get most stuff.
		A regex CLR would be able to provide a more refined solution.
		Include any called procedures.
	*/
	DECLARE @sptext TABLE(code varchar(max));
	DECLARE @loc int -- lines of code count
	DECLARE @crud TABLE (procname nvarchar(255), tablename nvarchar(255), crudmap int); 
	DECLARE @TableNames Table (TableName nvarchar(255)); 
	declare @objName nvarchar(255), @parentObjName nvarchar(255)
	declare @objcount int = (select count(distinct ParentName) from @ObjTable)
	declare @objpos int = 1
	WHILE @objpos <= @objcount
	BEGIN
		Select @parentObjName = (Select distinct ParentName from @ObjTable where line = @objpos)

		-- Load up the text of the proc. Initially used sp_helptext but calling this from other procs that insert-exec breaks things.
		-- To preserve line breaks use string_split (2016 and above only!)
		delete from @sptext;
		insert into @sptext (code)
		Select value from string_split(
			(SELECT OBJECT_DEFINITION(object_id) 
				FROM sys.procedures 
				WHERE name = @parentObjName 
			), char(10)
		) 
		where len(ltrim(replace(value, char(9), ' '))) > 1

		-- Update the return table with the lines of code count. Just update the object that references itself
		select @loc = count(*) from @sptext
		UPDATE @returntable
		SET loc = @loc
		WHERE ThisObjectName = @parentObjName
		

		-- Create a list of table names for the procedure object
		-- Main drawback here is that the the dependency table doesn't know about any tables accessed solely via dynamic sql
		-- in the procedure, which can happen. 
		delete from @TableNames
		insert into @TableNames (TableName)
		select distinct ThisObjectNAme 
		from @returntable where ThisObjectType = 'USER_TABLE'
		AND ParentObjectName = @parentObjName;
 
 		-- look for the crud words in the text
		INSERT INTO @crud
		SELECT  ParentObjectName, TableName, sum(crudvalue)
		FROM
		(
			SELECT firstword, ParentObjectName, TableName,
				CASE firstword 
					WHEN 'insert' THEN 2
					WHEN 'update' THEN 4
					WHEN 'delete' THEN 8
				END AS crudvalue
			FROM
			(
				SELECT *, left (code, patindex('% %', code)) as firstword
				FROM
				(
					SELECT @parentObjName as ParentObjectName, TableName,  
						ltrim(replace(code, char(9), ' ')) as code, PATINDEX('%' + TableName + '%', code)  as pos
					FROM @sptext  cross join @TableNames
				) x where pos > 0
				and left(ltrim(code), 2) <> '--'
			 ) y
			 WHERE firstword in ('insert','update','delete') -- possibility of looking for ddl as well (create, drop, etc)?
		) z
		GROUP BY z.ParentObjectName, z.TableName

		-- Now update the return table with the crudmap 
		UPDATE r
		SET r.srcdest = c.crudmap
		FROM @returntable r
		JOIN @crud c on c.procname = r.ParentObjectName
			AND c.tablename = r.ThisObjectName

		-- next procedure
		Set @objpos = @objpos + 1
	END

	RETURN
END