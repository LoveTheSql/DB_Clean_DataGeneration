CREATE TABLE [dbo].[FemaleNames] (
    [ID]        INT          IDENTITY (1, 1) NOT NULL,
    [FirstName] VARCHAR (50) NULL,
    [LastName]  VARCHAR (50) NULL,
    CONSTRAINT [PK_FemaleNames] PRIMARY KEY CLUSTERED ([ID] ASC)
);

