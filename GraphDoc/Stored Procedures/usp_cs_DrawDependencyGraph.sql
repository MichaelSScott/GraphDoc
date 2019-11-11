/* =============================================
-- Author:		M. Scott
-- Create date: 30/08/18
-- Description:	For a given dependency graph 
   table generate the dependency graph file.
   Results should be saved to a .gv file. This 
   can then be drawn as required with the 
   graphviz application.
-- ============================================= */
CREATE PROCEDURE [GraphDoc].[usp_cs_DrawDependencyGraph]
	@dep udtt_DependencyGraph READONLY,
	@FriendlyName nvarchar(255) = NULL,
	@collapse_nonlocal_db char(1) = 'N', -- Y/N, default N
	@direction char(2) = 'TB',  -- LR, BT, RL. top to bottom, left to right, etc.
	@graphsection tinyint = 1, -- 1 = all, 2 = notail, 4 = body, 8 = nohead
	@overview char(1) = 'N', -- Y = ensure table/view objects are in the namespace of the base object.
	@description nvarchar(max) = NULL,
	@codesample nvarchar(max) = NULL
AS
	SET NOCOUNT ON

	DECLARE @cleanFriendlyName nvarchar(255)
	-- this really could do with regex
	set @cleanFriendlyName = replace(replace(replace(replace(replace(replace(replace(isnull(@FriendlyName,'GraphDoc'), ' ', '_'), '(','_'), ')','_'), '-','_'),'\','_'),':','_'),',','_')

	declare @sql varchar(1000);

	if object_id('tempdb..#gvfile') is not null
		drop table #gvfile;

	create table #gvfile (
			gvline varchar(2048) null
		)

	if object_id('tempdb..#edges') is not null
		drop table #edges;
	create table #edges (
		clusterEdge varchar(2048) null
	)

	if @graphsection & 1 = 1 or @graphsection & 2 = 2
	begin
	/* all or notail section specified so preamble is required
	*/
		-- Set up preamble
		insert into #gvfile values ('/* Command to generate the layout: dot -Tpng ' + @cleanFriendlyName + '.gv > ' + @cleanFriendlyName + '.png */')
		insert into #gvfile values ('/* sqlcmd -S "myServer\myInstance" -d myDBName -i "script.sql" -E -o myOutputFile.gv -h -1 */')
		insert into #gvfile values ('/* ' + convert(nvarchar, getdate()) + ' */')
		insert into #gvfile values ('')
		insert into #gvfile values ('strict digraph ' + @cleanFriendlyName + ' {')
		insert into #gvfile values ('ratio=auto;')
		insert into #gvfile values ('rankdir='+ @direction +';')
		insert into #gvfile values ('overlap=false;')
		insert into #gvfile values ('compound=true;')
		insert into #gvfile values ('edge [color=blue];')
		insert into #gvfile values ('')
	
	end

		/* 
			Process all base objects. We only want procs.
			Ordinarily there'd only be one base object per execution as it makes for a clearer diagram.
			But if the user wants to see multiple objects this will still work.
		*/
		DECLARE @objpos int = 0;
		DECLARE @stringPos nvarchar(3);
		DECLARE @thisbaseobj nvarchar(255);
		DECLARE @sources nvarchar(1000);
		DECLARE @targets nvarchar(1000);

		DECLARE @baseCount int
		DECLARE @displayName nvarchar(255)
		Select @baseCount = count(distinct BaseObjectName) from @dep
		
		IF @baseCount > 1 
			Set @displayName  = isnull(@cleanFriendlyName, '') + '_Multiple_Objects'
		ELSE 
			Select @thisbaseobj = BaseObjectName from @dep where Level = 0;
			Set @displayName = coalesce(@cleanFriendlyName, @thisbaseobj, 'No procedures selected!')
					
		-- Add local objects subgraph. This only needs doing once per dependency table
		-- Actually two clusters if overview or hierarchical view, one for the baseobject (helps with job related graphs)
		-- then the local db cluster

		if @overview in ('Y', 'H')
		begin
			-- Add a framing cluster node.
			insert into #gvfile values ('	subgraph cluster_top_' + @displayName + ' {')
			insert into #gvfile 
				select  concat('		label=<<B> ' , @displayName, case @overview when 'H' then ' Hierarchical' else '' end, ' Overview.<BR/></B> <I> ', isnull(@description, ''), ' </I>>; ')
			-- Add a framing cluster node for the subject database. Note there is a constraint that only a single subject db is present in the  dependency table.
			insert into #gvfile values ('		subgraph cluster_local_' + @displayName + ' {')
			insert into #gvfile 
				select top 1 '			label="DB: ' + dl.DBName + '"; ' 
					from @dep dl 
					where Level = 0 
		end
		else -- not an overview so get an unframed set of graph objects.
		begin
			if @description is not null and @graphsection & 128 = 0  insert into #gvfile select  concat('label=<<I><BR/>', @description, '</I>>; ')
			insert into #gvfile values ('		subgraph local_' + @displayName + ' {')
		end

		/* 
			Add the base object nodes. Default shape ellipse.
			If graphSection = 1 (all) then the convention is that we will have both an overview and a hierarchical
			diagram available and the node will display with a link to the complementary file. This requires the user
			to run this procedure twice, for the Y and H overview options. If option N is taken (not usually expected,
			but nothing to stop it) then it will default its link to the Y file. Note that all links are expected to 
			be in the current directory.
			If the graphSections are being built up then this is (currently) for displaying job steps so just display 
			a static label. However we don't expect a ton of code to be present in job steps so set the tooltip to this
			code (up to 10 lines say). 
		*/
		if @graphsection != 1
		begin
			insert into #gvfile 
			SELECT '			' + dl.BaseObjectName  + ' [style=bold, label="' + @FriendlyName + ' [' + convert(nvarchar, dl.loc) + ']", fontsize=16, tooltip="' 
					+ isnull(@codesample, 'SQL_STORED_PROCEDURE') + '"] ;'
			FROM  @dep dl
			WHERE dl.BaseObjectType in ('SQL_STORED_PROCEDURE')
			AND dl.Level = 0;
		end
		else
		begin
			insert into #gvfile 
			SELECT '			' + dl.BaseObjectName  + ' [style=bold, label=<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">
				<TR><TD href=".\'+ dl.BaseObjectName +'_' + case @overview when 'Y' then 'H' else 'Y' end + '.gv.svg" TOOLTIP="Open ' + case @overview when 'Y' then 'Hierarchical ' else 'Over' end + 'view">
					<B> <font color="#0000ff">' + dl.BaseObjectName + '</font></B><BR/><FONT POINT-SIZE="10"><I> [' + convert(nvarchar, dl.loc) + ']</I></FONT>
				</TD></TR></TABLE>>, fontsize=16] ;'
			FROM  @dep dl
			WHERE dl.BaseObjectType in ('SQL_STORED_PROCEDURE')
			AND dl.Level = 0;
		end

		/*
			Draw a set of local objects
		*/
		IF @overview != 'H' -- Overview Y or N  displays lowest level tables and views tied to the base object
		BEGIN
			-- Add the source and target nodes
			INSERT INTO #gvfile
				SELECT distinct '			' 
					+  case when @overview = 'Y' then  ThisObjectName + isnull(@thisbaseobj, '')  else ThisObjectName end -- Ensures a separation of names for job overview and steps for easier reading of diagrams 
					+ ' [label="'+ ThisObjectName +'", shape=' 
							+ CASE  WHEN ThisObjectType = 'USER_TABLE' THEN 'tab' 
									WHEN ThisObjectType = 'VIEW' THEN 'component' 
									--WHEN ThisObjectType = 'SQL_STORED_PROCEDURE' THEN 'ellipse' 
									ELSE 'box, style="rounded"' end 
							+ ', tooltip=' + CASE WHEN ThisObjectType = 'SQL_STORED_PROCEDURE' AND @codesample is not null THEN '"' + @codesample + '"' ELSE ThisObjectType END
					+ '];'
			FROM @dep 
			WHERE Level > 0 
			AND BaseObjectType = 'SQL_STORED_PROCEDURE'
			AND ThisObjectType <> 'SQL_STORED_PROCEDURE'
			AND referenced_server_name is null
			AND referenced_database_name is null
		END 
		ELSE -- H
		BEGIN
			/* 
				Otherwise a hierarchical view of things.
				For this we need to know each object's parent.
			*/
			INSERT INTO #gvfile
			SELECT distinct '			' 
					+ ThisObjectName
					+ ' [label="'+ ThisObjectName +'", shape=' 
							+ CASE  WHEN ThisObjectType = 'USER_TABLE' THEN 'tab' 
									WHEN ThisObjectType = 'VIEW' THEN 'component' 
									WHEN ThisObjectType = 'SQL_STORED_PROCEDURE' THEN 'ellipse' 
									ELSE 'box, style="rounded"' end 
					+ '];'
			FROM @dep 
			WHERE Level > 0 
			AND BaseObjectType = 'SQL_STORED_PROCEDURE'
			AND referenced_server_name is null
			AND referenced_database_name is null
		END

		-- Close the subgraph.
		insert into #gvfile values ('		} # end local')

		-- Get the source tables and views on the local db used by the base object
		-- and create the edges for them
		-- These could go inside the above subgraph but for symmetry with the non-local dbs put them after. 

		if @overview != 'H'
		begin
			INSERT INTO #gvfile
			SELECT distinct '		' + case when @overview = 'Y' then  ThisObjectName + isnull(@thisbaseobj, '') else ThisObjectName end  + ' -> ' + BaseObjectName + ';'
			FROM @dep 
			WHERE Level > 0 
			AND ThisObjectType in ('USER_TABLE', 'VIEW')
			AND srcdest = 1 

		-- Get a list of target tables on the local db as for sources
								
			INSERT INTO #gvfile
			SELECT distinct '		' + BaseObjectName + ' -> ' +  case when @overview = 'Y' then  ThisObjectName + isnull(@thisbaseobj, '') else ThisObjectName end  + ';'
			FROM @dep 
			WHERE Level > 0 
			AND ThisObjectType = 'USER_TABLE'
			AND srcdest > 1 -- insert, update or delete then this is a target table. 
		end
		else -- @overview = 'H'. Distinct command to combine multiple arrows due to sp calls at multiple levels.
		begin
			INSERT INTO #gvfile
			SELECT distinct  '		' + ThisObjectName + ' -> ' +  ParentObjectName + ';'
			FROM @dep 
			WHERE Level > 0 
			AND ThisObjectType in ('USER_TABLE', 'VIEW')
			and srcdest = 1

			INSERT INTO #gvfile
			SELECT distinct  '		' + ParentObjectName + ' -> ' +  ThisObjectName + ' [arrowhead=ovee, color=deeppink, tooltip="calls"];'
			FROM @dep 
			WHERE Level > 0 
			AND ThisObjectType = 'SQL_STORED_PROCEDURE'
			AND srcdest = 1 

			INSERT INTO #gvfile
			SELECT distinct  '		' + ParentObjectName + ' -> ' +  ThisObjectName + ';'
			FROM @dep 
			WHERE Level > 0 
			AND srcdest > 1 
			AND referenced_database_name is null
		end


		/*
			If the graphSection high bit is on then there's something you should know
		*/
		if @graphsection & 128 = 128
		begin	
			insert into #gvfile 
			SELECT '			' + BaseObjectName + 'Warning [label="' + @description 
				+ '", shape=box, color=red, style ="rounded, dashed", fontcolor=red, fontsize=16];'
			FROM  @dep dl
			WHERE dl.BaseObjectType = 'SQL_STORED_PROCEDURE'
			AND dl.Level = 0;
			
			insert into #gvfile 
			SELECT '			' + BaseObjectName + 'Warning -> ' + BaseObjectName + ' [color=red, arrowhead=open];'
			FROM  @dep dl
			WHERE dl.BaseObjectType = 'SQL_STORED_PROCEDURE' 
			AND dl.Level = 0;
			
			insert into #gvfile 
			SELECT '			{rank=same; ' + BaseObjectName + 'Warning; ' + BaseObjectName + ';}'
			FROM  @dep dl
			WHERE dl.BaseObjectType = 'SQL_STORED_PROCEDURE'
			AND dl.Level = 0;
		end

		-- Add any other referenced databases. One cluster per db per base or parent object depending on overview level.
		DECLARE @dbident nvarchar(255)
		DECLARE @clusterIdent nvarchar(255)

		DECLARE @objectname nvarchar(255)
		DECLARE @parentobjectname nvarchar(255)
		DECLARE @dbpos int = 0

		-- Add other local server db objects subcluster(s)
		DECLARE @dbname nvarchar(255);
		DECLARE @remdbname nvarchar(255);
		DECLARE @remotesrv nvarchar(255);
		DECLARE @cleanServerName nvarchar(255);
		declare @dbsrcobjects nvarchar(1000);
		declare @dbtargobjects nvarchar(1000);
			
		IF @overview != 'H'
		BEGIN

			/*
				Draw database clusters as referenced.
			*/
			Declare @serverName nvarchar(255);
			DECLARE locdb_Cursor CURSOR FOR  
			SELECT distinct iif(referenced_server_name is null, '', referenced_server_name), referenced_database_name   
				FROM  @dep 
				where referenced_database_name is not null
			OPEN locdb_Cursor;  
			FETCH NEXT FROM locdb_Cursor into @remotesrv, @dbname;  
			WHILE @@FETCH_STATUS = 0
			BEGIN
				truncate table #edges

				--Remote server names can be ugly so get rid of upsetting characters for use in gv references.
				Set @cleanServerName = replace(replace(replace(replace(replace(replace(replace(@remotesrv, ' ', '_'), '(','_'), ')','_'), '-','_'),'\','_'),'[','_'),']', '_')

				-- Each unique db has a cluster
				Set @clusterIdent = 'cluster_' + @cleanServerName +'_db_' + @dbname;
				insert into #gvfile values ('		subgraph ' + @clusterIdent + ' {');
				Set @serverName = iif(@remotesrv='','(local)', @remoteSrv);
				insert into #gvfile values ('			label="Server: ' + @serverName +', DB: ' + @dbname +  '"; '); 

				-- Now draw table references for each base object that references this server
				DECLARE locdbobj_Cursor CURSOR FOR  
					SELECT distinct BaseObjectName   
					FROM  @dep 
					where isnull(referenced_server_name,'') = @remotesrv and 
						referenced_database_name = @dbname
				OPEN locdbobj_Cursor;  
				FETCH NEXT FROM locdbobj_Cursor into @objectname ;  
				WHILE @@FETCH_STATUS = 0  
				BEGIN
					-- Get a pipe separated list of source objects from the local server db
					SELECT @dbsrcobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.BaseObjectName = OutTab.BaseObjectName and 
									Level > 0  
									and isnull(referenced_server_name,'') = @remotesrv
									and referenced_database_name = @dbname
									and BaseObjectName = @objectname
									and srcdest = 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.BaseObjectName = @objectname 
					GROUP BY OutTab.BaseObjectName 

					-- Get a pipe separated list of target objects from the remote server db
					SELECT @dbtargobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.BaseObjectName = OutTab.BaseObjectName and 
									Level > 0 
									and isnull(referenced_server_name,'') = @remotesrv
									and referenced_database_name = @dbname
									and BaseObjectName = @objectname
									and srcdest > 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.BaseObjectName = @objectname 
					GROUP BY OutTab.BaseObjectName 

					SET @dbident = 'db_' + @cleanServerName + '_' + @dbname + '_' +  @objectname 

					if @dbsrcobjects is not null
					begin
						
						IF @collapse_nonlocal_db <> 'Y'
							insert into #gvfile values('			' + @dbident  + ' [label="Source Table(s) ' + @dbsrcobjects + '", shape = "Mrecord", fontsize=14]; ')
						ELSE 
							insert into #gvfile values('			' + @dbident + ' [label="Source Table(s) ", shape = "Mrecord", fontsize=14]; ')
					end

					if @dbtargobjects is not null
					begin
						IF @collapse_nonlocal_db <> 'Y'
							insert into #gvfile values('			' + @dbident + '_t [label="Target Table(s) ' + @dbtargobjects + '", shape = "Mrecord", fontsize=14]; ')
						ELSE 
							insert into #gvfile values('			' + @dbident + '_t [label="Target Table(s) ", shape = "Mrecord", fontsize=14]; ')								
					end

					/* This would be the ideal place to insert the edges from the db objects to the baseobjects into the gv file.
						However, if the edge is inside the cluster definition it seems like graphviz -sometimes- decides to place the 
						basobject node inside the db cluster, which is not good.
						So instead stack up the edges here and poot them out after the cluster is enclosed.
					*/
					if @dbsrcobjects is not null
						insert into #edges values ('		' + @dbident + ' -> ' + @objectname +';')
					if @dbtargobjects is not null
						insert into #edges values ('		' + @objectname + ' -> ' + @dbident  + '_t;')

					FETCH NEXT FROM locdbobj_Cursor into @objectname ; 
				END
				CLOSE locdbobj_Cursor;  
				DEALLOCATE locdbobj_Cursor;

				insert into #gvfile values ('		} # end cluster_db')

				-- Add the edges we've been saving up.
				insert into #gvfile
				select clusterEdge from #edges

				FETCH NEXT FROM locdb_Cursor into @remotesrv, @dbname;
			END
			CLOSE locdb_Cursor;  
			DEALLOCATE locdb_Cursor;  
		END

		ELSE
		BEGIN
			/*
				Draw database clusters as referenced.
			*/
			DECLARE locdb_Cursor CURSOR FOR  
			SELECT distinct iif(referenced_server_name is null, '', referenced_server_name), referenced_database_name   
				FROM  @dep 
				where referenced_database_name is not null
			OPEN locdb_Cursor;  
			FETCH NEXT FROM locdb_Cursor into @remotesrv, @dbname;  
			WHILE @@FETCH_STATUS = 0
			BEGIN
				truncate table #edges

				--Remote server names can be ugly so get rid of upsetting characters for use in gv references.
				Set @cleanServerName = replace(replace(replace(replace(replace(replace(replace(@remotesrv, ' ', '_'), '(','_'), ')','_'), '-','_'),'\','_'),'[','_'),']', '_')

				-- Each unique db has a cluster
				Set @clusterIdent = 'cluster_' + @cleanServerName +'_db_' + @dbname;
				insert into #gvfile values ('		subgraph ' + @clusterIdent + ' {');
				Set @serverName = iif(@remotesrv='','(local)', @remoteSrv);
				insert into #gvfile values ('			label="Server: ' + @serverName +', DB: ' + @dbname +  '"; '); 

				-- Now draw table references for each base object that references this server
				DECLARE locdbobj_Cursor CURSOR FOR  
					SELECT distinct ParentObjectName   
					FROM  @dep 
					where isnull(referenced_server_name,'') = @remotesrv and 
						referenced_database_name = @dbname
				OPEN locdbobj_Cursor;  
				FETCH NEXT FROM locdbobj_Cursor into @objectname ;  
				WHILE @@FETCH_STATUS = 0  
				BEGIN
					-- Get a pipe separated list of source objects from the local server db
					SELECT @dbsrcobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.ParentObjectName = OutTab.ParentObjectName and 
									Level > 0  
									and isnull(referenced_server_name,'') = @remotesrv
									and referenced_database_name = @dbname
									and ParentObjectName = @objectname
									and srcdest = 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.ParentObjectName = @objectname 
					GROUP BY OutTab.ParentObjectName 

					-- Get a pipe separated list of target objects from the remote server db
					SELECT @dbtargobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.ParentObjectName = OutTab.ParentObjectName and 
									Level > 0 
									and isnull(referenced_server_name,'') = @remotesrv
									and referenced_database_name = @dbname
									and ParentObjectName = @objectname
									and srcdest > 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.ParentObjectName = @objectname 
					GROUP BY OutTab.ParentObjectName 

					SET @dbident = 'db_' + @cleanServerName + '_' + @dbname + '_' +  @objectname 

					if @dbsrcobjects is not null
					begin
						
						IF @collapse_nonlocal_db <> 'Y'
							insert into #gvfile values('			' + @dbident  + ' [label="Source Table(s) ' + @dbsrcobjects + '", shape = "Mrecord", fontsize=14]; ')
						ELSE 
							insert into #gvfile values('			' + @dbident + ' [label="Source Table(s) ", shape = "Mrecord", fontsize=14]; ')
					end

					if @dbtargobjects is not null
					begin
						IF @collapse_nonlocal_db <> 'Y'
							insert into #gvfile values('			' + @dbident + '_t [label="Target Table(s) ' + @dbtargobjects + '", shape = "Mrecord", fontsize=14]; ')
						ELSE 
							insert into #gvfile values('			' + @dbident + '_t [label="Target Table(s) ", shape = "Mrecord", fontsize=14]; ')								
					end

					/* This would be the ideal place to insert the edges from the db objects to the baseobjects into the gv file.
						However, if the edge is inside the cluster definition it seems like graphviz -sometimes- decides to place the 
						basobject node inside the db cluster, which is not good.
						So instead stack up the edges here and poot them out after the cluster is enclosed.
					*/
					if @dbsrcobjects is not null
						insert into #edges values ('		' + @dbident + ' -> ' + @objectname +';')
					if @dbtargobjects is not null
						insert into #edges values ('		' + @objectname + ' -> ' + @dbident  + '_t;')

					FETCH NEXT FROM locdbobj_Cursor into @objectname ; 
				END
				CLOSE locdbobj_Cursor;  
				DEALLOCATE locdbobj_Cursor;

				insert into #gvfile values ('		} # end cluster_db')

				-- Add the edges we've been saving up.
				insert into #gvfile
				select clusterEdge from #edges

				FETCH NEXT FROM locdb_Cursor into @remotesrv, @dbname;
			END
			CLOSE locdb_Cursor;  
			DEALLOCATE locdb_Cursor;  
		END

		IF @overview in ('Y', 'H')
				insert into #gvfile values ('	} # end cluster_top')

		IF @baseCount = 0
			insert into #gvfile values ('"' + @FriendlyName + ' has nothing in it."')
	

		if @graphsection & 1 = 1 or @graphsection & 8 = 8
		begin
		/* 
			All or nohead section specified so final enclosure required
			Generally a nohead section will have some irrelevant text in the description and friendly name
			so ignore it.
		*/
			declare @label nvarchar(255) 
			if  @graphsection & 8 = 8
				Set @label = 'GraphDoc'
			else
				Set @label= coalesce(@description, @FriendlyName, 'GraphDoc')

			insert into #gvfile 
				values ('	label=<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">
							<TR><TD href="http://composedsoftware.net" target="_blank" TOOLTIP="Composed Software Ltd">
									<B> <font color="#0000ff">' + @label + '</font></B>
							</TD></TR></TABLE>>')
			insert into #gvfile values ('} # end graph')
		end 

		select * from #gvfile
RETURN 0