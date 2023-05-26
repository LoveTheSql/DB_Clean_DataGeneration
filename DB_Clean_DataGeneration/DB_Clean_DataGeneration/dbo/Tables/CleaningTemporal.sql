CREATE TABLE [dbo].[CleaningTemporal] (
    [ID]               INT           IDENTITY (1, 1) NOT NULL,
    [DatabaseName]     VARCHAR (200) NULL,
    [TableSchema]      VARCHAR (50)  NULL,
    [TableName]        VARCHAR (200) NULL,
    [HistorySchema]    VARCHAR (50)  NULL,
    [HistoryTableName] VARCHAR (200) NULL,
    [IsActive]         BIT           NOT NULL,
    CONSTRAINT [PK_CleaningTemporal] PRIMARY KEY CLUSTERED ([ID] ASC)
);

