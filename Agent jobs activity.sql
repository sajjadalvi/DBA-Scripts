--====================================================================
----script to see only Running agent Jobs id and SPID

select substring(program_name,55,7) 'to search'
from master..sysprocesses
where program_name like '%agent%' and program_name not like '%DatabaseMail – SQLAGENT -%'
and program_name not in ('SQLAgent – Alert Engine','SQLAgent – Generic Refresher','SQLAgent – Email Logger','SQLAgent – Job invocation engine','SQLAgent – Job Manager')

-- Then find the jobs name
--Get the job details from MSDB database by using the results you got from above query and replace them in where clause

select *
from msdb..sysjobs
where job_id like '%A68D437%'

--if you have more than one job running replace below job_id %strings%

select *
from msdb..sysjobs
where job_id like '%A68D437%' or job_id like '%4E742EB%' or job_id like '%FAEDF18%'

--====================================================================
----script to see running agent jobs
SELECT
    ja.job_id,
    j.name AS job_name,
    ja.start_execution_date,      
    ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
    Js.step_name
FROM msdb.dbo.sysjobactivity ja with (nolock) 
LEFT JOIN msdb.dbo.sysjobhistory jh with (nolock) 
    ON ja.job_history_id = jh.instance_id
JOIN msdb.dbo.sysjobs j with (nolock) 
    ON ja.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js with (nolock)
    ON ja.job_id = js.job_id
    AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
AND start_execution_date is not null
AND stop_execution_date is null
order by start_execution_date;

--====================================================================
----script to see all agent jobs detail status by Foqia

declare @tmp_sp_help_jobhistory table
(
    instance_id int null, 
    job_id uniqueidentifier null, 
    job_name sysname null, 
    step_id int null, 
    step_name sysname null, 
    sql_message_id int null, 
    sql_severity int null, 
    message nvarchar(4000) null, 
    run_status int null, 
    run_date int null, 
    run_time int null, 
    run_duration int null, 
    operator_emailed sysname null, 
    operator_netsent sysname null, 
    operator_paged sysname null, 
    retries_attempted int null, 
    server sysname null  
)

insert into @tmp_sp_help_jobhistory 
exec msdb.dbo.sp_help_jobhistory 
    @job_id = '7961f73e-4846-4367-a796-9a900c066b7e', -- Enter job id Here...
    @mode='FULL' 
        
SELECT
    tshj.instance_id AS [InstanceID],
    tshj.sql_message_id AS [SqlMessageID],
    tshj.message AS [Message],
    tshj.step_id AS [StepID],
    tshj.step_name AS [StepName],
    tshj.sql_severity AS [SqlSeverity],
    tshj.job_id AS [JobID],
    tshj.job_name AS [JobName],
    tshj.run_status AS [RunStatus],
    CASE tshj.run_date WHEN 0 THEN NULL ELSE
    convert(datetime, 
            stuff(stuff(cast(tshj.run_date as nchar(8)), 7, 0, '-'), 5, 0, '-') + N' ' + 
            stuff(stuff(substring(cast(1000000 + tshj.run_time as nchar(7)), 2, 6), 5, 0, ':'), 3, 0, ':'), 
            120) END AS [RunDate],
    tshj.run_duration AS [RunDuration],
    tshj.operator_emailed AS [OperatorEmailed],
    tshj.operator_netsent AS [OperatorNetsent],
    tshj.operator_paged AS [OperatorPaged],
    tshj.retries_attempted AS [RetriesAttempted],
    tshj.server AS [Server],
    getdate() as [CurrentDate]
FROM @tmp_sp_help_jobhistory as tshj
ORDER BY [InstanceID] ASC

--====================================================================
----script to see all agent jobs detail status by Foqia

SELECT DISTINCT T1.server AS [Server Name],
	T1.step_id AS [Step_id],
	T1.step_name AS [Step Name],
	SUBSTRING(T2.name,1,140) AS [SQL Job Name],
	msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
	CAST(CONVERT(DATETIME,CAST(run_date AS CHAR(8)),101) AS CHAR(11)) AS [Failure Date],
	msdb.dbo.agent_datetime(T1.run_date, T1.run_time) AS 'RunDateTime',
	T1.run_duration StepDuration,
	CASE T1.run_status
	WHEN 0 THEN 'Failed'
	WHEN 1 THEN 'Succeeded'
	WHEN 2 THEN 'Retry'
	WHEN 3 THEN 'Cancelled'
	WHEN 4 THEN 'In Progress'
	END AS ExecutionStatus,
	T1.message AS [Error Message]
	FROM
	msdb..sysjobhistory T1 with (nolock) INNER JOIN msdb..sysjobs T2 with (nolock) ON T1.job_id = T2.job_id
	WHERE
	T1.run_status NOT IN (1, 4)
	AND T1.step_id != 0
	--AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (DAY,(-1), GETDATE())), 112)
	AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (HOUR,(-8), GETDATE())), 112)
	--AND SUBSTRING(T2.name,1,140) NOT LIKE 'collection_set_%'
	--AND SUBSTRING(T2.name,1,140) NOT LIKE 'STATS-Load WRH Stats'	
	--AND SUBSTRING(T2.name,1,140) NOT IN ('STATS_Load_DAX_IndexTxCount_Stats','STATS-Load WRH Stats')
	order by [Failure Date] desc

--====================================================================
----script to see all agent jobs detail status 


DECLARE @Job_ID as varchar(100)
SET @Job_ID = '%' -- you can specify a job id to query for a certain job

		CREATE TABLE #JobResults
			(job_id uniqueidentifier NOT NULL, 
			last_run_date int NOT NULL, 
			last_run_time int NOT NULL, 
			next_run_date int NOT NULL, 
			next_run_time int NOT NULL, 
			next_run_schedule_id int NOT NULL, 
			requested_to_run int NOT NULL, /* bool*/ 
			request_source int NOT NULL, 
			request_source_id sysname 
			COLLATE database_default NULL, 
			running int NOT NULL, /* bool*/ 
			current_step int NOT NULL, 
			current_retry_attempt int NOT NULL, 
			job_state int NOT NULL) 

		INSERT	#JobResults 
		EXEC master.dbo.xp_sqlagent_enum_jobs 1, '';

		SELECT	
			r.job_id, 
			job.name as Job_Name, 
			
			(select top 1 start_execution_date 
					FROM [msdb].[dbo].[sysjobactivity]
					where job_id = r.job_id
					order by start_execution_date desc) as Job_Start_DateTime,
					
			cast((select top 1 ISNULL(stop_execution_date, GETDATE()) - start_execution_date  
					FROM [msdb].[dbo].[sysjobactivity]
					where job_id = r.job_id
					order by start_execution_date desc) as time) as Job_Duration, 
					
			r.current_step AS Current_Running_Step_ID,
			CASE 
				WHEN r.running = 0 then jobinfo.last_run_outcome
				ELSE
					--convert to the uniform status numbers (my design)
					CASE
						WHEN r.job_state = 0 THEN 1	--success
						WHEN r.job_state = 4 THEN 1
						WHEN r.job_state = 5 THEN 1
						WHEN r.job_state = 1 THEN 2	--in progress
						WHEN r.job_state = 2 THEN 2
						WHEN r.job_state = 3 THEN 2
						WHEN r.job_state = 7 THEN 2
					END
			END as Run_Status,
			CASE 
				WHEN r.running = 0 then 
					-- convert to the uniform status numbers (my design)
					-- no longer running, use the last outcome in the sysjobservers
					-- sysjobservers will give last run status, but does not know about current running jobs
					CASE 
						WHEN jobInfo.last_run_outcome = 0 THEN 'Failed'
						WHEN jobInfo.last_run_outcome = 1 THEN 'Success'
						WHEN jobInfo.last_run_outcome = 3 THEN 'Canceled'
						ELSE 'Unknown'
					end
					-- convert to the uniform status numbers (my design)
					-- if running, use the job state in xp_sqlagent_enum_jobs	
					-- xp_sqlagent_enum_jobs will give current status, but does not know if a completed job
					-- succeeded, failed or was canceled.
					WHEN r.job_state = 0 THEN 'Success'
					WHEN r.job_state = 4 THEN 'Success'
					WHEN r.job_state = 5 THEN 'Success'
					WHEN r.job_state = 1 THEN 'In Progress'
					WHEN r.job_state = 2 THEN 'In Progress'
					WHEN r.job_state = 3 THEN 'In Progress'
					WHEN r.job_state = 7 THEN 'In Progress'
				 ELSE 'Unknown' END AS Run_Status_Description
		FROM	#JobResults as r left join
				msdb.dbo.sysjobservers as jobInfo on r.job_id = jobInfo.job_id inner join
				msdb.dbo.sysjobs as job on r.job_id = job.job_id 
		WHERE	cast(r.job_id as varchar(100)) like @Job_ID
				and job.[enabled] = 1
		AND job.name like 'SNAPSHOT_%'
		order by job.name
		
		DROP TABLE #JobResults	


SET @Job_ID = 'B6C41BC6-7A73-49BC-A8F3-165600F07F89'

DECLARE @Job_Start_DateTime as smalldatetime

--SET @Job_Start_DateTime = (
select top 1 start_execution_date 
            FROM [msdb].[dbo].[sysjobactivity]
            where job_id = @Job_ID
            order by start_execution_date desc
		  --)

SELECT         
    Steps.step_id, 
    Steps.step_name, 
    run_status, 
    run_status_description, 
    Step_Start_DateTime,
    Step_Duration
FROM            
    (SELECT        
        Jobstep.step_name, 
        Jobstep.step_id
    FROM    msdb.dbo.sysjobsteps AS Jobstep
    WHERE job_id = @Job_ID) AS Steps LEFT JOIN
    
    (SELECT
         JobHistory.step_id, 
         CASE --convert to the uniform status numbers we are using
            WHEN JobHistory.run_status = 0 THEN 0
            WHEN JobHistory.run_status = 1 THEN 1
            WHEN JobHistory.run_status = 2 THEN 2
            WHEN JobHistory.run_status = 4 THEN 2
            WHEN JobHistory.run_status = 3 THEN 3
            ELSE 'Unknown' 
         END AS run_status, 
         CASE 
            WHEN JobHistory.run_status = 0 THEN 'Failed' 
            WHEN JobHistory.run_status = 1 THEN 'Success' 
            WHEN JobHistory.run_status = 2 THEN 'In Progress'
            WHEN JobHistory.run_status = 4 THEN 'In Progress' 
            WHEN JobHistory.run_status = 3 THEN 'Canceled' 
            ELSE 'Unknown' 
         END AS run_status_description,
         CAST(STR(run_date) AS DATETIME) + CAST(STUFF(STUFF(REPLACE(STR(run_time, 6, 0), ' ', 
              '0'), 3, 0, ':'), 6, 0, ':') AS DATETIME) as Step_Start_DateTime,
         CAST(CAST(STUFF(STUFF(REPLACE(STR(JobHistory.run_duration % 240000, 6, 0), ' ', '0'), 
              3, 0, ':'), 6, 0, ':') AS DATETIME) AS DATETIME) AS Step_Duration
    FROM msdb..sysjobhistory as JobHistory WITH (NOLOCK) 
    WHERE job_id = @Job_ID and CAST(STR(run_date) AS DATETIME) + 
        CAST(STUFF(STUFF(REPLACE(STR(run_time, 6, 0), ' ', '0'), 
                   3, 0, ':'), 6, 0, ':') AS DATETIME) >= @Job_Start_DateTime
    ) AS StepStatus ON Steps.step_id = StepStatus.step_id
ORDER BY Steps.step_id


--====================================================================
-- script to see - specific job history 


SELECT 
	T1.server AS [Server Name],
	CASE T1.job_id
	WHEN N'3baa2af2-a95d-4f81-abe0-ed73d7590008' THEN 'DAX_GL_Cube_Processing_Full'
	WHEN N'a5a43620-b68f-4130-b1ef-9391d1652cc4' THEN 'DAX_GL_Cube_Processing_Incremental'
	END AS [Job Name],
	CAST(CONVERT(DATETIME,CAST(run_date AS CHAR(8)),101) AS CHAR(11)) AS [Date],
	msdb.dbo.agent_datetime(T1.run_date, T1.run_time) AS 'RunDateTime',
	T1.run_duration StepDuration,
	CASE T1.run_status
	WHEN 0 THEN 'Failed'
	WHEN 1 THEN 'Succeeded'
	WHEN 2 THEN 'Retry'
	WHEN 3 THEN 'Cancelled'
	WHEN 4 THEN 'In Progress'
	END AS ExecutionStatus,
	message
	FROM msdb..sysjobhistory T1 
	where T1.job_id IN (N'3baa2af2-a95d-4f81-abe0-ed73d7590008', N'a5a43620-b68f-4130-b1ef-9391d1652cc4') 
	AND T1.step_id = 0
	order by 4 desc	



--====================================================================
----script to see running agent jobs current steps status


SELECT
    ja.job_id,
    j.name AS job_name,
    ja.start_execution_date,      
    ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
    Js.step_name
FROM msdb.dbo.sysjobactivity ja 
LEFT JOIN msdb.dbo.sysjobhistory jh 
    ON ja.job_history_id = jh.instance_id
JOIN msdb.dbo.sysjobs j 
    ON ja.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js
    ON ja.job_id = js.job_id
    AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
AND start_execution_date is not null
AND stop_execution_date is null
order by start_execution_date;

--====================================================================
-- This will give provide you full status of all sql jobs

Use msdb
go
select distinct j.Name as "Job Name", j.job_id,
case j.enabled 
when 1 then 'Enable' 
when 0 then 'Disable' 
end as "Job Status", jh.run_date as [Last_Run_Date(YY-MM-DD)] , 
case jh.run_status 
when 0 then 'Failed' 
when 1 then 'Successful' 
when 2 then 'Retry'
when 3 then 'Cancelled' 
when 4 then 'In Progress' 
end as Job_Execution_Status
from sysJobHistory jh, sysJobs j
where j.job_id = jh.job_id and jh.run_date =  
(select max(hi.run_date) from sysJobHistory hi where jh.job_id = hi.job_id )-- to get latest date


--====================================================================
-- T-sql script to find schedule jobs list and steps 


use msdb
go

SELECT	jobs.name  AS [ScheduleName]
    , CASE [sch].[enabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [IsEnabled]
    --, CASE 
    --    WHEN [sch].[freq_type] = 64 THEN 'Start automatically when SQL Server Agent starts'
    --    WHEN [sch].[freq_type] = 128 THEN 'Start whenever the CPUs become idle'
    --    WHEN [sch].[freq_type] IN (4,8,16,32) THEN 'Recurring'
    --    WHEN [sch].[freq_type] = 1 THEN 'One Time'
    --  END [ScheduleType]
    , CASE [sch].[freq_type]
        WHEN 1 THEN 'One Time'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly - Relative to Frequency Interval'
        WHEN 64 THEN 'Start automatically when SQL Server Agent starts'
        WHEN 128 THEN 'Start whenever the CPUs become idle'
      END [Occurrence]
    , CASE [sch].[freq_type]
        WHEN 4 THEN 'Occurs every ' + CAST([sch].[freq_interval] AS VARCHAR(3)) + ' day(s)'
        WHEN 8 THEN 'Occurs every ' + CAST([sch].[freq_recurrence_factor] AS VARCHAR(3)) 
                    + ' week(s) on '
                    + CASE WHEN [sch].[freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
                    + CASE WHEN [sch].[freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
                    + CASE WHEN [sch].[freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
                    + CASE WHEN [sch].[freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
                    + CASE WHEN [sch].[freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
                    + CASE WHEN [sch].[freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
                    + CASE WHEN [sch].[freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
        WHEN 16 THEN 'Occurs on Day ' + CAST([sch].[freq_interval] AS VARCHAR(3)) 
                     + ' of every '
                     + CAST([sch].[freq_recurrence_factor] AS VARCHAR(3)) + ' month(s)'
        WHEN 32 THEN 'Occurs on '
                     + CASE[sch].[freq_relative_interval]
                        WHEN 1 THEN 'First'
                        WHEN 2 THEN 'Second'
                        WHEN 4 THEN 'Third'
                        WHEN 8 THEN 'Fourth'
                        WHEN 16 THEN 'Last'
                       END
                     + ' ' 
                     + CASE [sch].[freq_interval]
                        WHEN 1 THEN 'Sunday'
                        WHEN 2 THEN 'Monday'
                        WHEN 3 THEN 'Tuesday'
                        WHEN 4 THEN 'Wednesday'
                        WHEN 5 THEN 'Thursday'
                        WHEN 6 THEN 'Friday'
                        WHEN 7 THEN 'Saturday'
                        WHEN 8 THEN 'Day'
                        WHEN 9 THEN 'Weekday'
                        WHEN 10 THEN 'Weekend day'
                       END
                     + ' of every ' + CAST([sch].[freq_recurrence_factor] AS VARCHAR(3)) 
                     + ' month(s)'
      END AS [Recurrence]
    , CASE [sch].[freq_subday_type]
        WHEN 1 THEN 'Occurs once at ' 
                    + STUFF(
                 STUFF(RIGHT('000000' + CAST([sch].[active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 2 THEN 'Occurs every ' 
                    + CAST([sch].[freq_subday_interval] AS VARCHAR(3)) + ' Second(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([sch].[active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([sch].[active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 4 THEN 'Occurs every ' 
                    + CAST([sch].[freq_subday_interval] AS VARCHAR(3)) + ' Minute(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([sch].[active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([sch].[active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 8 THEN 'Occurs every ' 
                    + CAST([sch].[freq_subday_interval] AS VARCHAR(3)) + ' Hour(s) between ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([sch].[active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([sch].[active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
      END [Frequency]
    , CAST(STR(run_date) AS DATETIME) + CAST(STUFF(STUFF(REPLACE(STR(run_time, 6, 0), ' ', 
              '0'), 3, 0, ':'), 6, 0, ':') AS DATETIME) as Step_Start_DateTime,
         CAST(CAST(STUFF(STUFF(REPLACE(STR(JobHistory.run_duration % 240000, 6, 0), ' ', '0'), 
              3, 0, ':'), 6, 0, ':') AS DATETIME) AS DATETIME) AS Step_Duration
	--,STUFF(STUFF(CAST([sch].[active_start_date] AS VARCHAR(8)), 5, 0, '-') , 8, 0, '-') AS [ScheduleUsageStartDate]
     --,STUFF(STUFF(CAST([sch].[active_end_date] AS VARCHAR(8)), 5, 0, '-'), 8, 0, '-') AS [ScheduleUsageEndDate]
    , [sch].[date_created] AS [ScheduleCreatedOn]
    , [sch].[date_modified] AS [ScheduleLastModifiedOn]
FROM [dbo].[sysjobs] as jobs
join msdb..sysjobhistory as JobHistory WITH (NOLOCK) ON jobs.job_id = JobHistory.job_id
LEFT OUTER JOIN dbo.sysjobschedules as jsch ON jobs.job_id = jsch.job_id
INNER JOIN dbo.sysschedules as sch ON jsch.schedule_id = sch.schedule_id 
where -- jobs.name like 'SNAPSHOT_%' and 
sch.enabled = 1
ORDER BY 3, [ScheduleName]




--====================================================================
-- T-sql script to find next running agent jobs detail (date/time)

SELECT job.[job_id] AS [JobID]
        ,job.[name] AS [JobName]
        --<span style="color: green;">--Convert integer date yyyymmdd and integer time [h]hmmss 
        --into a readable date/time field</span>
        ,CONVERT(VARCHAR(50),
                 CAST(STUFF(STUFF(CAST(jobsch.[next_run_date] AS VARCHAR(8))
                                 ,5
                                 ,0
                                 ,'-')
                            ,8
                            ,0
                            ,'-') AS DATETIME)
               + CAST(STUFF(STUFF(CAST(RIGHT('000000' 
                                               + CAST(jobsch.[next_run_time] 
                                                      AS VARCHAR(6))
                                            , 6) AS VARCHAR(8))
                                 ,3
                                 ,0
                                 ,':')
                     ,6
                     ,0
                     ,':') AS DATETIME)
               ,100) AS [Next Run Time]
   FROM [msdb].[dbo].[sysjobs] AS job
        LEFT JOIN [msdb].[dbo].[sysjobschedules] AS jobsch 
                  ON (job.[job_id] = jobsch.[job_id])
        LEFT JOIN [msdb].[dbo].[sysschedules] AS syssch 
                  ON (jobsch.[schedule_id] = syssch.[schedule_id])
  WHERE job.[enabled] = 1
    AND jobsch.[next_run_date] IS NOT NULL
    --AND jobsch.[next_run_date] &gt; 0
  ORDER BY jobsch.[next_run_date]
          ,jobsch.[next_run_time];


--====================================================================
-- T-sql script to find agent jobs detail

SELECT DISTINCT substring(a.name,1,100) AS [Job Name], 
'Enabled'=case 
WHEN a.enabled = 0 THEN 'No'
WHEN a.enabled = 1 THEN 'Yes'
end, 
substring(b.name,1,30) AS [Name of the schedule],
'Frequency of the schedule execution'=case
WHEN b.freq_type = 1 THEN 'Once'
WHEN b.freq_type = 4 THEN 'Daily'
WHEN b.freq_type = 8 THEN 'Weekly'
WHEN b.freq_type = 16 THEN 'Monthly'
WHEN b.freq_type = 32 THEN 'Monthly relative'	
WHEN b.freq_type = 32 THEN 'Execute when SQL Server Agent starts'
END,	
'Units for the freq_subday_interval'=case
WHEN b.freq_subday_type = 1 THEN 'At the specified time' 
WHEN b.freq_subday_type = 2 THEN 'Seconds' 
WHEN b.freq_subday_type = 4 THEN 'Minutes' 
WHEN b.freq_subday_type = 8 THEN 'Hours' 
END,
SUBSTRING(CAST(b.active_start_date AS VARCHAR(8)), 5, 2) + '-' + SUBSTRING(CAST(b.active_start_date AS VARCHAR(8)), 7, 2) + '-' + SUBSTRING(CAST(b.active_start_date AS VARCHAR(8)), 1, 4) As ActiveStartDate,
--b.active_end_date,	
SUBSTRING(CAST(c.next_run_date AS VARCHAR(8)), 5, 2) + '-' + SUBSTRING(CAST(c.next_run_date AS VARCHAR(8)), 7, 2) + '-' + SUBSTRING(CAST(c.next_run_date AS VARCHAR(8)), 1, 4) As NextRunDate,
--cast(cast(b.active_start_date as varchar(15)) as datetime) as active_start_date,	
--cast(cast(b.active_end_date as varchar(15)) as datetime) as active_end_date,	
--cast(cast(c.next_run_date as varchar(15)) as datetime) as next_run_date,	

Stuff(Stuff(right('000000'+Cast(c.next_run_time as Varchar),6),3,0,':'),6,0,':') as Run_Time,	

b.date_created

FROM msdb..sysjobhistory d 
INNER JOIN msdb..sysjobs a 
ON a.job_id = d.job_id 
INNER JOIN msdb..sysJobschedules c 
ON a.job_id = c.job_id 
INNER JOIN msdb..SysSchedules b 
ON b.Schedule_id=c.Schedule_id
ORDER BY [Frequency of the schedule execution],
[NextRunDate],
[Run_Time];

GO

--====================================================================
-- T-sql script to find failed agent jobs in last 24 hours

SELECT DISTINCT T1.server AS [Server Name],
T1.step_id AS [Step_id],
T1.step_name AS [Step Name],
SUBSTRING(T2.name,1,140) AS [SQL Job Name],
msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
CAST(CONVERT(DATETIME,CAST(run_date AS CHAR(8)),101) AS CHAR(11)) AS [Failure Date],
msdb.dbo.agent_datetime(T1.run_date, T1.run_time) AS 'RunDateTime',
T1.run_duration StepDuration,
CASE T1.run_status
WHEN 0 THEN 'Failed'
WHEN 1 THEN 'Succeeded'
WHEN 2 THEN 'Retry'
WHEN 3 THEN 'Cancelled'
WHEN 4 THEN 'In Progress'
END AS ExecutionStatus,
T1.message AS [Error Message]
FROM
msdb..sysjobhistory T1 with (nolock) INNER JOIN msdb..sysjobs T2 with (nolock) ON T1.job_id = T2.job_id
WHERE
T1.run_status NOT IN (1, 4)
AND T1.step_id != 0
--AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (DAY,(-1), GETDATE())), 112)
AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (HOUR,(-8), GETDATE())), 112)
order by [Failure Date] desc

--======================================================================
-- T-SQL Query to find last run status of scheduled Jobs

USE msdb
GO
SELECT DISTINCT SJ.Name AS JobName, SJ.description AS JobDescription,
SJH.run_date AS LastRunDate, 
CASE SJH.run_status 
WHEN 0 THEN 'Failed'
WHEN 1 THEN 'Successful'
WHEN 3 THEN 'Cancelled'
WHEN 4 THEN 'In Progress'
END AS LastRunStatus
FROM sysjobhistory SJH, sysjobs SJ
WHERE SJ.Name = 'test%' and SJH.job_id = SJ.job_id and SJH.run_date = 
(SELECT MAX(SJH1.run_date) FROM sysjobhistory SJH1 WHERE SJH.job_id = SJH1.job_id)
ORDER BY SJH.run_date desc

--======================================================================
-- T-SQL Query to find currently running jobs

SELECT  JA.session_id as Running_Jobs,  
  JA.Start_execution_date As Starting_time,
        datediff(MINUTE, JA.Start_execution_date,getdate()) as [Has_been_running(in Sec)]
FROM msdb.dbo.sysjobactivity JA

--======================================================================
--To see current jobs activity
SELECT
    ja.job_id,
    j.name AS job_name,
    ja.start_execution_date,      
    ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
    Js.step_name
FROM msdb.dbo.sysjobactivity ja 
LEFT JOIN msdb.dbo.sysjobhistory jh 
    ON ja.job_history_id = jh.instance_id
JOIN msdb.dbo.sysjobs j 
    ON ja.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js
    ON ja.job_id = js.job_id
    AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
AND start_execution_date is not null
AND stop_execution_date is null
order by start_execution_date;

--======================================================================
--# t-sql script to check upcoming scheduled jobs for sql server agent

SELECT job.[job_id] AS [JobID]
        ,job.[name] AS [JobName]
        --<span style="color: green;">--Convert integer date yyyymmdd and integer time [h]hmmss 
        --into a readable date/time field</span>
        ,CONVERT(VARCHAR(50),
                 CAST(STUFF(STUFF(CAST(jobsch.[next_run_date] AS VARCHAR(8))
                                 ,5
                                 ,0
                                 ,'-')
                            ,8
                            ,0
                            ,'-') AS DATETIME)
               + CAST(STUFF(STUFF(CAST(RIGHT('000000' 
                                               + CAST(jobsch.[next_run_time] 
                                                      AS VARCHAR(6))
                                            , 6) AS VARCHAR(8))
                                 ,3
                                 ,0
                                 ,':')
                     ,6
                     ,0
                     ,':') AS DATETIME)
               ,100) AS [Next Run Time]
   FROM [msdb].[dbo].[sysjobs] AS job
        LEFT JOIN [msdb].[dbo].[sysjobschedules] AS jobsch 
                  ON (job.[job_id] = jobsch.[job_id])
        LEFT JOIN [msdb].[dbo].[sysschedules] AS syssch 
                  ON (jobsch.[schedule_id] = syssch.[schedule_id])
  WHERE job.[enabled] = 1
    AND jobsch.[next_run_date] IS NOT NULL
    --AND jobsch.[next_run_date] &gt; 0
  ORDER BY jobsch.[next_run_date]
          ,jobsch.[next_run_time];

--======================================================================
-- script to see

select 
 j.name as 'JobName',
 s.step_id as 'Step',
 s.step_name as 'StepName',
 msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
 ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60) 
         as 'RunDurationMinutes'
From msdb.dbo.sysjobs j 
INNER JOIN msdb.dbo.sysjobsteps s 
 ON j.job_id = s.job_id
INNER JOIN msdb.dbo.sysjobhistory h 
 ON s.job_id = h.job_id 
 AND s.step_id = h.step_id 
 AND h.step_id <> 0
where j.enabled = 1   --Only Enabled Jobs
--and j.name = 'TestJob' --Uncomment to search for a single job
/*
and msdb.dbo.agent_datetime(run_date, run_time) 
BETWEEN '12/08/2012' and '12/10/2012'  --Uncomment for date range queries
*/
order by JobName, RunDateTime desc

--======================================================================
--# t-sql script to see jobs current history

Declare @jobId as uniqueidentifier
 select 
  j.job_id,j.Name as "Job Name", j.description as "Job Description", h.run_date as LastStatusDate, 
case h.run_status 
when 0 then 'Failed' 
when 1 then 'Successful' 
when 3 then 'Cancelled' 
when 4 then 'In Progress' 
end as JobStatus
from msdb.dbo.sysJobHistory h, msdb.dbo.sysJobs j
where j.job_id = h.job_id 
--and H.run_status = 0
--AND h.run_date > ()
and h.run_date = (select max(hi.run_date) from msdb.dbo.sysJobHistory hi where h.job_id = hi.job_id)  and h.run_status=0
order by 4 DESC
--====================================================================
-- T-sql script to find failed jobs in last 24 hours
SELECT DISTINCT T1.server AS [Server Name],
T1.step_id AS [Step_id],
T1.step_name AS [Step Name],
SUBSTRING(T2.name,1,140) AS [SQL Job Name],
msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
CAST(CONVERT(DATETIME,CAST(run_date AS CHAR(8)),101) AS CHAR(11)) AS [Failure Date],
msdb.dbo.agent_datetime(T1.run_date, T1.run_time) AS 'RunDateTime',
T1.run_duration StepDuration,
CASE T1.run_status
WHEN 0 THEN 'Failed'
WHEN 1 THEN 'Succeeded'
WHEN 2 THEN 'Retry'
WHEN 3 THEN 'Cancelled'
WHEN 4 THEN 'In Progress'
END AS ExecutionStatus,
T1.message AS [Error Message]
FROM
msdb..sysjobhistory T1 INNER JOIN msdb..sysjobs T2 ON T1.job_id = T2.job_id
WHERE
T1.run_status NOT IN (1, 4)
AND T1.step_id != 0
AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (DAY,(-1), GETDATE())), 112)

--======================================================================
--T-SQL to find Job Owners name status

SELECT SERVERPROPERTY('ServerName') As 'Server Name',
name,
enabled as Status,
SUSER_SNAME(owner_sid) AS owner 
FROM msdb.dbo.sysjobs;

--======================================================================
-- T-SQL to find Job History For Certain Time Period( 6 Months )

--Search for 'YourJobName', replace with your job name--
-- For example my job name is 'Growth report'--
-- Replace 'Growth report' with 'YourJobName'--


select @@SERVERNAME,
 j.name as 'JobName',
 run_status,
 msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
 ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60) 
         as 'RunDurationMinutes'
From msdb.dbo.sysjobs j 
INNER JOIN msdb.dbo.sysjobsteps s 
ON j.job_id = s.job_id
INNER JOIN msdb.dbo.sysjobhistory h 
 ON s.job_id = h.job_id 
 where j.enabled = 1   and j.name = 'YourJobName'

and msdb.dbo.agent_datetime(run_date, run_time) 
BETWEEN '2016/01/01' and '2016/06/08'  

--======================================================================
-- T-SQL to find the Currently running jobs with startup time, start job time, job start time

SELECT
ja.job_id,
j.name AS job_name,
ja.start_execution_date,      
ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
Js.step_name
FROM msdb.dbo.sysjobactivity ja 
LEFT JOIN msdb.dbo.sysjobhistory jh 
ON ja.job_history_id = jh.instance_id
JOIN msdb.dbo.sysjobs j 
ON ja.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js
ON ja.job_id = js.job_id
AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions   ORDER BY agent_start_date DESC)
AND start_execution_date is not null
AND stop_execution_date is null

--======================================================================
-- T-SQL to find 

with qry as
(select job_id,last_executed_step_id
 from msdb.dbo.sysjobactivity
 where last_executed_step_id is not null)
select 
   job_name, 
   CASE run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
    END
    AS
    run_status,
   convert(date,convert(varchar,run_date)) run_date, 
    Isnull(Substring(CONVERT(VARCHAR, run_time + 1000000), 2, 2) + ':' +
                Substring(CONVERT(VARCHAR, run_time + 1000000), 4, 2)
        + ':' +
        Substring(CONVERT(VARCHAR, run_time + 1000000), 6, 2), '') as run_time,
   run_duration, step_name, message
 from qry
cross apply
(select top (qry.last_executed_step_id + 1)
        sysjobs.name as job_name,
        sysjobhistory.run_status,
        run_date, run_time,
        run_duration, step_name,
        message, step_id
             FROM   msdb.dbo.sysjobhistory
             INNER JOIN msdb.dbo.sysjobs
               ON msdb.dbo.sysjobhistory.job_id = msdb.dbo.sysjobs.job_id
    where msdb.dbo.sysjobs.job_id=qry.job_id
order by run_date desc,run_time desc) t
where run_status<>1
order by job_name,step_id



------------------------------------------------------------
------------------------------------------------------------

	--Varibale Declarations
	declare @job_id uniqueidentifier = NULL
	declare @num_days int
	declare @first_day datetime, @last_day datetime
	declare @first_num int

	if @num_days is null
		set @num_days=30

	set @last_day = getdate()
	set @first_day = dateadd(dd, -@num_days, @last_day)

	select @first_num= cast(year(@first_day) as char(4))
		+replicate('0',2-len(month(@first_day)))+ cast(month(@first_day) as varchar(2))
		+replicate('0',2-len(day(@first_day)))+ cast(day(@first_day) as varchar(2))

	 --Basic Job Information  
	;With bjinfo as
	(
		Select 
			A.job_id, B.name, Case B.enabled
			When 1 Then 'Yes'
			When 0 Then 'No' Else 'Unknown' End As 'Enabled', 	
			/* -- Only for later version of SQL Server 2005 */
			msdb.dbo.SQLAGENT_SUSER_SNAME(b.owner_sid) 'Job Owner',  
			(Select Top 1 next_scheduled_run_date From msdb.dbo.sysjobactivity Where job_id = A.job_id Order by session_id desc) as 'NextRunDateTime',
			msdb.dbo.agent_datetime(last_run_date, last_run_time) as 'LastRunDateTime',  
			Case last_run_outcome
				When 0 Then 'Failed'  
				When 1 Then 'Succeeded'
				When 2 Then 'Retry'
				When 3 Then 'Cancelled'
				Else 'NA' 
			End Last_Run_Status, 
			last_run_duration,	
			case
				when (len(cast(last_run_duration as varchar(20))) < 3)  
					then cast(last_run_duration as varchar(6))
				WHEN (len(cast(last_run_duration as varchar(20))) = 3)  
					then LEFT(cast(last_run_duration as varchar(6)),1) * 60  
						+ RIGHT(cast(last_run_duration as varchar(6)),2)  
				WHEN (len(cast(last_run_duration as varchar(20))) = 4)  
					then LEFT(cast(last_run_duration as varchar(6)),2) * 60   
						+ RIGHT(cast(last_run_duration as varchar(6)),2)  
				WHEN (len(cast(last_run_duration as varchar(20))) >= 5)  
					then (Left(cast(last_run_duration as varchar(20)),len(last_run_duration)-4)) * 3600   		
						+(substring(cast(last_run_duration as varchar(20)) , len(last_run_duration)-3, 2)) * 60	
						+ Right(cast(last_run_duration as varchar(20)) , 2)					
			End As 'Last_RunDuration',
			CONVERT(DATETIME, RTRIM(last_run_date)) + ((last_run_time + last_run_duration) * 9 + (last_run_time + last_run_duration) % 10000 * 6 
				+ (last_run_time + last_run_duration) % 100 * 10) / 216e4 AS Last_RunFinishDateTime,
			Case last_run_outcome
				When 1 Then  
					Left(Replace(last_outcome_message,'The job succeeded.  The Job was invoked by',''),  
					Charindex('.',Replace(last_outcome_message,'The job succeeded.  The Job was invoked by','')))   
				When 0 Then  
					Left(Replace(last_outcome_message,'The job failed.  The Job was invoked by',''),  
				Charindex('.',Replace(last_outcome_message,'The job failed.  The Job was invoked by','')))   
				When 3 Then  
					Left(Replace(last_outcome_message,'The job was stopped prior to completion by ',''),  
				Charindex('.',Replace(last_outcome_message,'The job was stopped prior to completion by ','')))   
			End 'LastInvokedBy',  
			Case last_run_outcome
				When 3 Then  
					Left(Replace(last_outcome_message,'The job failed.  The Job was invoked by',''),  
				Charindex('.',Replace(last_outcome_message,'The job failed.  The Job was invoked by','')))   
				Else ''
			End 'Cancelled/Stopped By', 
			last_outcome_message 'Message'  
		 From msdb.dbo.sysjobs B   
		 Left Join (select job_id,last_run_outcome,last_outcome_message,case when last_run_date = 0
		                                                      then 19900101
															  else
															  last_run_date end last_run_date,last_run_time,last_run_duration from msdb.dbo.SysJobServers) A on A.job_id = B.job_id
		-- Left Join msdb.dbo.sysjobschedules D on A.job_id = D.job_id
		Where ((A.job_id = @job_id  and @Job_id is not null) OR (1=1 and @Job_id is null)) 
		 --And 
		-- ISNULL(last_run_date,0) <>0  --And ISNULL(next_run_date,0) <>0
	),
	bjhistory as
	( 	select
				jobhist.job_id,
				jobs.name,
				jobhist.step_id,
				run_dur_Casted = case 
					when (len(cast(jobhist.run_duration as varchar(20))) < 3)  
						then cast(jobhist.run_duration as varchar(6))
					WHEN (len(cast(jobhist.run_duration as varchar(20))) = 3)  
						then LEFT(cast(jobhist.run_duration as varchar(6)),1) * 60   
							+ RIGHT(cast(jobhist.run_duration as varchar(6)),2)  
					WHEN (len(cast(jobhist.run_duration as varchar(20))) = 4)  
						then LEFT(cast(jobhist.run_duration as varchar(6)),2) * 60   
							+ RIGHT(cast(jobhist.run_duration as varchar(6)),2) 
					WHEN (len(cast(jobhist.run_duration as varchar(20))) >= 5)  
						then (Left(cast(jobhist.run_duration as varchar(20)),len(jobhist.run_duration)-4)) * 3600   		
							+(substring(cast(jobhist.run_duration as varchar(20)) , len(jobhist.run_duration)-3, 2)) * 60	
							+ Right(cast(jobhist.run_duration as varchar(20)) , 2)					
					end
				from msdb.dbo.sysjobhistory jobhist
				Inner Join msdb.dbo.sysjobs jobs On jobhist.job_id = jobs.job_id
				where	jobhist.job_id=jobs.job_id
					and jobhist.run_date>= @first_num
					and jobhist.step_id=0
					and ((jobs.job_id = @job_id  and @Job_id is not null) OR (1=1 and @Job_id is null)) 
			)
	,bjstats
			As
			(
				Select jobs.job_id
					,jobs.name
					,'Sampling'=(select count(*) from bjhistory jobhist where jobhist.job_id=jobs.job_id)
					,'run_dur_max'=(select max(run_dur_Casted) from bjhistory jobhist where jobhist.job_id=jobs.job_id)
					,'run_dur_min'=(select min(run_dur_Casted) from bjhistory jobhist where jobhist.job_id=jobs.job_id)
					,'run_dur_avg'=(select avg(run_dur_Casted) from bjhistory jobhist where jobhist.job_id=jobs.job_id)
				from msdb..sysjobs jobs
				Where ((jobs.job_id = @job_id  and @Job_id is not null) OR (1=1 and @Job_id is null))
			)
	   select bjinfo.Name as 'Job_Name', bjinfo.Enabled,bjinfo.Last_Run_Status [Current Run Status], 
				bjinfo.LastRunDateTime [Current Run StartTime],bjinfo.Last_RunFinishDateTime [Current Run EndTime],
				Right('00'+cast(bjinfo.Last_RunDuration/3600 as varchar(10)),2)
				+':'+replicate('0',2-len((bjinfo.Last_RunDuration % 3600)/60))+cast((bjinfo.Last_RunDuration % 3600)/60 as varchar(2))
				+':'+replicate('0',2-len((bjinfo.Last_RunDuration % 3600) %60))+cast((bjinfo.Last_RunDuration % 3600)%60 as varchar(2)) 'Currnet Run Duration',
				'Avg. Duration' = cast(run_dur_avg/3600 as varchar(10))
					+':'+replicate('0',2-len((run_dur_avg % 3600)/60))+cast((run_dur_avg % 3600)/60 as varchar(2))
					+':'+replicate('0',2-len((run_dur_avg % 3600) %60))+cast((run_dur_avg % 3600)%60 as varchar(2)),
				'Max. Duration' = cast(run_dur_max/3600 as varchar(10))
					+':'+replicate('0',2-len((run_dur_max % 3600)/60))+cast((run_dur_max % 3600)/60 as varchar(2))
					+':'+replicate('0',2-len((run_dur_max % 3600) %60))+cast((run_dur_max % 3600)%60 as varchar(2)),
				'Min. Duration' = cast(run_dur_min/3600 as varchar(10))
					+':'+replicate('0',2-len((run_dur_min % 3600)/60))+cast((run_dur_min % 3600)/60 as varchar(2))
					+':'+replicate('0',2-len((run_dur_min % 3600) %60))+cast((run_dur_min % 3600)%60 as varchar(2)),
		        bjstats.Sampling,bjinfo.NextRunDateTime					
		From bjinfo
		left outer join bjstats on bjinfo.job_id = bjstats.job_id
		where bjinfo.name like 'SNAPSHOT%'
		Order by bjinfo.name 

	 --As per few suggestions from my collegues, I added History details for a job if the job id is passed.
	 If (@job_id is not null)
	 Begin
		;With CteJobHistory
		As
		(
			 Select jobs.job_id,name,
			 Case when run_status = 0 Then
				(Select Top 1 message From msdb.dbo.sysjobhistory A
					Where A.job_id = jobs.job_id and A.run_date = jobhist.run_date and A.run_time = jobhist.run_time
					and step_id = 1
				)	
				Else jobhist.Message
			 End Message			
			,msdb.dbo.agent_datetime(run_date,run_time) run_datetime,
			case
					when (len(cast(run_duration as varchar(20))) < 3)  
						then cast(run_duration as varchar(6))
					WHEN (len(cast(run_duration as varchar(20))) = 3)  
						then LEFT(cast(run_duration as varchar(6)),1) * 60  
							+ RIGHT(cast(run_duration as varchar(6)),2)  
					WHEN (len(cast(run_duration as varchar(20))) = 4)  
						then LEFT(cast(run_duration as varchar(6)),2) * 60   
							+ RIGHT(cast(run_duration as varchar(6)),2)  
					WHEN (len(cast(run_duration as varchar(20))) >= 5)  
						then (Left(cast(run_duration as varchar(20)),len(run_duration)-4)) * 3600   		
							+(substring(cast(run_duration as varchar(20)) , len(run_duration)-3, 2)) * 60	
							+ Right(cast(run_duration as varchar(20)) , 2)					
				End As 'RunDuration',
				CONVERT(DATETIME, RTRIM(run_date)) + ((run_time + run_duration) * 9 + (run_time + run_duration) % 10000 * 6 
				+ (run_time + run_duration) % 100 * 10) / 216e4 AS RunFinishDateTime,
			 Case run_status
					When 0 Then 'Failed'  
					When 1 Then 'Succeeded'
					When 2 Then 'Retry'
					When 3 Then 'Cancelled'
					Else 'NA' 
				End Last_Run_Status
			from msdb.dbo.sysjobhistory jobhist
				Inner Join msdb.dbo.sysjobs jobs On jobhist.job_id = jobs.job_id
			 Where jobs.job_id = @job_id and step_id =0
		)Select job_id,name,message,run_datetime,
				Right('00'+cast(RunDuration/3600 as varchar(10)),2)
				+':'+replicate('0',2-len((RunDuration % 3600)/60))+cast((RunDuration % 3600)/60 as varchar(2))
				+':'+replicate('0',2-len((RunDuration % 3600) %60))+cast((RunDuration % 3600)%60 as varchar(2)) 'RunDuration', RunFinishDateTime
				Last_Run_Status From CteJobHistory
		 Order by run_datetime desc
	 End

------------------------------------------------------------
------------------------------------------------------------


use msdb
go
SELECT 
    [sJOB].[name] AS [JobName]
   -- , [sJSTP].[step_id] AS [JobStartStepNo]
    , [sJSTP].[step_name] AS [JobStartStepName]
    , [sJOB].[date_created] AS [JobCreatedOn]
    , [sJOB].[date_modified] AS [JobLastModifiedOn]
  , CASE [sJOB].[enabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [IsEnabled]
   
   , Last_Run = CONVERT(DATETIME, RTRIM(run_date) + ' '
        + STUFF(STUFF(REPLACE(STR(RTRIM(h.run_time),6,0),
        ' ','0'),3,0,':'),6,0,':'))
  , case [sJSTP].Last_run_outcome
          When 0 then 'Failed'
          when 1 then 'Succeeded'
          When 2 then 'Retry'
          When 3 then 'Canceled'
          When 5 then 'Unknown'
   End as Last_Run_Status

  ,Last_Run_Duration_HHMMSS = STUFF(STUFF(REPLACE(STR([sJSTP].last_run_duration,7,0),
        ' ','0'),4,0,':'),7,0,':')
    , Max_Duration = STUFF(STUFF(REPLACE(STR(l.run_duration,7,0),
        ' ','0'),4,0,':'),7,0,':')
  , Next_Run= CONVERT(DATETIME, RTRIM(NULLIF([sJOBSCH].next_run_date, 0)) + ' '
        + STUFF(STUFF(REPLACE(STR(RTRIM([sJOBSCH].next_run_time),6,0),
        ' ','0'),3,0,':'),6,0,':'))

    , [sSVR].[name] AS [OriginatingServerName]


FROM
    [msdb].[dbo].[sysjobs] AS [sJOB]
    LEFT JOIN [msdb].[sys].[servers] AS [sSVR]
        ON [sJOB].[originating_server_id] = [sSVR].[server_id]
    LEFT JOIN [msdb].[dbo].[syscategories] AS [sCAT]
        ON [sJOB].[category_id] = [sCAT].[category_id]
    LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sJSTP]
        ON [sJOB].[job_id] = [sJSTP].[job_id]
        AND [sJOB].[start_step_id] = [sJSTP].[step_id]
    LEFT JOIN [msdb].[sys].[database_principals] AS [sDBP]
        ON [sJOB].[owner_sid] = [sDBP].[sid]
    LEFT JOIN [msdb].[dbo].[sysjobschedules] AS [sJOBSCH]
        ON [sJOB].[job_id] = [sJOBSCH].[job_id]
    LEFT JOIN [msdb].[dbo].[sysschedules] AS [sSCH]
        ON [sJOBSCH].[schedule_id] = [sSCH].[schedule_id]

        left JOIN
    (
        SELECT job_id, instance_id = MAX(instance_id),max(run_duration) AS run_duration
            FROM msdb.dbo.sysjobhistory
            GROUP BY job_id
    ) AS l
    ON sJOB.job_id = l.job_id
left JOIN
    msdb.dbo.sysjobhistory AS h
    ON h.job_id = l.job_id
    AND h.instance_id = l.instance_id
Where [sJOB].[name] like 'SNAPSHOT%'     
ORDER BY [JobName]

--====================================================================
-- T-sql script to find SQL Agent Jobs without Notification Operator Configured

USE [msdb]
GO
 
SET NOCOUNT ON;
 
SELECT 'SQL Agent job(s) without notification operator found:' AS [Message]
 
SELECT j.[name] AS [JobName], j.[notify_level_email]
FROM [dbo].[sysjobs] j
LEFT JOIN [dbo].[sysoperators] o ON (j.[notify_email_operator_id] = o.[id])
WHERE j.[enabled] = 1
    AND j.[notify_level_email] IN (1)
    AND j.[notify_level_email] not IN (1,2,3)
	and j.name like '%Snapshot%'
GO