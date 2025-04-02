
DECLARE @SourceServer sysname
DECLARE @ScriptPath nvarchar(max)
DECLARE @ProxyName sysname

SET @SourceServer = 'MyServer\MyInstance'  -- The SQL Server instance name to be monitored
SET @ScriptPath = 'D:\PerformanceStore'    -- The directory where the PowerShell scripts are located
SET @ProxyName = 'PerformanceStore'        -- The name of the SQL Server Agent Proxy

DECLARE @JobCategory nvarchar(max)
DECLARE @JobOwner nvarchar(max)

DECLARE @JobNameExtendedEvents nvarchar(max)
DECLARE @JobNameSessions nvarchar(max)
DECLARE @JobNameStatistics nvarchar(max)
DECLARE @JobNameDataPurge nvarchar(max)

DECLARE @JobCommandExtendedEvents nvarchar(max)
DECLARE @JobCommandSessions nvarchar(max)
DECLARE @JobCommandStatistics nvarchar(max)
DECLARE @JobCommandDataPurge nvarchar(max)

DECLARE @ScheduleNameStatistics nvarchar(max)
DECLARE @ScheduleNameExtendedEvents nvarchar(max)
DECLARE @ScheduleNameSessions nvarchar(max)
DECLARE @ScheduleNameDataPurge nvarchar(max)

SET @JobCategory = 'PerformanceStore'
SET @JobOwner = SUSER_SNAME(0x01)

SET @JobNameExtendedEvents = 'PerformanceStore - ExtendedEvents - ' + @SourceServer
SET @JobCommandExtendedEvents = 'powershell ' + @ScriptPath + IIF(RIGHT(@ScriptPath,1) = '\','','\') + 'ExtendedEvents_Init.ps1' + ' -SourceServer """' + @SourceServer + '"""'
SET @ScheduleNameExtendedEvents = 'PerformanceStore - ExtendedEvents'

SET @JobNameSessions = 'PerformanceStore - Sessions - ' + @SourceServer
SET @JobCommandSessions = 'powershell ' + @ScriptPath + IIF(RIGHT(@ScriptPath,1) = '\','','\') + 'Sessions_Init.ps1' + ' -SourceServer """' + @SourceServer + '"""'
SET @ScheduleNameSessions = 'PerformanceStore - Sessions'

SET @JobNameStatistics = 'PerformanceStore - Statistics - ' + @SourceServer
SET @JobCommandStatistics = 'powershell ' + @ScriptPath + IIF(RIGHT(@ScriptPath,1) = '\','','\') + 'Statistics_Init.ps1' + ' -SourceServer """' + @SourceServer + '"""'
SET @ScheduleNameStatistics = 'PerformanceStore - Statistics'

SET @JobNameDataPurge = 'PerformanceStore - DataPurge'
SET @JobCommandDataPurge = 'powershell ' + @ScriptPath + IIF(RIGHT(@ScriptPath,1) = '\','','\') + 'DataPurge_Init.ps1'
SET @ScheduleNameDataPurge = 'PerformanceStore - DataPurge'

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysproxies WHERE name = @ProxyName)
BEGIN
  RAISERROR ('The specified Proxy does not exist.', 16, 1)
  RETURN
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.syscategories WHERE name = @JobCategory)
BEGIN
  EXECUTE msdb.dbo.sp_add_category @class = 'JOB', @type= 'LOCAL', @name = @JobCategory 
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @ScheduleNameExtendedEvents)
BEGIN
  EXECUTE msdb.dbo.sp_add_schedule @schedule_name = @ScheduleNameExtendedEvents, @enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=2, @freq_subday_interval=30, @freq_relative_interval=0, @freq_recurrence_factor=0, @active_start_time=10, @active_end_time=235959
END
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameExtendedEvents)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobNameExtendedEvents, @category_name = @JobCategory, @owner_login_name = @JobOwner
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobNameExtendedEvents, @step_name = @JobNameExtendedEvents, @subsystem = 'CMDEXEC', @command = @JobCommandExtendedEvents, @proxy_name = @ProxyName
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobNameExtendedEvents
  EXECUTE msdb.dbo.sp_attach_schedule @job_name = @JobNameExtendedEvents,  @schedule_name = @ScheduleNameExtendedEvents
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @ScheduleNameSessions)
BEGIN
  EXECUTE msdb.dbo.sp_add_schedule @schedule_name = @ScheduleNameSessions, @enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=2, @freq_subday_interval=30, @freq_relative_interval=0, @freq_recurrence_factor=0, @active_start_time=20, @active_end_time=235959
END
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameSessions)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobNameSessions, @category_name = @JobCategory, @owner_login_name = @JobOwner
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobNameSessions, @step_name = @JobNameSessions, @subsystem = 'CMDEXEC', @command = @JobCommandSessions, @proxy_name = @ProxyName
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobNameSessions
  EXECUTE msdb.dbo.sp_attach_schedule @job_name = @JobNameSessions,  @schedule_name = @ScheduleNameSessions
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @ScheduleNameStatistics)
BEGIN
  EXECUTE msdb.dbo.sp_add_schedule @schedule_name = @ScheduleNameStatistics, @enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=8, @freq_subday_interval=1, @freq_relative_interval=0, @freq_recurrence_factor=0, @active_start_date=20131207, @active_end_date=99991231, @active_start_time=0, @active_end_time=235959
END
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameStatistics)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobNameStatistics, @category_name = @JobCategory, @owner_login_name = @JobOwner
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobNameStatistics, @step_name = @JobNameStatistics, @subsystem = 'CMDEXEC', @command = @JobCommandStatistics, @proxy_name = @ProxyName
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobNameStatistics
  EXECUTE msdb.dbo.sp_attach_schedule @job_name = @JobNameStatistics,  @schedule_name = @ScheduleNameStatistics
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @ScheduleNameDataPurge)
BEGIN
  EXECUTE msdb.dbo.sp_add_schedule @schedule_name = @ScheduleNameDataPurge, @enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @freq_subday_interval=1, @freq_relative_interval=0, @freq_recurrence_factor=0, @active_start_time=0, @active_end_time=235959
END
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameDataPurge)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobNameDataPurge, @category_name = @JobCategory, @owner_login_name = @JobOwner
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobNameDataPurge, @step_name = @JobNameDataPurge, @subsystem = 'CMDEXEC', @command = @JobCommandDataPurge, @proxy_name = @ProxyName
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobNameDataPurge
  EXECUTE msdb.dbo.sp_attach_schedule @job_name = @JobNameDataPurge,  @schedule_name = @ScheduleNameDataPurge
END
