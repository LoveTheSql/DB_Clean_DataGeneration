CREATE TABLE [dbo].[MaleNames] (
    [ID]        INT          IDENTITY (1, 1) NOT NULL,
    [FirstName] VARCHAR (50) NULL,
    [LastName]  VARCHAR (50) NULL,
    CONSTRAINT [PK_MaleNames] PRIMARY KEY CLUSTERED ([ID] ASC)
);

