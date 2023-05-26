CREATE TABLE [dbo].[PostCleaningCustomCode] (
    [ID]        INT           IDENTITY (1, 1) NOT NULL,
    [IsActive]  BIT           NULL,
    [dtCreated] DATETIME      NULL,
    [Tsql]      VARCHAR (MAX) NULL,
    [Notes]     VARCHAR (MAX) NULL,
    CONSTRAINT [PK_PostCleaningCustomCode] PRIMARY KEY CLUSTERED ([ID] ASC)
);

