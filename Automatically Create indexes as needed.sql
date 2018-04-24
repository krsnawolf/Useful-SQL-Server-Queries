/****** Object:  Job [INDEXING - Create Custom Indexes]    Script Date: 3/29/2018 9:15:12 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 3/29/2018 9:15:12 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'INDEXING - Create Custom Indexes', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job creates custom indexes for environments to optimize the database performance.  This script is designed to run only when there are performance issues and will add indexes to the database that the script shows as highly relevant.  This script does NOT remove current custom indexes.  You must run the remove custom indexes job to remove all custom indexes if you wish to re-optimize the database.

The script is set up to generate the best performance options based on the SQL Server DMV views.
schrist', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'[user name here]', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [CSPRD]    Script Date: 3/29/2018 9:15:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CSPRD', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'	  /* 2/22/2016 - steve christensen - added criteria to eliminate duplicating indexes.  This should avoid contention with indexes by eliminating the possibility of indexes with similar columns and include columns.)*/
	 /*12/2/2016 - added restriction to only consider queries with more than 10,000 user scans*/
	------------------------------------------------------
begin
	set nocount on
	Declare @cstmIndexes as nvarchar(max)
	create table #tbl (id [int] IDENTITY(1,1) NOT NULL,cstindex varchar(max),qstats int)
	set @cstmIndexes=''''
	-- schriste 12/4/2013:  script to create custom indexes that the system indicates it needs.  This is based on user table scans and updates to determine the best index options to use.  Limited to critical indexes based on the last time a user table scan occurred.
	insert into #tbl(cstindex,qstats)
	SELECT DISTINCT ''CREATE NONCLUSTERED INDEX '' + ''[CSTM_'' + CAST(q.index_handle AS VARCHAR(200)) + ''_CSTM] ON '' + q.[statement] + ''('' + ISNULL(q.equality_columns,'''') + case when (isnull(q.equality_columns,'''')='''' or isnull(q.inequality_columns,'''')='''') then '''' else '','' end + ISNULL(q.inequality_columns,'''') + '') '' +case when ISNULL(q.included_columns,'''') <> '''' then ''INCLUDE ('' + ISNULL(q.included_columns,'''') +'')'' else '''' end + '' WITH (SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY=OFF, DROP_EXISTING=OFF,ONLINE=OFF) ON [PRIMARY];'' as myindex,sum(q.user_scans)
	from (select distinct top 100 percent
		  b.index_handle
		  ,b.[statement]
		  ,ISNULL(b.[included_columns],'''') as [included_columns]
		  ,ISNULL(b.[inequality_columns],'''') as [inequality_columns]
		  ,ISNULL(b.[equality_columns],'''') as [equality_columns]
		  ,a.[user_scans],isnull([statement],'''')+ISNULL([included_columns],'''') +ISNULL([inequality_columns],'''')+ISNULL([equality_columns],'''') as natchexclude
	  FROM [sys].[dm_db_index_usage_stats] a right outer join [sys].[dm_db_missing_index_details] b on b.database_id=a.database_id and a.[object_id]=b.[object_id]
	  where  (user_scans>user_updates) and 
	  [statement] like ''%'' +DB_NAME() +''%'' order by user_scans desc) q 
	  
	  where q.index_handle in (	  select [indexid] from (
	  select distinct max(index_handle) as indexid
	  FROM [sys].[dm_db_missing_index_details]  group by isnull([statement],'''')+ISNULL([included_columns],'''') +ISNULL([inequality_columns],'''')+ISNULL([equality_columns],'''')) q
	  ) and ''UWS_'' + CAST(q.index_handle AS VARCHAR(200)) + ''_CSTM'' not in (select name from sys.indexes where name like ''UWS%CSTM'')
	  group by ''CREATE NONCLUSTERED INDEX '' + ''[UWS_'' + CAST(q.index_handle AS VARCHAR(200)) + ''_CSTM] ON '' + q.[statement] + ''('' + ISNULL(q.equality_columns,'''') + case when (isnull(q.equality_columns,'''')='''' or isnull(q.inequality_columns,'''')='''') then '''' else '','' end + ISNULL(q.inequality_columns,'''') + '') '' +case when ISNULL(q.included_columns,'''') <> '''' then ''INCLUDE ('' + ISNULL(q.included_columns,'''') +'')'' else '''' end + '' WITH (SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY=OFF, DROP_EXISTING=OFF,ONLINE=OFF) ON [PRIMARY];'' 
	  having sum(q.user_scans)>10000
	  order by sum(q.user_scans) desc

		begin
		while isnull((select COUNT(*) from #tbl),0)>0 
			begin
				select top 1 @cstmIndexes=cstindex from #tbl order by id
				--select @cstmIndexes
				delete top(1) from #tbl where id in (select top 1 id from #tbl order by id)
				exec sp_executesql @cstmIndexes
			end
		end
		drop table #tbl
		set nocount off
end', 
		@database_name=N'[database name]', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'proc custom indexes', 
		@enabled=0, 
		@freq_type=1, 
		@freq_interval=0, 
		@freq_subday_type=0, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20160322, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959, 
		@schedule_uid=N'65340d4f-9c94-4b29-9424-dc721fe44ceb'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


