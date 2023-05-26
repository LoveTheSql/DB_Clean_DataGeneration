CREATE TABLE [dbo].[CleaningDataType] (
    [ID]           INT            IDENTITY (1, 1) NOT NULL,
    [DataTypeName] VARCHAR (50)   NULL,
    [IsActive]     BIT            NULL,
    [IsPrefered]   BIT            NULL,
    [KeyWordList]  VARCHAR (3000) NULL,
    [IsInt]        BIT            NULL,
    CONSTRAINT [PK_CleaninDataType] PRIMARY KEY CLUSTERED ([ID] ASC)
);

