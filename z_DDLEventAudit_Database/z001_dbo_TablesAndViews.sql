--
-- BEGIN FILE :: z001_dbo_TablesAndViews.sql 
--
USE [z_DDLEventAudit] 
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
--
-- 1. Main table to log/store all DDL Events executed on server/instance.
--
CREATE TABLE [dbo].[DDLEvent](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[LogTimestamp] [datetime] NOT NULL,
	[EventXML] [xml] NULL,
	[EventType] [nvarchar](100) NULL,
	[TSQLCommand] [nvarchar](max) NULL,
	[DatabaseName] [nvarchar](255) NULL,
	[SchemaName] [nvarchar](255) NULL,
	[ObjectName] [nvarchar](255) NULL,
	[UserName] [nvarchar](255) NULL,
	[HostName] [nvarchar](255) NULL,
	[ProgramName] [nvarchar](255) NULL,
 CONSTRAINT [PK_DDLEvent] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 
GO 
CREATE NONCLUSTERED INDEX [IX_DDLEvent_DatabaseSchemaObject] ON [dbo].[DDLEvent]
(
	[DatabaseName] ASC,
	[SchemaName] ASC,
	[ObjectName] ASC
)
GO
CREATE NONCLUSTERED INDEX [IX_DDLEvent_EventType] ON [dbo].[DDLEvent]
(
	[EventType] ASC
)
GO
CREATE NONCLUSTERED INDEX [IX_DDLEvent_UserHostProgram] ON [dbo].[DDLEvent]
(
	[UserName] ASC,
	[HostName] ASC,
	[ProgramName] ASC
)
GO
ALTER TABLE [dbo].[DDLEvent] ADD  CONSTRAINT [DF_DDLEvent_LogTimestamp]  DEFAULT (getdate()) FOR [LogTimestamp]
GO
--
--
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--
--
	CREATE TRIGGER [dbo].[TG_DDLEvent_UpdateDelete] ON [dbo].[DDLEvent]  
	INSTEAD OF UPDATE, DELETE	
	AS	
		SET NOCOUNT ON ; 
	
		BEGIN TRY 
			--
			PRINT 'Table trigger dbo.TG_DDLEvent_UpdateDelete on dbo.DDLEvent prevents update or delete statements from running.'
			--
		END TRY 
		BEGIN CATCH 
			IF 1 = 0 
			BEGIN 
				PRINT 'Failed to print.' 
			END		
		END CATCH	

GO
ALTER TABLE [dbo].[DDLEvent] ENABLE TRIGGER [TG_DDLEvent_UpdateDelete]
GO
--
-- 2. Corresponding view for main DDL Event log table.
--
USE [z_DDLEventAudit]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vw_DDLEvent]	
AS  
/**************************************************************************************

	Displays DDLEvent records. 

	The [ID] and [EventXML] fields are excluded intentionally. 

		
		Example:	


			SELECT  TOP 1000  X.*
			FROM		dbo.vw_DDLEvent  X		
			ORDER BY	X.LogTimestamp  DESC 
			;	


	Date			Action	
	----------		----------------------------
	2018-10-08		Created initial version.	

**************************************************************************************/	


	SELECT		X.LogTimestamp		
	--
	,			X.EventType 
	--	
	,			X.DatabaseName 
	,			X.SchemaName 
	,			X.ObjectName	
	--
	,			X.UserName 
	,			X.HostName	
	,			X.ProgramName	
	--	
	--
	,			X.TSQLCommand 
	--	
	--
	FROM		dbo.DDLEvent	X	WITH(NOLOCK)	
	--	
	;	
	

GO
--
-- 3. Table to store summary information from "purged" records (related to record-purging stored procedure executions).
--
USE [z_DDLEventAudit]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DDLEvent_PurgedRecordSummary](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[PurgedTimestamp] [datetime] NOT NULL,
	[EventDate] [date] NOT NULL,
	[EventType] [nvarchar](100) NULL,
	[DatabaseName] [nvarchar](255) NULL,
	[UserName] [nvarchar](255) NULL,
	[HostName] [nvarchar](255) NULL,
	[PurgedRecordCount] [int] NOT NULL,
 CONSTRAINT [PK_DDLEvent_PurgedRecordSummary] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 
GO 
CREATE NONCLUSTERED INDEX [IX_DDLEvent_PurgedRecordSummary_EventDate] ON [dbo].[DDLEvent_PurgedRecordSummary]
(
	[EventDate] ASC
)
GO
CREATE NONCLUSTERED INDEX [IX_DDLEvent_PurgedRecordSummary_EventTypeAndDatabaseName] ON [dbo].[DDLEvent_PurgedRecordSummary]
(
	[EventType] ASC,
	[DatabaseName] ASC
)
GO
CREATE NONCLUSTERED INDEX [IX_DDLEvent_PurgedRecordSummary_PurgedTimestamp] ON [dbo].[DDLEvent_PurgedRecordSummary]
(
	[PurgedTimestamp] ASC
)
GO
CREATE NONCLUSTERED INDEX [IX_DDLEvent_PurgedRecordSummary_UserNameAndHostName] ON [dbo].[DDLEvent_PurgedRecordSummary]
(
	[UserName] ASC,
	[HostName] ASC
)
GO
ALTER TABLE [dbo].[DDLEvent_PurgedRecordSummary] ADD  CONSTRAINT [DF_DDLEvent_PurgedRecordSummary_PurgedTimestamp]  DEFAULT (getdate()) FOR [PurgedTimestamp]
GO
--
--
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--
--
	CREATE TRIGGER [dbo].[TG_DDLEvent_PurgedRecordSummary_UpdateDelete] ON [dbo].[DDLEvent_PurgedRecordSummary]  
	INSTEAD OF UPDATE, DELETE	
	AS	
		SET NOCOUNT ON ; 

		BEGIN TRY 
			--
			PRINT 'Table trigger dbo.TG_DDLEvent_PurgedRecordSummary_UpdateDelete on dbo.DDLEvent_PurgedRecordSummary prevents update or delete statements from running.'
			--
		END TRY 
		BEGIN CATCH 
			IF 1 = 0 
			BEGIN 
				PRINT 'Failed to print.' 
			END		
		END CATCH	

GO
ALTER TABLE [dbo].[DDLEvent_PurgedRecordSummary] ENABLE TRIGGER [TG_DDLEvent_PurgedRecordSummary_UpdateDelete]
GO
--
-- 4. Corresponding view for "purged" DDL Event record-summary table.
--
USE [z_DDLEventAudit]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vw_DDLEvent_PurgedRecordSummary]	
AS  
/**************************************************************************************

	Displays DDLEvent_PurgedRecordSummary records. 
	
	The [ID] field is excluded intentionally. 

		
		Example:	


			SELECT  TOP 1000  X.*
			FROM		dbo.vw_DDLEvent_PurgedRecordSummary  X		
			ORDER BY	X.PurgedTimestamp  DESC 
			;	


	Date			Action	
	----------		----------------------------
	2020-08-31		Created initial version.	

**************************************************************************************/	


	SELECT		X.PurgedTimestamp 
	,			X.EventDate 
	,			X.EventType 
	,			X.DatabaseName 
	,			X.UserName 
	,			X.HostName 
	,			X.PurgedRecordCount
	--
	FROM		dbo.DDLEvent_PurgedRecordSummary  X  WITH(NOLOCK)  
	--	
	;	
	

GO
--
-- END FILE :: z001_dbo_TablesAndViews.sql 
--