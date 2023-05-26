CREATE TABLE [dbo].[CleaningVerificationSample] (
    [ID]                 INT            IDENTITY (1, 1) NOT NULL,
    [CleaningColumnID]   INT            NULL,
    [OriginalSampleData] NVARCHAR (500) NULL,
    [ChangedSampleData]  NVARCHAR (500) NULL,
    [RowID]              INT            NULL,
    [Pass]               BIT            NULL,
    CONSTRAINT [PK_CleaningVerificationSample] PRIMARY KEY CLUSTERED ([ID] ASC)
);

