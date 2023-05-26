CREATE TABLE [dbo].[DimAudit] (
    [AuditKey]                INT              IDENTITY (1, 1) NOT NULL,
    [ParentAuditKey]          INT              NOT NULL,
    [TableName]               VARCHAR (50)     CONSTRAINT [DF__DimAudit__TableName] DEFAULT ('Unknown') NOT NULL,
    [PkgName]                 VARCHAR (50)     CONSTRAINT [DF__DimAudit__PkgName] DEFAULT ('Unknown') NOT NULL,
    [PkgGUID]                 UNIQUEIDENTIFIER NULL,
    [PkgVersionGUID]          UNIQUEIDENTIFIER NULL,
    [PkgVersionMajor]         SMALLINT         NULL,
    [PkgVersionMinor]         SMALLINT         NULL,
    [ExecStartDT]             DATETIME         CONSTRAINT [DF__DimAudit__ExecStartDT] DEFAULT (getdate()) NOT NULL,
    [ExecStopDT]              DATETIME         NULL,
    [ExecutionInstanceGUID]   UNIQUEIDENTIFIER NULL,
    [ExtractRowCnt]           BIGINT           NULL,
    [InsertRowCnt]            BIGINT           NULL,
    [UpdateRowCnt]            BIGINT           NULL,
    [ErrorRowCnt]             BIGINT           NULL,
    [TableInitialRowCnt]      BIGINT           NULL,
    [TableFinalRowCnt]        BIGINT           NULL,
    [TableMaxDateTime]        DATETIME         NULL,
    [SuccessfulProcessingInd] CHAR (1)         CONSTRAINT [DF__DimAudit__Success] DEFAULT ('N') NOT NULL,
    CONSTRAINT [PK_dbo.DimAudit] PRIMARY KEY CLUSTERED ([AuditKey] ASC),
    CONSTRAINT [FK_dbo_DimAudit_ParentAuditKey] FOREIGN KEY ([ParentAuditKey]) REFERENCES [dbo].[DimAudit] ([AuditKey])
);

