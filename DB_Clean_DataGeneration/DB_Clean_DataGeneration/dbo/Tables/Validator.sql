CREATE TABLE [dbo].[Validator] (
    [ID]                INT           IDENTITY (1, 1) NOT NULL,
    [DatabaseName]      VARCHAR (250) NULL,
    [SchemaName]        VARCHAR (150) NULL,
    [TableName]         VARCHAR (250) NULL,
    [ColumnName]        VARCHAR (250) NULL,
    [ObjectTypeName]    VARCHAR (50)  NULL,
    [Status]            VARCHAR (50)  NULL,
    [DataType]          VARCHAR (50)  NULL,
    [GeneratorDataType] VARCHAR (50)  NULL,
    [IsActive]          BIT           NULL,
    [dtCreated]         DATETIME      NULL,
    [dtLastModified]    DATETIME      NULL,
    CONSTRAINT [PK_Validator] PRIMARY KEY CLUSTERED ([ID] ASC)
);

