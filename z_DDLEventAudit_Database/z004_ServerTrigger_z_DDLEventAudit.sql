--
-- BEGIN FILE :: z004_ServerTrigger_z_DDLEventAudit.sql 
-- 
USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [ServerTrigger_z_DDLEventAudit] 
ON ALL SERVER  
FOR DDL_EVENTS 
AS 
BEGIN	
	
	SET NOCOUNT ON ; 

	DECLARE @EventXML XML = EVENTDATA() 
	--	
	,		@DatabaseName nvarchar(255) 	
	--	
	;			

	--
	--
	
	IF @EventXML IS NOT NULL 
	BEGIN	
	
		BEGIN TRY	
			SET @DatabaseName = @EventXML.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'NVARCHAR(255)') 
		END TRY 
		BEGIN CATCH 
			
			BEGIN TRY 
				--
				PRINT 'Failed to set @DatabaseName.'
				--
			END TRY 
			BEGIN CATCH 
				IF 1 = 0 
				BEGIN 
					PRINT 'Failed to print.' 
				END		
			END CATCH			

		END CATCH	

		-- 
		--	

		IF @DatabaseName IS NULL 
		OR @DatabaseName NOT IN ( 'z_DDLEventAudit' )  --  define list of databases to be excluded/out-of-scope 
		BEGIN	

			EXEC	z_DDLEventAudit.dbo.usp_Insert_DDLEvent		
					@EventXML	=	@EventXML		
			;	

		END		

		--
		--	

	END 

	--
	--	

END		
GO
ENABLE TRIGGER [ServerTrigger_z_DDLEventAudit] ON ALL SERVER
GO
--
-- END FILE :: z004_ServerTrigger_z_DDLEventAudit.sql 
-- 