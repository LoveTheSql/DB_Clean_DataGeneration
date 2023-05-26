
CREATE   PROCEDURE [dbo].[PostCleaning]
AS
BEGIN
	DECLARE @tSql varchar(max);
	DECLARE @iCount int = 0;
	DECLARE @isActive bit = 0;
	DECLARE @ParentAuditKey int;
	DECLARE @PkgGUID uniqueidentifier;

	SELECT @PkgGUID = NEWID();
	SELECT @iCount = MAX(ID) FROM dbo.PostCleaningCustomCode;

	INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
	VALUES (1, 'DATA CLEANING: PostClean-Start','POST CLEANING: PostClean-Start', @PkgGUID, getutcdate(), 'P');
	SELECT @ParentAuditKey = SCOPE_IDENTITY();
	UPDATE dbo.DimAudit  SET ParentAuditKey = @ParentAuditKey WHERE AuditKey = @ParentAuditKey;

	WHILE @iCount > 0
		BEGIN
			SELECT  @isActive = isActive, 
					@tSql = Tsql
			FROM	dbo.PostCleaningCustomCode
			WHERE	ID = @iCount;

			BEGIN TRY
				EXEC(@tSql);
			END TRY
			BEGIN CATCH
				PRINT @tSql;
				INSERT INTO dbo.DimAudit ( [ParentAuditKey], [TableName], [PkgName], [PkgGUID], [ExecStartDT], [SuccessfulProcessingInd])
				VALUES (@ParentAuditKey, 'DATA CLEANING: PostClean-Step',CONVERT(varchar(12),@iCount), @PkgGUID, getutcdate(), 'N');
			END CATCH;

			SELECT @iCount= @iCount-1, @isActive=0, @tSql=''
		END

		-- Success / Failure Actions
		IF ((SELECT COUNT(*) FROM dbo.DimAudit WHERE ParentAuditKey=@ParentAuditKey AND SuccessfulProcessingInd='N')=0)
		BEGIN
			UPDATE dbo.DimAudit  
			SET ExecStopDT = getutcdate(),SuccessfulProcessingInd = 'Y' 
			WHERE	(AuditKey = @ParentAuditKey );
			-- ELSE send email with Failed Steps table
		END
		ELSE
		BEGIN
			UPDATE dbo.DimAudit  
			SET ExecStopDT = getutcdate(),SuccessfulProcessingInd = 'N' 
			WHERE	(AuditKey = @ParentAuditKey );
		END

END
