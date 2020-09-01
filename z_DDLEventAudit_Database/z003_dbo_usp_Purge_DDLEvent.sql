--
-- BEGIN FILE :: z003_dbo_usp_Purge_DDLEvent.sql 
--
USE [z_DDLEventAudit]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_Purge_DDLEvent]    
	@MaximumEventDate		date		=	null	
,	@MinimumEventDate		date		=	null	
--
,	@DEBUG					bit			=	0		
--	
AS
/**************************************************************************************

	Deletes records from [DDLEvent] table based on specific criteria:	

	   --  WHERE [UserName] LIKE '%SERVICE\SQLAgent%' 
	   --  AND	 [EventType] IN ( 'ALTER_INDEX' , 'UPDATE_STATISTICS' )		


	   These criteria should be adjusted depending on the specific server configuration.
	   
	   The idea is to purge records created by repetitive, routine-maintenance-based scheduled jobs 
	    like weekly index & statistics re-generation.
	   
	   There may be many of these records created and they are not very valuable to keep, 
	    so purging them helps control the size of the [dbo].[DDLEvent] table.  


	   If this procedure is deemed useful, 
	    recommend scheduling it to run weekly as part of a SQL Agent Job routine. 

		
		Example:	


			EXEC	dbo.usp_Purge_DDLEvent  
						@MaximumEventDate	=	null	
					,	@MinimumEventDate	=	null	
					--
					,	@DEBUG				=	1	
			;	


	Date			Action	
	----------		----------------------------
	2019-01-18		Created initial version.	
	2020-08-31		Spruced up (cosmetically) for GITHUB post. Added @MinimumEventDate parameter. 

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	DECLARE		@ErrorMessage				varchar(200)	
	,			@RowCount					int				
	--
	,			@CurrentTimestamp			datetime		=	getdate()	
	--
	,			@Default_DaysBackToKeep		int				=	10 		
	--
	;
	
	--
	--

	CREATE TABLE #t_RecordsToPurge 	
	(	
		ID					bigint			not null	primary key		
	--	
	,	EventDate			date			not null
	,	EventType			nvarchar(100)	null	
	,	DatabaseName		nvarchar(255)	null	
	,	UserName			nvarchar(255)	null	
	,	HostName			nvarchar(255)	null	
	--	
	)	
	;	

		CREATE TABLE #t_PurgedRecordSummary 	
		(	
			ID					int				not null	identity(1,1)	primary key		
		--	
		,	PurgedTimestamp		datetime		not null	
		--	
		,	EventDate			date			not null
		,	EventType			nvarchar(100)	null	
		,	DatabaseName		nvarchar(255)	null	
		,	UserName			nvarchar(255)	null	
		,	HostName			nvarchar(255)	null	
		--
		,	PurgedRecordCount	int				not null	
		--
		/* -- 2020-08-31 :: Although logically unique, including this index generates a warning message 
		   --				 about potentially exceeding the maximum bit-length for a key column-set.
		*/ -- 
		--,	UNIQUE	(
		--				EventDate		
		--			,	EventType		
		--			,	DatabaseName	
		--			,	UserName		
		--			,	HostName		
		--			)	
		--	
		)	
		;	
			
	--	
	--	
		
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 
	
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check input parameters.' ) END ; 
	
		IF @MaximumEventDate IS NULL 
		BEGIN 
			SET @MaximumEventDate = dateadd(	day
										   ,   -@Default_DaysBackToKeep
										   ,	convert(date,@CurrentTimestamp)
										   )	
			--	
			;	
		END		

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Gather list of records to be purged.' ) END ; 

		INSERT INTO #t_RecordsToPurge 	
		(
			ID	
		--
		,	EventDate		
		,	EventType		
		,	DatabaseName	
		,	UserName		
		,	HostName		
		)	

		SELECT	X.ID	
		--
		,		convert(date,X.LogTimestamp)	EventDate	
		,		X.EventType		
		,		X.DatabaseName	
		,		X.UserName 
		,		X.HostName	
		--	
		FROM	dbo.DDLEvent	X	
		--
		WHERE	convert(date,X.LogTimestamp) <= @MaximumEventDate	
		--
		AND		(
					convert(date,X.LogTimestamp) >= @MinimumEventDate 
				OR	@MinimumEventDate IS NULL 
				)	
		--
			/*
			--
			--  Specific criteria below will depend on server configuration, as noted in header. 
			-- 
			*/	
		AND		(
					X.UserName LIKE '%SERVICE\SQLAgent%' 
			    AND	X.EventType IN ( 'ALTER_INDEX' , 'UPDATE_STATISTICS' )	
				)	
		--
		;	
		
	SET @RowCount = @@ROWCOUNT ; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--
	
		IF ( SELECT COUNT(*) FROM #t_RecordsToPurge ) = 0 
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'No records gathered for purge.' ) END ; 
			GOTO FINISH ;	
		END		
		
	--
	--	
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Summarize records to be purged, for table [dbo].[DDLEvent_PurgedRecordSummary].' ) END ; 
	
		INSERT INTO #t_PurgedRecordSummary	
		(
			PurgedTimestamp			
		--							
		,	EventDate				
		,	EventType				
		,	DatabaseName			
		,	UserName				
		,	HostName				
		--							
		,	PurgedRecordCount		
		--	
		)	

		SELECT	@CurrentTimestamp	as	PurgeTimestamp		
		--
		,		X.EventDate 
		,		X.EventType
		,		X.DatabaseName
		,		X.UserName
		,		X.HostName	
		--
		,		COUNT(*)			as	PurgedRecordCount	
		--	
		FROM	#t_RecordsToPurge	X		
		--
		GROUP BY	X.EventDate 
		,			X.EventType
		,			X.DatabaseName
		,			X.UserName
		,			X.HostName	
		--
		;	
	
	SET @RowCount = @@ROWCOUNT ; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Delete records from dbo.DDLEvent.' ) END ; 
	
	BEGIN TRY 
	
		--	
		--	
		DISABLE TRIGGER TG_DDLEvent_UpdateDelete ON dbo.DDLEvent ; 
		--
		--	

			DELETE		X	
			FROM		#t_RecordsToPurge	T	
			INNER JOIN	dbo.DDLEvent		X	ON	T.ID = X.ID		
			--	
			;				
	
		SET @RowCount = @@ROWCOUNT ; 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
		
		--	
		--	
		ENABLE TRIGGER TG_DDLEvent_UpdateDelete ON dbo.DDLEvent ; 
		--
		--	

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered while attempting to delete records from [dbo].[DDLEvent].' 
		GOTO ERROR 

	END CATCH	

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate [dbo].[DDLEvent_PurgedRecordSummary].' ) END ; 
	
	BEGIN TRY 

		INSERT INTO dbo.DDLEvent_PurgedRecordSummary	
		(
			PurgedTimestamp
		--
        ,	EventDate
        ,	EventType
        ,	DatabaseName
        ,	UserName
        ,	HostName
		--
        ,	PurgedRecordCount
		--	
		)	

			SELECT	X.PurgedTimestamp
			--
			,		X.EventDate
			,		X.EventType
			,		X.DatabaseName
			,		X.UserName
			,		X.HostName
			--
			,		X.PurgedRecordCount
			--	
			FROM	#t_PurgedRecordSummary	X	
			--
			;	
	
		SET @RowCount = @@ROWCOUNT ; 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
		
	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered while attempting to populate dbo.DDLEvent_PurgedRecordSummary.' 
		GOTO ERROR 

	END CATCH	
	
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Purge complete.' ) END ; 

	--
	--

	FINISH:		

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 
	
	--
	DROP TABLE #t_RecordsToPurge  
	DROP TABLE #t_PurgedRecordSummary  
	--

	RETURN 1 ; 

	--
	--
	
	ERROR:	

	--
	IF OBJECT_ID('tempdb..#t_RecordsToPurge') IS NOT NULL DROP TABLE #t_RecordsToPurge  
	IF OBJECT_ID('tempdb..#t_PurgedRecordSummary') IS NOT NULL DROP TABLE #t_PurgedRecordSummary
	--

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END		

	RETURN -1 ; 

END
GO
-- 
-- END FILE :: z003_dbo_usp_Purge_DDLEvent.sql 
-- 