CREATE TABLE [dbo].[CleaningColumns] (
    [ID]                  INT           IDENTITY (1, 1) NOT NULL,
    [DatabaseName]        VARCHAR (200) NULL,
    [SchemaName]          VARCHAR (50)  NULL,
    [TableName]           VARCHAR (200) NULL,
    [ColumnName]          VARCHAR (200) NULL,
    [GenderRefColumnName] VARCHAR (200) NULL,
    [IDColumnName]        VARCHAR (200) NULL,
    [DataType]            VARCHAR (50)  NULL,
    [IsActive]            BIT           NOT NULL,
    [UsesGenerationDb]    BIT           NOT NULL,
    CONSTRAINT [PK_CleaningColumns] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Unique_ColumnCombo]
    ON [dbo].[CleaningColumns]([DatabaseName] ASC, [SchemaName] ASC, [TableName] ASC, [ColumnName] ASC);

