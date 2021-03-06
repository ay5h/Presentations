--##############################################################
--# Supercharge your Reporting Services - An essential toolkit #
--# @cporteous | craigporteous.com | github.com/cporteou       #
--##############################################################

USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Failed SSRS Subscriptions', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sqladmin', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Failed SSRS Subscriptions', @server_name = N'SSRSTOOLKIT'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'Failed SSRS Subscriptions', @step_name=N'Check Subscription data', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE ReportServer
 
DECLARE @count INT
 
SELECT
   	Cat.[Name],
   	Rep.[ScheduleId],
   	Own.[UserName],
   	ISNULL(REPLACE(Sub.[Description],''Send e-mail to '',''''),'' '') AS Recipients,
   	Sub.[LastStatus],
   	Cat.[Path],
	''<a href="http://ssrstoolkit/Reports/Pages/Report.aspx?ItemPath='' + Cat.[Path] + ''">'' + Cat.[Path] + ''</a>'' as [LinkedPath],
   	Sub.[LastRunTime]
INTO
   	#tFailedSubs
FROM
   	dbo.[Subscriptions] Sub
INNER JOIN
   	dbo.[Catalog] Cat on Sub.[Report_OID] = Cat.[ItemID]
INNER JOIN
   	dbo.[ReportSchedule] Rep ON (cat.[ItemID] = Rep.[ReportID] 
	   and Sub.[SubscriptionID] =Rep.[SubscriptionID])
INNER JOIN
   	dbo.[Users] Own on Sub.[OwnerID] = Own.[UserID]
WHERE
Sub.[LastStatus] NOT LIKE ''%was written%'' --File Share subscription
AND Sub.[LastStatus] NOT LIKE ''%pending%'' --Subscription in progress. No result yet
AND Sub.[LastStatus] NOT LIKE ''%mail sent%'' --Mail sent successfully.
AND Sub.[LastStatus] NOT LIKE ''%New Subscription%'' --New Sub. Not been executed yet
AND Sub.[LastStatus] NOT LIKE ''%been saved%'' --File Share subscription
AND Sub.[LastStatus] NOT LIKE ''% 0 errors.'' --Data Driven subscription
AND Sub.[LastStatus] NOT LIKE ''%succeeded%'' --Success! Used in cache refreshes
AND Sub.[LastStatus] NOT LIKE ''%successfully saved%'' --File Share subscription
AND Sub.[LastStatus] NOT LIKE ''%New Cache%'' --New cache refresh plan
-- AND Sub.[LastRunTime] > GETDATE()-1

-- If any failed subscriptions found, proceed to build HTML & send mail.
SELECT @count = COUNT(*) FROM #tFailedSubs
 
IF (@count>0) 
   	BEGIN
 
   	DECLARE @EmailRecipient NVARCHAR(1000)
   	DECLARE @SubjectText NVARCHAR(1000)
   	DECLARE @ProfileName NVARCHAR(1000)
   	DECLARE @tableHTML1 NVARCHAR(MAX)
   	DECLARE @tableHTMLAll NVARCHAR(MAX)
 
   	SET NOCOUNT ON
   	
   	SELECT @EmailRecipient = ''Changeme@craigporteous.com''
   	SET @SubjectText = ''Failed SSRS Subscriptions''
 
   	--Set DB Mail profile to use
   	SELECT TOP 1 @ProfileName = [Name] FROM msdb.dbo.sysmail_profile WHERE [Name] = ''Alert-BI-Admins''
   	
   	SET @tableHTML1 =
 
         	N''<H3 style="color:red; font-family:verdana">Failed SSRS Subscription details. Please resolve & re-run jobs</H3>'' +
         	N''<p align="left" style="font-family:verdana; font-size:8pt"></p>'' +
         	N''<table border="2" style="font-size:8pt; font-family:verdana; text-align:left">'' +
         	N''<tr style="color:black; font-weight:bold">'' +
         	N''<th>Report Name</th><th>SQL Agent Job ID</th><th>Owner Username</th><th>Distribution</th><th>Error Message</th><th>Report Location</th><th>Last Run Time</th></tr>'' +
         	CAST((
                	SELECT
                       	td = t.[Name],'''',
                       	td = t.[ScheduleId],'''',
                       	td = t.[UserName],'''',
                       	td = t.[Recipients],'''',
                       	td = t.[LastStatus],'''',
                       	td = t.[Path],'''',
                	   	td = t.[LastRunTime]
                	FROM
                       	#tFailedSubs t
                	FOR XML PATH(''tr''), TYPE)
         	AS NVARCHAR(MAX) ) +
         	N''</table>''
 
SET @tableHTMLAll = ISNULL(@tableHTML1,'''')
 
IF @tableHTMLAll <> ''''   	
   	BEGIN
		EXEC msdb.dbo.sp_send_dbmail
				@profile_name = @ProfileName,
				@recipients = @EmailRecipient,
				@body = @tableHTMLAll,
				@body_format = ''HTML'',
				@subject = @SubjectText
   	END
 
SET NOCOUNT OFF 
DROP TABLE #tFailedSubs
 
END', 
		@database_name=N'ReportServer', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'Failed SSRS Subscriptions', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sqladmin', 
		@notify_email_operator_name=N'', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Failed SSRS Subscriptions', @name=N'Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190820, 
		@active_end_date=99991231, 
		@active_start_time=100000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
