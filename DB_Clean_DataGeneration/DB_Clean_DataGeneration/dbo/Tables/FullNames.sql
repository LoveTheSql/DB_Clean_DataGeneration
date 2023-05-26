CREATE TABLE [dbo].[FullNames] (
    [ID]     INT          IDENTITY (1, 1) NOT NULL,
    [Fname]  VARCHAR (50) NULL,
    [Lname]  VARCHAR (50) NULL,
    [Gender] VARCHAR (10) NULL,
    CONSTRAINT [PK_FullNames] PRIMARY KEY CLUSTERED ([ID] ASC)
);

