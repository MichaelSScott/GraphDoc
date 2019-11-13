/* =============================================
-- Author:		M. Scott
-- Create date: 29/08/18
-- Description:	For a given job name generate 
   all the dependency graphs for the steps and
   the commands called (TSQL type jobs only).
   Results can be saved to a .gv file to be 
   drawn by graphviz.
-- ============================================= */
CREATE PROCEDURE [GraphDoc].[usp_cs_Job_Graphs]
	@JobName nvarchar(255),
	@bundle char(1) = 'Y', -- Y/N Y=merge job and steps into one gv file, N=produce separate graph for job and each job step.
	@collapse_nonlocal_db char(1) = 'N', -- Y/N, default N
	@direction char(2) = 'TB' -- LR, BT, RL. top to bottom, left to right, etc.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Random value for temporary ddl naming
	DECLARE @wrapper_id nvarchar(6);

	Set @wrapper_id = convert(nvarchar, convert(int, convert(decimal(10,6), rand())*1000000))

    -- Get the List of steps in the job into a table
	DECLARE @JobSteps AS GraphDoc.udtt_JobStepGraphing;
	 
	INSERT INTO @JobSteps
	select 'usp_wrapper_' + @wrapper_id + '_' + convert(nvarchar(3), step_id) + '_' + step_name
		, IsReachable
		, jobname
		, description
		, #steps
		, step_id
		, step_name
		, subsystem
		, command
		, database_name
		, runat
		, enabled
	from GraphDoc.udf_cs_JobSteps( @JobName )
	order by runat, jobname, step_id

	/*
		It's hard to know just what might be in a job step command so wrap them in stored procedures and let the dbms figure it out.
		Note that if a step has a 'GO' command embedded in it the ddl to create the proc WILL FAIL. Of course: it does not make
		sense for a procedure to have batches within it. If you encounter this then either remove the GO command from the step's t-sql OR
		if that's not possible then split the step into as many batches as are present. I'd argue that the latter option is what you 
		should do anyway, for a clearer set of job activities..
		First, wrap every step command in in big proc. This will get us a top level dependency graph. Note that this part isn't especially bright 
		at figuring out if any steps are being run in databases other than the one this routine is called from. The individual job steps make a better go of it.
	*/
	declare @pos int, @usedsteps int;
	declare @jobDescription nvarchar(max);
	declare @command nvarchar(max), @fatcommand nvarchar(max);

	set @pos = 1

	select @jobDescription = description from @JobSteps where step_id = 1 -- Job description is on every step so just get first.
	select @usedsteps = MAX(step_id) from @JobSteps where IsReachable = 'Reachable'


	set @fatcommand = ''
	while @pos <= @usedsteps
	BEGIN
		select @command = isnull(command, '')  from @JobSteps where step_id = @pos and subsystem = 'TSQL'
		set @fatcommand = @fatcommand + char(13) + @command 
				
		set @pos = @pos + 1
	END


	/*
		Generate DDL to create the procedure
	*/
	declare @ddl nvarchar(max);
	declare @procname nvarchar(255);

	declare @cleanJobName nvarchar(255);

	/* 
		Clunky replacement of characters in the job name that upset the ddl. 
		Add a clr assembly for regex and do this right. 
		Regex can also be used for finessing the table usage srcdest field in the dependencygraph
	*/
	set @cleanJobName = replace(replace(replace(replace(@JobName, ' ', ''), '(',''), ')',''), '-','')

	set @procname = 'usp_wrapper_' + @wrapper_id + '_' + @cleanJobName

	set @ddl = 'CREATE PROCEDURE GraphDoc.' + @procname +
		' AS
		BEGIN
			-- SET NOCOUNT ON added to prevent extra result sets from
			-- interfering with SELECT statements.
			SET NOCOUNT ON;
		 ' + @fatcommand + '
		END
		'
	exec( @DDL)

	/*
		Now generate a dependency graph for it.
		Create a dependency table for the new proc.
		Then pass that to the graph generator.
	*/
	declare @DepTable as GraphDoc.udtt_DependencyGraph

	Insert into @DepTable
	Select *
	FROM GraphDoc.udf_cs_DepTable('GraphDoc', @procname )

	/*
		Pass the dependency table to the graph generator.
		As procname is a generated value, use the jobname as the display value in the graph.
		If we want the whole job and steps in one graph the sequence of operations needs to be:
			main job - notail
			steps bar last step - body only
			last step nohead
		Otherwise generate a full gvfile for the job and each step separately
		Note that the DrawDependencyGraph proc simply returns a result set of gv file records.
	*/
	declare @graphsection tinyint -- 1 = all, 2 = notail, 4 = body, 8 = nohead
	if @bundle = 'Y'
		set @graphsection = 2
	else 
		set @graphsection = 1	
	
	-- As this is the top level job, set the overview flag to Y.
	DECLARE @overview char(1) = 'Y'
	DECLARE @displayJobName nvarchar(255) = 'Job:' + @JobName

	execute GraphDoc.usp_cs_DrawDependencyGraph @DepTable, @displayJobName, @collapse_nonlocal_db, @direction, @graphsection, @overview, @description=@jobDescription


	/*
		Then dump the proc just created as we don't want clutter.
	*/
	set @ddl = '
		IF EXISTS ( SELECT * 
				FROM   sysobjects 
				WHERE  id = object_id(N''GraphDoc.' + @procname + ''') 
					   and OBJECTPROPERTY(id, N''IsProcedure'') = 1 )
		DROP PROCEDURE GraphDoc.' + @procname
	exec (@ddl)	

	/*
		Then create a dependency graph for each job step in turn.
		This time we'll draw all steps, including unreachable ones, for reference.
		Turn overview off for job steps. This means that the table/view objects will 
		be common for all steps. It might look a little messy.
		If the subsystem type is not TSQL then mark it up with a message.
	*/
	DECLARE @prior nvarchar(255);
	Set @prior = @procname; -- retain a copy of the jobname
			
	Set @overview = 'N'
	declare @dbname nvarchar(255)
	declare @stepname nvarchar(255);
	declare @fullstepname nvarchar(255)
	declare @reachable nvarchar(20)
	declare @subsystem nvarchar(255)
	declare @warning nvarchar(max);
	declare @codesample nvarchar(max)

	set @pos = 1
	select @usedsteps = MAX(step_id) from @JobSteps

	while @pos <= @usedsteps
	BEGIN
		select @dbname = database_name,
			@command = case
				when subsystem = 'TSQL' then isnull(command, '') 
				else '' 
				end
			, @stepname = step_name, @reachable = IsReachable, @subsystem = subsystem  
		from @JobSteps 
		where step_id = @pos
		
		set @procname = 'usp_wrapper_' + @wrapper_id + '_' + @cleanJobName + '_Step_' + convert(nvarchar, @pos)
		set @fullstepname = 'Job:' + @JobName + ', Step: ' + convert(nvarchar, @pos) + ' (' + @stepname + ')'

		/* Generate DDL to create the procedure.
			The procedure is created inside the db you are running the graphdoc in, even if the step has a different
			database_name, as it does not know enough to create procs in other databases. Such procs may appear barren
			on the diagram, but a warning will be displayed.
		*/
		set @ddl = 'CREATE PROCEDURE GraphDoc.' + @procname +
		' AS
		BEGIN
			-- SET NOCOUNT ON added to prevent extra result sets from
			-- interfering with SELECT statements.
			SET NOCOUNT ON;
		 ' + @command + '
		END
		'
		exec( @DDL)

		/* generate a dependency graph */
		delete from @DepTable; /*clear down */

		Insert into @DepTable
		Select *
		FROM GraphDoc.udf_cs_DepTable( 'GraphDoc', @procname )

		/*
			Pass the dependency table to the graph generator.

		*/
		if @bundle = 'Y'
		begin
			if @pos < @usedsteps
				set @graphsection = 4
			else
				set @graphsection = 8
			/*
				Now here's a complete frig. I want to have edges connecting the job and each step. At the mo' I can't do this in the
				usp_cs_DrawDependencyGraph routine as there's no memory of preceding events. So I'm going to do it here, for now.
				Yes, it's horrible. Note that this is done before the graph is drawn. This is to ensure it's inside the final enclosure.
				Also, the minlen is to try get some more separation of the step clusters, as gv tends to squish them a bit too close for 
				my liking.
				This is only meaningful if the job and steps are bundled. If not then each graph is independent anyway.
			*/
			if @pos = 1 /* If this is the first step then the prior is the job overview cluster so set the edge to that cluster */
				Select '	{edge [color=deeppink] ' + @prior + ' -> ' + @procname + ' [ltail= cluster_top_' + @prior + ', minlen=2.5] }'
			else
				Select '	{edge [color=deeppink] ' + @prior + ' -> ' + @procname + ' [minlen=2.5] }'
			Set @prior = @procname;
		end
		else 
			set @graphsection = 1	

		/*
			If the job step is unreachable set the high bit in the graphsection, and set the description accordingly.
			This tells usp_cs_DrawDependencyGraph  to display the description against the step.
			Also, if the step type is not a TSQL command then note this on the warning.
		*/
		Set @warning = null
		if @reachable = 'Unreachable'
		begin
			Set @graphsection = @graphsection + 128 
			Set @warning = 'This step is unreachable!'
		end

		if @subsystem != 'TSQL'
		begin 
			if @warning is null 
			begin
				Set @graphsection = @graphsection + 128 
				Set @warning = 'Not a TSQL command. Check the job step directly for details.'
			end
			else
			begin
				Set @warning = @warning + ' ' + '\nAlso, not a TSQL command. Check the job step directly for details.'
			end
		end

		if @dbname != DB_NAME()
		begin 
			if @warning is null 
			begin
				Set @graphsection = @graphsection + 128 
				Set @warning = 'This job step runs in database ' + @dbname + '. GraphDoc isn''t smart enough \nto figure out everything it might be doing there.'
			end
			else
			begin
				Set @warning = @warning + ' ' + '\nFurthermore, this job step runs in database ' + @dbname + '. GraphDoc isn''t smart enough \nto figure out everything it might be doing there.'
			end
		end

		/* This is an attempt to get something readable from the sp code
		*/
		SELECT @codesample = 'Stored Procedure (first 10 lines only)&#x0D;&#x0D;' +
			(Select top 10  value AS [text()]
			 from 
				string_split(
					 @command, char(10)
				) 
				where ltrim(replace(value, char(9), ' ')) not like '--%'
				and len(ltrim(replace(value, char(9), ' '))) > 1
				for xml path (''))

		execute GraphDoc.usp_cs_DrawDependencyGraph @DepTable, @fullstepname, @collapse_nonlocal_db, @direction, @graphsection, @overview, @warning, @codesample

		/*
		Then dump the proc just created as we don't want clutter.
		*/
		set @ddl = '
			IF EXISTS ( SELECT * 
					FROM   sysobjects 
					WHERE  id = object_id(N''GraphDoc.' + @procname + ''') 
						   and OBJECTPROPERTY(id, N''IsProcedure'') = 1 )
			DROP PROCEDURE GraphDoc.' + @procname
		exec (@ddl)
		
		/* next step */		
		set @pos = @pos + 1
	END
END