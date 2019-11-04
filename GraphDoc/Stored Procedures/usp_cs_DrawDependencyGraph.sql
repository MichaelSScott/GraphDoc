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
	set @cleanFriendlyName = replace(replace(replace(replace(replace(replace(isnull(@FriendlyName,'GraphDoc'), ' ', '_'), '(','_'), ')','_'), '-','_'),'\','_'),':','_')

	declare @sql varchar(1000);

	if object_id('tempdb..#gvfile') is not null
		drop table #gvfile;

	create table #gvfile (
			gvline varchar(2048) null
		)

	if @graphsection & 1 = 1 or @graphsection & 2 = 2
	begin
	/* all or notail section specified so preamble is required
	*/
		-- Set up preamble
		insert into #gvfile values ('/* Command to generate the layout: dot -Tpng ' + @cleanFriendlyName + '.gv > ' + @cleanFriendlyName + '.png */')
		insert into #gvfile values ('')
		insert into #gvfile values ('digraph ' + @cleanFriendlyName + ' {')
		insert into #gvfile values ('ratio=auto;')
		insert into #gvfile values ('rankdir='+ @direction +';')
		insert into #gvfile values ('overlap=false;')
		insert into #gvfile values ('compound=true;')
		insert into #gvfile values ('edge [color=blue];')
		insert into #gvfile values ('')
	
	end

		/* 
			Process each base object. We only want procs.
			Ordinarily there'd only be one base object per execution as it makes for a clearer diagram.
			But if the user wants to see multiple objects this will still work, though each object will
			be in its own cluster. Multiple objects clobber any friendly name passed in.
		*/
		DECLARE @objpos int = 0;
		DECLARE @stringPos nvarchar(3);
		DECLARE @thisbaseobj nvarchar(255);
		DECLARE @loc nvarchar(6)
		DECLARE @sources nvarchar(1000);
		DECLARE @targets nvarchar(1000);

		DECLARE @baseCount int
		DECLARE @displayName nvarchar(255)
		Select @baseCount = count(distinct BaseObjectName) from @dep

			
		DECLARE baseobj_Cursor CURSOR FOR  
			SELECT distinct dl.BaseObjectName, convert(nvarchar, dl.loc) as loc
			FROM  @dep dl
			WHERE dl.BaseObjectType in ('SQL_STORED_PROCEDURE')
			AND ParentObjectName is null
		OPEN baseobj_Cursor;  
		FETCH NEXT FROM baseobj_Cursor into @thisbaseobj, @loc;  
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			Set @objpos = @objpos + 1;
			Set @stringPos = convert(nvarchar,@objpos);

			if @baseCount > 1 
				Set @displayName  = @thisbaseobj
			else 
				Set @displayName = isnull(@FriendlyName, @thisbaseobj)
			
			-- Add local objects subgraph. This only needs doing once per base object
--			-- Actually two clusters if overview, one for the baseobject (helps with job related graphs)
			-- then the local db cluster
--			if @objpos = 1
--			begin
				-- Add base object cluster node if this is an overview.
				if @overview in ('Y', 'H')
				begin
					insert into #gvfile values ('	subgraph cluster_top_' + @thisbaseobj + ' {')
					insert into #gvfile 
						select  concat('		label=<<B> ' , @displayName, case @overview when 'H' then ' Hierarchical' else '' end, ' Overview.<BR/></B> <I> ', isnull(@description, ''), ' </I>>; ')
					insert into #gvfile values ('		subgraph cluster_local_' + @thisbaseobj + ' {')
					insert into #gvfile 
						select  '			label="DB: ' + dl.DBName + '"; ' 
							from @dep dl 
							where dl.BaseObjectName = '' + @thisbaseobj + ''
							and Level = 0 
				end
				else
				begin
					if @description is not null and @graphsection & 128 = 0  insert into #gvfile select  concat('label=<<I><BR/>', @description, '</I>>; ')
					insert into #gvfile values ('		subgraph local_' + @thisbaseobj + ' {')
				end

				if @overview != 'H' -- Overview Y or N  displays lowest level tables and views tied to the base object
				begin
					
					-- Add the source and target nodes
					INSERT INTO #gvfile
						SELECT distinct '				' 
							+ case when @overview = 'Y' then  ThisObjectName + @thisbaseobj  else ThisObjectName end
							+ ' [label="'+ ThisObjectName +'", shape=' 
									+ CASE  WHEN ThisObjectType = 'USER_TABLE' THEN 'tab' 
											WHEN ThisObjectType = 'VIEW' THEN 'component' 
											--WHEN ThisObjectType = 'SQL_STORED_PROCEDURE' THEN 'ellipse' 
											ELSE 'box, style="rounded"' end 
									+ ', tooltip=' + CASE WHEN ThisObjectType = 'SQL_STORED_PROCEDURE' AND @codesample is not null THEN '"' + @codesample + '"' ELSE ThisObjectType END
							+ '];'
					FROM @dep 
					WHERE Level > 0 
					AND BaseObjectName = '' + @thisbaseobj + ''
					AND BaseObjectType = 'SQL_STORED_PROCEDURE'
					AND ThisObjectType <> 'SQL_STORED_PROCEDURE'
					AND referenced_server_name is null
					AND referenced_database_name is null
				end 
				else
				begin
					/* 
						Otherwise a hierarchical view of things.
						For this we need to know each object's parent.
					*/
					INSERT INTO #gvfile
						SELECT distinct '				' 
							+ ThisObjectName
							+ ' [label="'+ ThisObjectName +'", shape=' 
									+ CASE  WHEN ThisObjectType = 'USER_TABLE' THEN 'tab' 
											WHEN ThisObjectType = 'VIEW' THEN 'component' 
											WHEN ThisObjectType = 'SQL_STORED_PROCEDURE' THEN 'ellipse' 
											ELSE 'box, style="rounded"' end 
							+ '];'
					FROM @dep 
					WHERE Level > 0 
					AND BaseObjectName = '' + @thisbaseobj + ''
					AND BaseObjectType = 'SQL_STORED_PROCEDURE'
					--AND ThisObjectType <> 'SQL_STORED_PROCEDURE'
					AND referenced_server_name is null
					AND referenced_database_name is null
				end
--			end

			/* 
				Add the base object node. Default shape ellipse.
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
				
				insert into #gvfile values ('			' + @thisbaseobj  + ' [style=bold, label="' + @displayName + ' [' + @loc + ']", fontsize=16, tooltip="' + isnull(@codesample, 'SQL_STORED_PROCEDURE') + '"] ;')
			end
			else
			begin
				insert into #gvfile values ('			' + @thisbaseobj  + ' [style=bold, label=<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">
							<TR><TD href=".\'+ @thisbaseobj +'_' + case @overview when 'Y' then 'H' else 'Y' end + '.gv.svg" TOOLTIP="Open ' + case @overview when 'Y' then 'Hierarchical ' else 'Over' end + 'view">
								<B> <font color="#0000ff">' + @displayName + '</font></B><BR/><FONT POINT-SIZE="10"><I> [' + @loc + ']</I></FONT>
							</TD></TR></TABLE>>, fontsize=16] ;')
			end

			/*
				If the graphSection high bit is on then there's something you should know
			*/
			if @graphsection & 128 = 128
			begin	
				insert into #gvfile values ('			' + @thisbaseobj + 'Warning [label="' + @description + '", shape=box, color=red, style ="rounded, dashed", fontcolor=red, fontsize=16];')
				insert into #gvfile values ('			' + @thisbaseobj + 'Warning -> ' + @thisbaseobj + ' [color=red, arrowhead=open];')
				insert into #gvfile values ('			{rank=same; ' + @thisbaseobj + 'Warning; ' + @thisbaseobj + ';}')
			end


			-- Get a list of source tables and views on the local db use by the base object
			-- These go into the the same cluster as the local base objects. 

			if @overview != 'H'
			begin
				INSERT INTO #gvfile
				SELECT distinct '				' + case when @overview = 'Y' then  ThisObjectName + @thisbaseobj else ThisObjectName end + ' -> ' + @thisbaseobj + ';'
				FROM @dep 
				WHERE Level > 0 
				AND ThisObjectType in ('USER_TABLE', 'VIEW')
				AND srcdest = 1 
				AND BaseObjectName = @thisbaseobj 

			-- Get a list of target tables on the local db as for sources
								
				INSERT INTO #gvfile
				SELECT distinct '				' + @thisbaseobj + ' -> ' +  case when @overview = 'Y' then  ThisObjectName + @thisbaseobj else ThisObjectName end + ';'
				FROM @dep InrTab
				WHERE Level > 0 
				AND ThisObjectType = 'USER_TABLE'
				AND srcdest > 1 -- insert, update or delete then this is a target table. 
				AND BaseObjectName = @thisbaseobj 
			end
			else -- @overview = 'H'. Distinct command to combine multiple arrows due to sp calls at multiple levels.
			begin
				INSERT INTO #gvfile
				SELECT distinct  '				' + ThisObjectName + ' -> ' +  ParentObjectName + ';'
				FROM @dep InrTab
				WHERE Level > 0 
				AND ThisObjectType in ('USER_TABLE', 'VIEW')
				and srcdest = 1
				AND BaseObjectName = @thisbaseobj 
				and ParentObjectName is not null

				INSERT INTO #gvfile
				SELECT distinct  '				' + ParentObjectName + ' -> ' +  ThisObjectName + ' [arrowhead=ovee, color=deeppink, tooltip="calls"];'
				FROM @dep InrTab
				WHERE Level > 0 
				AND ThisObjectType = 'SQL_STORED_PROCEDURE'
				AND srcdest = 1 
				AND BaseObjectName = @thisbaseobj 
				and ParentObjectName is not null

				INSERT INTO #gvfile
				SELECT distinct  '				' + ParentObjectName + ' -> ' +  ThisObjectName + ';'
				FROM @dep InrTab
				WHERE Level > 0 
				AND srcdest > 1 
				AND BaseObjectName = @thisbaseobj 
				and ParentObjectName is not null

			end

			-- Close the subgraph and run the rest of the processing
			insert into #gvfile values ('			} # end local')

			-- Add any other referenced databases. One cluster per db per base or parent object depending on overview level.
			DECLARE @dbident nvarchar(255)
			DECLARE @clusterIdent nvarchar(255)

			DECLARE @baseobjectname nvarchar(255)
			DECLARE @parentobjectname nvarchar(255)
			DECLARE @dbpos int = 0

			-- Add other local server db objects subcluster(s)
			DECLARE @locdbname nvarchar(255);
			DECLARE @remdbname nvarchar(255);
			DECLARE @remotesrv nvarchar(255);
			DECLARE @cleanRemoteName nvarchar(255);
			declare @dbsrcobjects nvarchar(1000);
			declare @dbtargobjects nvarchar(1000);
			
			if @overview != 'H'
			begin
				DECLARE locsvrdb_Cursor CURSOR FOR  
					SELECT distinct dl.referenced_database_name, dl.BaseObjectName   
					FROM  @dep dl
					where dl.referenced_server_name is null
					and dl.referenced_database_name is not null
				Set @dbpos = 0
				OPEN locsvrdb_Cursor;  
				FETCH NEXT FROM locsvrdb_Cursor into @locdbname, @baseobjectname ;  
				WHILE @@FETCH_STATUS = 0  
				BEGIN
					Set @dbpos = @dbpos + 1;
					Set @stringPos = convert(nvarchar,@dbpos);

					-- Each unique db on the local server has a cluster
					Set @clusterIdent = 'cluster_local_' + @baseobjectname + @locdbname + @stringPos
					insert into #gvfile values ('		subgraph ' + @clusterIdent + ' {')

					insert into #gvfile values ('			label="DB: ' + @locdbname +  '"; ')			 
				  
					-- Get a pipe separated list of source objects from the local server db

					SELECT 
						@dbsrcobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.BaseObjectName = OutTab.BaseObjectName and 
									Level > 0  
									and referenced_database_name = @locdbname
									and BaseObjectName = @baseobjectname
									and srcdest = 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.BaseObjectName = @baseobjectname 
					GROUP BY OutTab.BaseObjectName 

					-- Get a pipe separated list of target objects from the remote server db

					SELECT 
						@dbtargobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.BaseObjectName = OutTab.BaseObjectName and 
									Level > 0 
									and referenced_database_name = @locdbname
									and BaseObjectName = @baseobjectname
									and srcdest > 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.BaseObjectName = @baseobjectname 
					GROUP BY OutTab.BaseObjectName 

					SET @dbident = 'dblocal_' + @locdbname + @stringPos +  @baseobjectname 

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

					insert into #gvfile values ('		} # end cluster_localdb')

					if @dbsrcobjects is not null
						insert into #gvfile values ('		' + @dbident + ' -> ' + @baseobjectname  + ' [ltail='+@clusterIdent+'];')
					if @dbtargobjects is not null
						insert into #gvfile values ('		' + @baseobjectname + ' -> ' + @dbident  + '_t [lhead='+@clusterIdent+'] ;')

					FETCH NEXT FROM locsvrdb_Cursor into @locdbname, @baseobjectname;  
				END;  
				CLOSE locsvrdb_Cursor;  
				DEALLOCATE locsvrdb_Cursor;  
		
				-- Add remote server db objects subcluster(s)
				DECLARE remsvrdb_Cursor CURSOR FOR  
					SELECT distinct dl.referenced_server_name, dl.referenced_database_name, dl.BaseObjectName   
					FROM  @dep dl
					WHERE dl.referenced_server_name is not null
					and dl.referenced_database_name is not null
				Set @dbpos = 0;
				OPEN remsvrdb_Cursor;  
				FETCH NEXT FROM remsvrdb_Cursor into @remotesrv, @remdbname, @baseobjectname;  
				WHILE @@FETCH_STATUS = 0  
				BEGIN
					Set @dbpos = @dbpos + 1;
					Set @stringPos = convert(nvarchar,@dbpos);

					Set @cleanRemoteName = replace(replace(replace(replace(replace(replace(replace(@remotesrv, ' ', '_'), '(','_'), ')','_'), '-','_'),'\','_'),'[','_'),']', '_')

					SET @dbident = 'dbremote_' + '_' + @cleanRemoteName + @stringPos + '_'  +  @baseobjectname
					Set @clusterIdent = 'cluster_remote_' + @baseobjectname + @cleanRemoteName + '_' +  @remdbname + @stringPos

					-- Each unique db on the remote server has a cluster. Double quote server name node as may contain special chars.
					insert into #gvfile values ('		subgraph ' + @clusterIdent + ' {')

					insert into #gvfile values ('			label="Server: ' + @remotesrv +', DB: ' + @remdbname +  '"; ')			 
				  
					-- Get a pipe separated list of source objects from the remote server db

					declare @remdbsrcobjects nvarchar(1000);
					SELECT 
						@remdbsrcobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.BaseObjectName = OutTab.BaseObjectName and 
									Level > 0 and 
									referenced_server_name= @remotesrv and
									referenced_database_name = @remdbname
									and BaseObjectName = @baseobjectname
									and srcdest = 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.BaseObjectName = @baseobjectname 
					GROUP BY OutTab.BaseObjectName 


					-- Get a pipe separated list of target objects from the remote server db

					declare @remdbtargobjects nvarchar(1000);
					SELECT 
						@remdbtargobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.BaseObjectName = OutTab.BaseObjectName and 
									Level > 0 and 
									referenced_server_name= @remotesrv and
									referenced_database_name = @remdbname
									and BaseObjectName = @baseobjectname
									and srcdest > 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.BaseObjectName = @baseobjectname 
					GROUP BY OutTab.BaseObjectName 

					if @remdbsrcobjects is not null
					begin
						insert into #gvfile values('			' + @dbident + ' [label="Source Table(s) ' + @remdbsrcobjects + '", shape = "Mrecord", fontsize=14]; ')
					end 

					if @remdbtargobjects is not null
					begin
						insert into #gvfile values('			' + @dbident + '_t [label="Target Table(s) ' + @remdbtargobjects + '", shape = "Mrecord", fontsize=14]; ')
					end
				
					insert into #gvfile values ('		} # end cluster_remotedb')

					if @remdbsrcobjects is not null
						insert into #gvfile values ('		' + @dbident + ' -> ' + @baseobjectname  + '[ltail=' + @clusterIdent +'];')
					if @remdbtargobjects is not null
						insert into #gvfile values ('		' + @baseobjectname + ' -> ' + @dbident + '_t [lhead=' + @clusterIdent +'] ;')

					FETCH NEXT FROM remsvrdb_Cursor into @remotesrv, @remdbname, @baseobjectname;  
				END;  
				CLOSE remsvrdb_Cursor;  
				DEALLOCATE remsvrdb_Cursor;
			end
			else --'H' -- This and above need massivel
			begin 
				DECLARE locsvrdb_Cursor_p CURSOR FOR  
					SELECT distinct dl.referenced_database_name, dl.ParentObjectName   
					FROM  @dep dl
					where dl.referenced_server_name is null
					and dl.referenced_database_name is not null
				Set @dbpos = 0
				OPEN locsvrdb_Cursor_p;  
				FETCH NEXT FROM locsvrdb_Cursor_p into @locdbname, @parentobjectname ;  
				WHILE @@FETCH_STATUS = 0  
				BEGIN
					Set @dbpos = @dbpos + 1;
					Set @stringPos = convert(nvarchar,@dbpos);

					-- Each unique db on the local server has a cluster
					Set @clusterIdent = 'cluster_local_' + @parentobjectname + @locdbname + @stringPos
					insert into #gvfile values ('		subgraph ' + @clusterIdent + ' {')

					insert into #gvfile values ('			label="DB: ' + @locdbname +  '"; ')			 
				  
					-- Get a pipe separated list of source objects from the local server db

					SELECT 
						@dbsrcobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.ParentObjectName = OutTab.ParentObjectName and 
									Level > 0  
									and referenced_database_name = @locdbname
									and ParentObjectName = @parentobjectname
									and srcdest = 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.ParentObjectName = @parentobjectname 
					GROUP BY OutTab.ParentObjectName 

					-- Get a pipe separated list of target objects from the remote server db

					SELECT 
						@dbtargobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.ParentObjectName = OutTab.ParentObjectName and 
									Level > 0 
									and referenced_database_name = @locdbname
									and ParentObjectName = @parentobjectname
									and srcdest > 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.ParentObjectName = @parentobjectname 
					GROUP BY OutTab.ParentObjectName 

					SET @dbident = 'dblocal_' + @locdbname + @stringPos +  @parentobjectname 

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

					insert into #gvfile values ('		} # end cluster_localdb')

					if @dbsrcobjects is not null
						insert into #gvfile values ('		' + @dbident + ' -> ' + @parentobjectname  + ' [ltail='+@clusterIdent+'];')
					if @dbtargobjects is not null
						insert into #gvfile values ('		' + @parentobjectname + ' -> ' + @dbident  + '_t [lhead='+@clusterIdent+'] ;')

					FETCH NEXT FROM locsvrdb_Cursor_p into @locdbname, @parentobjectname;  
				END;  
				CLOSE locsvrdb_Cursor_p;  
				DEALLOCATE locsvrdb_Cursor_p;  
		
				-- Add remote server db objects subcluster(s)
				DECLARE remsvrdb_Cursor_p CURSOR FOR  
					SELECT distinct dl.referenced_server_name, dl.referenced_database_name, dl.ParentObjectName   
					FROM  @dep dl
					WHERE dl.referenced_server_name is not null
					and dl.referenced_database_name is not null
				Set @dbpos = 0;
				OPEN remsvrdb_Cursor_p;  
				FETCH NEXT FROM remsvrdb_Cursor_p into @remotesrv, @remdbname, @parentobjectname;  
				WHILE @@FETCH_STATUS = 0  
				BEGIN
					Set @dbpos = @dbpos + 1;
					Set @stringPos = convert(nvarchar,@dbpos);

					Set @cleanRemoteName = replace(replace(replace(replace(replace(replace(replace(@remotesrv, ' ', '_'), '(','_'), ')','_'), '-','_'),'\','_'),'[','_'),']', '_')

					SET @dbident = 'dbremote_' + '_' + @cleanRemoteName + @stringPos + '_'  +  @parentobjectname
					Set @clusterIdent = 'cluster_remote_' + @parentobjectname + @cleanRemoteName + '_' +  @remdbname + @stringPos

					-- Each unique db on the remote server has a cluster. Double quote server name node as may contain special chars.
					insert into #gvfile values ('		subgraph ' + @clusterIdent + ' {')

					insert into #gvfile values ('			label="Server: ' + @remotesrv +', DB: ' + @remdbname +  '"; ')			 
				  
					-- Get a pipe separated list of source objects from the remote server db

					SELECT 
						@remdbsrcobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.ParentObjectName = OutTab.ParentObjectName and 
									Level > 0 and 
									referenced_server_name= @remotesrv and
									referenced_database_name = @remdbname
									and ParentObjectName = @parentobjectname
									and srcdest = 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.ParentObjectName = @parentobjectname 
					GROUP BY OutTab.ParentObjectName 

					-- Get a pipe separated list of target objects from the remote server db
					SELECT 
						@remdbtargobjects = 
								STUFF ( ( SELECT ' | '+InrTab.ThisObjectName
									FROM @dep InrTab
									WHERE InrTab.ParentObjectName = OutTab.ParentObjectName and 
									Level > 0 and 
									referenced_server_name= @remotesrv and
									referenced_database_name = @remdbname
									and ParentObjectName = @parentobjectname
									and srcdest > 1
									GROUP BY InrTab.ThisObjectName
									ORDER BY InrTab.ThisObjectName
									FOR XML PATH(''),TYPE 
									).value('.','VARCHAR(MAX)') 
									, 1,1,SPACE(0))
					FROM @dep OutTab
					where OutTab.ParentObjectName = @parentobjectname 
					GROUP BY OutTab.ParentObjectName 

					if @remdbsrcobjects is not null
					begin
						insert into #gvfile values('			' + @dbident + ' [label="Source Table(s) ' + @remdbsrcobjects + '", shape = "Mrecord", fontsize=14]; ')
					end 

					if @remdbtargobjects is not null
					begin
						insert into #gvfile values('			' + @dbident + '_t [label="Target Table(s) ' + @remdbtargobjects + '", shape = "Mrecord", fontsize=14]; ')
					end
				
					insert into #gvfile values ('		} # end cluster_remotedb')

					if @remdbsrcobjects is not null
						insert into #gvfile values ('		' + @dbident + ' -> ' + @parentobjectname  + '[ltail=' + @clusterIdent +'];')
					if @remdbtargobjects is not null
						insert into #gvfile values ('		' + @parentobjectname + ' -> ' + @dbident + '_t [lhead=' + @clusterIdent +'] ;')

					FETCH NEXT FROM remsvrdb_Cursor_p into @remotesrv, @remdbname, @parentobjectname;  
				END;  
				CLOSE remsvrdb_Cursor_p;  
				DEALLOCATE remsvrdb_Cursor_p;
			end

			if @overview in ('Y', 'H')
				insert into #gvfile values ('	} # end cluster_top_ thisbaseobject')

			FETCH NEXT FROM baseobj_Cursor into @thisbaseobj, @loc;   
		END; 
		CLOSE baseobj_Cursor;  
		DEALLOCATE baseobj_Cursor; 

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
				values ('label=<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">
							<TR><TD href="http://composedsoftware.net" target="_blank" TOOLTIP="Composed Software Ltd">
								<B> <font color="#0000ff">' + @label + '</font></B>
							</TD></TR></TABLE>>')
			insert into #gvfile values ('} # end graph')
		end 

		select * from #gvfile
RETURN 0