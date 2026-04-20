USE [msdb]
GO

/****** Object:  Job [(DBA) - Optimisation]    Script Date: 4/20/2026 3:49:15 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/20/2026 3:49:15 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(DBA) - Optimisation', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [(DBA) - Indexes]    Script Date: 4/20/2026 3:49:15 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'(DBA) - Indexes', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @Counter TINYINT,
		@DBName SYSNAME

DECLARE @Databases TABLE
(
ID TINYINT IDENTITY(1,1),
Name SYSNAME
)

INSERT INTO @Databases
SELECT name
FROM sys.databases
ORDER BY Name;

SET @Counter = 1

WHILE EXISTS (SELECT 1 FROM @Databases WHERE ID = @Counter)
	BEGIN
		SELECT @DBName = Name FROM @Databases WHERE ID = @Counter

		EXEC [dbo].[UspDatabaseOptimise] @DBName = @DBName, @RetentionWeeks = -5, @ReassessDay = 0, @LimitProcessing = NULL, @BulkRecovery = 0, @SortOrder = ''DESC'', @RebuildHeap = 0, @Debug = 0

		SET @Counter = @Counter + 1
	END
GO', 
		@database_name=N'DBA', 
		@output_file_name=N'D:\SQLReports\(DBA) - Optimisation - Indexes ($(ESCAPE_SQUOTE(STRTDT))).txt', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [(DBA) - Statistics]    Script Date: 4/20/2026 3:49:15 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'(DBA) - Statistics', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @Counter TINYINT,
		@DBName SYSNAME

DECLARE @Databases TABLE
(
ID TINYINT IDENTITY(1,1),
Name SYSNAME
)

INSERT INTO @Databases
SELECT name
FROM sys.databases
ORDER BY Name;

SET @Counter = 1

WHILE EXISTS (SELECT 1 FROM @Databases WHERE ID = @Counter)
	BEGIN
		SELECT @DBName = Name FROM @Databases WHERE ID = @Counter

		EXEC [dbo].[UspDatabaseOptimiseStatistics] @DBName = @DBName, @StatisticAgeHours = 0, @SampleValue = NULL, @PrintCommandOnly = 0

		SET @Counter = @Counter + 1
	END
GO', 
		@database_name=N'DBA', 
		@output_file_name=N'D:\SQLReports\(DBA) - Optimisation - Statistics ($(ESCAPE_SQUOTE(STRTDT))).txt', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(DBA) - Index Optimisation', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=127, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20130620, 
		@active_end_date=99991231, 
		@active_start_time=60500, 
		@active_end_time=235959, 
		@schedule_uid=N'1267cc99-2291-40dc-beb5-5ba3ce7bc9eb'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


