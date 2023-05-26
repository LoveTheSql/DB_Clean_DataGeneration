CREATE TABLE [dbo].[CleaningTriggers] (
    [ID]                 INT           IDENTITY (1, 1) NOT NULL,
    [TriggerDisableTsql] VARCHAR (700) NULL,
    [TriggerEnableTsql]  VARCHAR (700) NULL,
    CONSTRAINT [PK_CleaningTriggers] PRIMARY KEY CLUSTERED ([ID] ASC)
);

