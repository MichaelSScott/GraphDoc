/* =============================================
-- Author:		M Scott
-- Create date: 29/08/18
-- Description:	Given a job name, get each job
   step and return the result in table form.
   ============================================= */
CREATE FUNCTION [GraphDoc].[udf_cs_JobSteps]
(	
	@JobName nvarchar(255)
)
/* 
	The return table defines the user-defined table type udtt_JobStepGraphing.
	As yet a udf can't return a udtt so we're stuck with doing it this way.
*/
RETURNS TABLE 
AS
RETURN 
(
/*
	Value-added;
		Determine if the step is actually reachable based on success/fail conditions in the prior steps.
		Add the total number of steps in the job to each row.
*/
	with steplist as (
	select sj.name as jobname
		, sj.job_id
		, sj.description
		, count(*) over(partition by sj.name) as #steps
		, step_id
		, step_name
		, sjs.subsystem
		, sjs.command
		, sjs.database_name
		, sjs.on_success_action
		, sjs.on_success_step_id
		, sjs.on_fail_action
		, lag(case when sjs.on_success_action = 3 then 0 else 1 end, 1, 0) over(partition by sj.name order by step_id) as priors
	from msdb..sysjobs sj
	join msdb..sysjobsteps sjs on sjs.job_id = sj.job_id
	where sj.name = @JobName
	)
	select 
		  case when sum(priors) over(partition by jobname order by step_id) = 0 then 'Reachable' else 'Unreachable' end as IsReachable
		, jobname
		, description
		, #steps
		, step_id
		, step_name
		, subsystem
		, command
		, database_name
		, convert(varchar, next_run_date) + '.' + right('000000' + convert(varchar, next_run_time ), 6) as runat
		, ss.enabled
	from steplist l
	left join msdb..sysjobschedules s on s.job_id = l.job_id
	left join msdb..sysschedules ss on ss.schedule_id = s.schedule_id
)