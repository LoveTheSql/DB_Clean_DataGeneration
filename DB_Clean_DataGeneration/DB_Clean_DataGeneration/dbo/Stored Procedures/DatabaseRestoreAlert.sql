-- =============================================
-- Author:		David Speight
-- Create date: 20230516
-- =============================================
CREATE   PROCEDURE [dbo].[DatabaseRestoreAlert] 
@E_profile_name nvarchar(250),
@E_recipients nvarchar(2000),
@DayLimit int = 7
AS
BEGIN
	-- This will email the Daily Audit Report
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

		declare @body1 nvarchar(max);
				declare @bodyFIN nvarchar(max);
		DECLARE @StyleSheet VARCHAR(1000);
		DECLARE @Header VARCHAR(400);
		DECLARE @GreenTitle VARCHAR(250);
		DECLARE @ServerResolvedName VARCHAR(250);


		SELECT @StyleSheet = 
'<style><!--
@font-face
	{font-family:"Microsoft Sans Serif";
	panose-1:2 11 6 4 2 2 2 2 2 4;}
p.MsoNormal, li.MsoNormal, div.MsoNormal
	{margin:0in;
	font-size:11.0pt;
	font-family:"Calibri",sans-serif;}
--></style>',
				@Header = CONCAT('<p class="MsoNormal" style="background:white"><span style="font-size:16pt;color:#009A44;letter-spacing:-1.0pt">COVENT</span><span style="font-size:16pt;color:#0C2340">BRIDGE GROUP</span></p><BR /><span style="font-size:16pt;color:#0C2340"><p><span style="font-size:16pt;color:#0C2340">QA/DEV DATABASE RESTORE ALERT ON ',CONVERT(varchar(12),getdate()),' </span></p>'),
				@GreenTitle = '<p class="MsoNormal" style="background:white"><span style="font-size:16.0pt;font-family:&amp;quot;color:#009A44;letter-spacing:-1.0pt">'
;
	WITH LastRestores AS(SELECT DatabaseName = [d].[name] ,  r.*, 
	RowNum = ROW_NUMBER() OVER (PARTITION BY d.Name ORDER BY r.[restore_date] DESC)
	FROM master.sys.databases d
	LEFT OUTER JOIN msdb.dbo.[restorehistory] r ON r.[destination_database_name] = d.Name)

	SELECT @body1 = cast( (
		select td = CONCAT(d.DatabaseName,'</td><td>',CONVERT(varchar(50),d.restore_date),'</td><td>',convert(varchar(50),d.AgedDays) )
		from (

					SELECT DatabaseName, restore_date, CONVERT(varchar(8),datediff(day,restore_date,getutcdate())) AS AgedDays
					FROM [LastRestores]
					WHERE [RowNum] = 1
					and datediff(day,restore_date,getutcdate()) > @DayLimit
					and DatabaseName in (	SELECT DatabaseName 
											FROM DB_Clean_DataGeneration.dbo.Validator 
											WHERE ObjectTypeName = 'database' and isactive=1 and status='parent'
					)	
				) as d
		for xml path( 'tr' ), type ) as varchar(max) )
		SELECT @body1 = (CASE WHEN len(@body1) IS NULL THEN '' ELSE		
						(CONCAT('<table cellpadding="2" cellspacing="2" border="0"><tr><th style="background:#009A44">Database</th><th style="background:#009A44">Restore Date</th><th style="background:#009A44">Aged Days</th></tr>'
					, replace( replace( @body1, '&lt;', '<' ), '&gt;', '>' )
					, '</table>')) END);
		SELECT @body1 = LEFT(@body1,40000) -- Limit to 40 of the 64k

		SELECT @bodyFIN = CONCAT( @StyleSheet,@Header,'<BR />',@GreenTitle,'AGED DATABASE RESTORE</span></p><BR />', @body1);

		IF (LEN(@bodyFIN) > 10) and (@E_profile_name is not null) and (@E_recipients is not null)
		BEGIN
			DECLARE @SubjectTxt   VARCHAR(50);
			SELECT @SubjectTxt   = 'ALERT: Aged Database Restore';
			EXEC msdb.dbo.sp_send_dbmail
				@profile_name = @E_profile_name,
				@recipients = @E_recipients,
				@body = @bodyFIN,
				@subject = @SubjectTxt,
				@body_format = 'HTML'; 
		END;
END
