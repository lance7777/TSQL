--
-- BEGIN FILE :: z002_dbo_usp_Insert_DDLEvent.sql 
--
USE [z_DDLEventAudit]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_Insert_DDLEvent]  
	@EventXML		XML		=	null		
--
AS
/**************************************************************************************

	Inserts a [DDLEvent] record. 
	
	Referenced in server-level DDL trigger. 
	
	  Generally, non-"sysadmin" users should not have or need the ability to trigger DDL Events.
	  If this is unavoidable, create a "DDLUser" database role and grant them execution privileges for this procedure. 
	  
	  If the @EventXML parameter value is NULL, no action will occur. 
	  
	  A list of excluded/out-of-scope databases can be maintained within the related server-level DDL trigger. 


		
		Example:	


			EXEC	dbo.usp_Insert_DDLEvent		
					@EventXML	=	null		
			;	


	Date			Action	
	----------		----------------------------
	2018-10-08		Created initial version.	
	2020-08-31		Spruced up (cosmetically) for GITHUB post. 

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	DECLARE		@ErrorMessage		varchar(200)	
	,			@RowCount			int				
	--
	,			@UserName			nvarchar(255)		=	try_convert(nvarchar(255),SUSER_SNAME()) 
	,			@HostName			nvarchar(255)		=	try_convert(nvarchar(255),HOST_NAME()) 
	,			@ProgramName		nvarchar(255)		=	try_convert(nvarchar(255),PROGRAM_NAME()) 
	--
	,			@EventType			nvarchar(100)	
	--	
	,			@TSQLCommand		nvarchar(max)	
	--		
	,			@DatabaseName		nvarchar(255)	
	,			@SchemaName			nvarchar(255)	
	,			@ObjectName			nvarchar(255)	
	--
	;
	
	--
	--
	
	IF @EventXML IS NOT NULL 
	BEGIN 

		--
		--	set variable values		
		--	

			--
			--

			BEGIN TRY	
				SET @EventType = @EventXML.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)') 
			END TRY 
			BEGIN CATCH 
				PRINT 'Failed to set @EventType.'		
				--SET @ErrorMessage = 'Failed to set @EventType.'		
				--GOTO ERROR 
			END CATCH	
			
			--
			--

			BEGIN TRY	
				SET @TSQLCommand = @EventXML.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'NVARCHAR(MAX)') 
			END TRY 
			BEGIN CATCH 
				PRINT 'Failed to set @TSQLCommand.'		
				--SET @ErrorMessage = 'Failed to set @TSQLCommand.'		
				--GOTO ERROR 
			END CATCH	

			--
			--

			BEGIN TRY	
				SET @DatabaseName = @EventXML.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'NVARCHAR(255)') 
			END TRY 
			BEGIN CATCH 
				PRINT 'Failed to set @DatabaseName.'		
				--SET @ErrorMessage = 'Failed to set @DatabaseName.'		
				--GOTO ERROR 
			END CATCH	

			--
			--
			
			BEGIN TRY	
				SET @SchemaName = @EventXML.value('(/EVENT_INSTANCE/SchemaName)[1]', 'NVARCHAR(255)') 
			END TRY 
			BEGIN CATCH 
				PRINT 'Failed to set @SchemaName.'		
				--SET @ErrorMessage = 'Failed to set @SchemaName.'		
				--GOTO ERROR 
			END CATCH	

			--
			--
			
			BEGIN TRY	
				SET @ObjectName = @EventXML.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(255)') 
			END TRY 
			BEGIN CATCH 
				PRINT 'Failed to set @ObjectName.'		
				--SET @ErrorMessage = 'Failed to set @ObjectName.'		
				--GOTO ERROR 
			END CATCH	

			--
			--
			
	--
	--

		--
		--	perform table insert 
		--	

			BEGIN TRY	
		
				INSERT INTO dbo.DDLEvent	
				(
					EventXML
				--
				,	EventType
				--
				,	TSQLCommand
				--
				,	DatabaseName
				,	SchemaName
				,	ObjectName
				--
				,	UserName
				,	HostName
				,	ProgramName
				--
				)	

					SELECT	@EventXML
					--
					,		@EventType
					--		
					,		@TSQLCommand
					--		
					,		@DatabaseName
					,		@SchemaName
					,		@ObjectName
					--		
					,		@UserName
					,		@HostName
					,		@ProgramName
					--
					;	

				SET @RowCount = @@ROWCOUNT ; 

			END TRY		
			BEGIN CATCH		
		
				SET @ErrorMessage = 'An error occurred during attempted INSERT to table [z_DDLEventAudit].[dbo].[DDLEvent].' 
				GOTO ERROR 

			END CATCH	

	--
	--

		--IF @RowCount = 0 
		--BEGIN 
		--	SET @ErrorMessage = 'No records were affected.' 
		--	GOTO ERROR 
		--END		
		--IF @RowCount > 1 
		--BEGIN 
		--	SET @ErrorMessage = 'More than 1 record was affected.' 
		--	GOTO ERROR 
		--END			

	END		--	// end of  " IF @EventXML IS NOT NULL "  code block 

	--
	--

	FINISH:		

	--
	--

	RETURN 1 ; 

	--
	--
	
	ERROR:	

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END		

	RETURN -1 ; 

END 
GO
-- 
-- END FILE :: z002_dbo_usp_Insert_DDLEvent.sql 
-- 