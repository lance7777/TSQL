--
-- BEGIN FILE :: 004_utility_usp_Run_ServerMonitor.sql 
--
USE [EXAMPLE]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [utility].[usp_Run_ServerMonitor] 
-- 
	@INCLUDE_sp_WhoIsActive    bit  =  0  -- !! a stored procedure  [dbo].[sp_WhoIsActive]  must exist for this parameter to function !! 
-- 
,	@INCLUDE_RecentDDLEvents		   bit	=  0  -- !! external database/view:  [z_DDLEventAudit].[dbo].[vw_DDLEvent]  is expected !! 
,	@RecentDDLEvents_RecordCountLimit  int	=  9999 
,	@RecentDDLEvents_UserName  varchar(256) =  null  
-- 
,   @INCLUDE_IntegrityCheck    bit  =  0  -- !! common/shared database/routine:  [utility].[usp_Check_StructuralIntegrity]  is expected !! 
-- 
,	@DEBUG		bit		=	0  
-- 
AS 
/**************************************************************************************

	Runs a battery of requested checks (or one or none, depending on input parameters) 
	 related to the server's history and present condition.  


	DEPENDENCIES: -- !! 1 !! [dbo].[sp_WhoIsActive] is intended to reference the famous script here:  [https://github.com/amachanic/sp_whoisactive/releases] 
				  -- !! 2 !! [z_DDLEventAudit].[dbo].[vw_DDLEvent] is a view in this other database:  [https://github.com/lance7777/TSQL/tree/master/z_DDLEventAudit_Database] 
				  -- !! 3 !! [utility].[usp_Check_StructuralIntegrity] is a sister to this procedure: [https://github.com/lance7777/TSQL/tree/master/utility_Schema] 


	Any other checks or displays deemed desirable or relevant to a particular server instance 
	 can be added through new parameters, following the style of these 3 "universal" examples. 
	 

		Example: 


			EXEC  utility.usp_Run_ServerMonitor 
			-- 
				@INCLUDE_sp_WhoIsActive				=  0     --  1  
			--
			,	@INCLUDE_RecentDDLEvents		    =  1  
			,	@RecentDDLEvents_RecordCountLimit   =  777 
			,	@RecentDDLEvents_UserName			=  null  -- 'EXAMPLE\lance7777' -- select suser_sname() ; 
			-- 
			,   @INCLUDE_IntegrityCheck				=  1  
			-- 
			,	@DEBUG	 =	1	
			-- 
			;  
			

	Date			Action	
	----------		----------------------------
	2021-03-07		Created initial version. 
	2021-03-20		Code cleaned & comments embellished for GITHUB repository. 

**************************************************************************************/
BEGIN
	SET NOCOUNT ON;

	DECLARE		@ErrorMessage	 varchar(200)	
	,			@RowCount		 int			
	-- 
	,			@SQL   varchar(max)   
	-- 
	;  
	   
	--
	--  (0)  List of optional components or steps: 
	--												 
		/*    																					 */
		/*    1 - execute the procedure [dbo].[sp_WhoIsActive]									 */
		/*     		(based on @INCLUDE_sp_WhoIsActive)  										 */
		/*     																					 */
		/*    2 - run a query on [z_DDLEventAudit].[dbo].[vw_DDLEvent] view for recent actions	 */
		/*     		(based on @INCLUDE_RecentDDLEvents)  										 */
		/*     																					 */
		/*    3 - execute the procedure [utility].[usp_Check_StructuralIntegrity]				 */
		/*     		(based on @INCLUDE_IntegrityCheck)  										 */
		/*    																					 */
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 
	
	--
	--

		IF @INCLUDE_RecentDDLEvents = 1 
		AND ( @RecentDDLEvents_RecordCountLimit IS NULL 
			OR @RecentDDLEvents_RecordCountLimit <= 0 ) 
		BEGIN 
			SET @RecentDDLEvents_RecordCountLimit = 9999 ; 
		END 

	--
	--
	
	--
	--  (1)  Execute [dbo].[sp_WhoIsActive] 
	--

	IF @INCLUDE_sp_WhoIsActive = 1 -- !! 
	BEGIN 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Execute [dbo].[sp_WhoIsActive].' ) END ; 
	
		BEGIN TRY 

			SET @SQL = ' EXEC dbo.sp_WhoIsActive ; ' ; 
			
			EXEC ( @SQL ) ; 

		END TRY 
		BEGIN CATCH 

			SET @ErrorMessage = 'An error was encountered while attempting to execute [dbo].[sp_WhoIsActive].' 
			GOTO ERROR ; 

		END CATCH 

	END 

	--
	-- // (1) 
	--
	
	--
	--  (2)  Select from [dbo].[vw_DDLEventAudit] 
	--

	IF @INCLUDE_RecentDDLEvents = 1 -- !! 
	BEGIN 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Query recent records from [z_DDLEventAudit].[dbo].[vw_DDLEvent].' ) END ; 
	
		BEGIN TRY 

		  SET @SQL = ' 

				SELECT	TOP (' + convert(varchar(50),@RecentDDLEvents_RecordCountLimit) -- !! NOTE :: @RecentDDLEvents_RecordCountLimit must be non-null !! 
						  + ')  
				-- 
						X.LogTimestamp		
				--
				,		X.EventType 
				--	
				,		X.DatabaseName 
				,		X.SchemaName 
				,		X.ObjectName	
				--
				,		X.UserName 
				,		X.HostName	
				,		X.ProgramName	
				--	
				--
				,		X.TSQLCommand 
				--		
				--		
				FROM  [z_DDLEventAudit].dbo.vw_DDLEvent  X  
				--
				--
				' + CASE WHEN @RecentDDLEvents_UserName IS NOT NULL 
						 THEN 'WHERE  X.UserName  =  ''' + REPLACE(@RecentDDLEvents_UserName,'''','''''') + ''' 
						 ' 
						 ELSE '' 
					END + '--
				--
				ORDER BY  X.LogTimestamp  DESC 
				--
				;

			' ; 
			
			EXEC ( @SQL ) ; 
			
			SET @RowCount = @@ROWCOUNT 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
			
		END TRY 
		BEGIN CATCH 

			SET @ErrorMessage = 'An error was encountered while attempting to SELECT from [z_DDLEventAudit].[dbo].[vw_DDLEvent].' 
			GOTO ERROR ; 

		END CATCH 

	END 

	--
	-- // (2) 
	--
	
	--
	--  (3)  Execute [utility].[usp_Check_StructuralIntegrity] 
	--

	IF @INCLUDE_IntegrityCheck = 1 -- !! 
	BEGIN 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Execute [utility].[usp_Check_StructuralIntegrity].' ) END ; 
	
		BEGIN TRY 
		
			SET @SQL = ' EXEC utility.usp_Check_StructuralIntegrity  @DEBUG = ' + CASE WHEN @DEBUG = 1 THEN '1' ELSE '0' END + ' ; ' ; 
			
			EXEC ( @SQL ) ; 

		END TRY 
		BEGIN CATCH 
		
			SET @ErrorMessage = 'An error was encountered while attempting to execute [utility].[usp_Check_StructuralIntegrity].' 
			GOTO ERROR ; 

		END CATCH 

	END 

	--
	-- // (3) 
	--
	
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'All requested components finished running. Review any displayed result-sets and messages for detected issues.' ) END ; 
	
	--
	--

	FINISH: 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

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
-- 
-- END FILE :: 004_utility_usp_Run_ServerMonitor.sql 
-- 