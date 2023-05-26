CREATE TABLE [dbo].[ValidatorAlwaysIgnore] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [DatabaseName] VARCHAR (250) NULL,
    [SchemaName]   VARCHAR (150) NULL,
    [TableName]    VARCHAR (250) NULL,
    [ColumnName]   VARCHAR (250) NULL,
    [dtCreated]    DATETIME      NULL,
    CONSTRAINT [PK_ValidatorAlwaysIgnore] PRIMARY KEY CLUSTERED ([ID] ASC)
);

