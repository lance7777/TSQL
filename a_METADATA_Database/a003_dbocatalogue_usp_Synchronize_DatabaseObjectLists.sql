--
-- BEGIN FILE :: a003_dbocatalogue_usp_Synchronize_ScopedDatabaseObjectLists.sql 
--
USE [a_METADATA] 
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbocatalogue.usp_Synchronize_ScopedDatabaseObjectLists 
--
	@Mode		varchar(10)		=	'TEST'	--	'TEST' , 'LIVE'		
--
,	@DatabaseName	 varchar(256)	=	null	
--
,	@UpdateSizeEstimates	bit		=	0		--  set to 1 to update TupleStructure & ScopedDatabase "Size" fields 	
--	
,	@DEBUG		bit				=	0 
--
AS
/**************************************************************************************

	Updates records in [dbocatalogue]-schema tables 
	 to reflect [sys] and [INFORMATION_SCHEMA] record information 
	  gathered from current configurations, for "in-scope" databases. 

	
	  If the @DatabaseName parameter is provided, 
	   synchronization will be restricted to only the provided database. 

	  If @UpdateSizeEstimates is set to 1, 
	   "Size"-related column values will be updated in two tables:
	      [LatestSizeUpdateTimestamp], [LatestRowCount], and [LatestTotalSpaceKB] 
		   in the [TupleStructure] table, 
		and [LatestSizeUpdateTimestamp] and [LatestTotalFileSize] 
		 in the [ScopedDatabase] table. 


		Example: 
		

			EXEC	dbocatalogue.usp_Synchronize_ScopedDatabaseObjectLists
						@Mode   =  'TEST' 
					--
					,   @DatabaseName  =  null 
					--
					,	@UpdateSizeEstimates  =  0 
					--
					,	@DEBUG  =   1  
			; 


	Date			Action	
	----------		----------------------------
	2020-09-27		Created initial version. 
	2020-09-28		Fixed 1 bug in population of #StoredProcedureParameter table. 

**************************************************************************************/
BEGIN
	SET NOCOUNT ON;

	DECLARE		@ErrorMessage				varchar(200)	
	,			@RowCount					int				
	--	
	--
	,			@Cursor_ScopedDatabaseID	int				
	,			@Cursor_DatabaseName		varchar(256)	
	--
	,			@SQL						varchar(MAX)	
	--
	--
	,	@sys_object_type_desc_Table 					  varchar(100)  =  'USER_TABLE'							
	,	@sys_object_type_desc_View 						  varchar(100)  =  'VIEW'								
	,	@sys_object_type_desc_UserDefinedTableType		  varchar(100)  =  'TYPE_TABLE'								
	,	@sys_object_type_desc_StoredProcedure 			  varchar(100)  =  'SQL_STORED_PROCEDURE'				
	,	@sys_object_type_desc_TableValuedFunction 		  varchar(100)  =  'SQL_TABLE_VALUED_FUNCTION'			
	,	@sys_object_type_desc_TableValuedFunction_INLINE  varchar(100)  =  'SQL_INLINE_TABLE_VALUED_FUNCTION'	
	,	@sys_object_type_desc_ScalarValuedFunction		  varchar(100)  =  'SQL_SCALAR_FUNCTION'				
	,	@sys_object_type_desc_Synonym					  varchar(100)  =  'SYNONYM'							
	--
	,	@TupleStructureType_CodeName_Table					varchar(10)	 =  'T' 
	,	@TupleStructureType_CodeName_View					varchar(10)	 =  'V' 
	,	@TupleStructureType_CodeName_UserDefinedTableType	varchar(10)	 =  'UTT' 
	--
	--
	;
	
	IF @Mode IS NULL 
	BEGIN 
		SET @Mode = 'TEST' ;
	END 
	IF @Mode NOT IN ( 'TEST' , 'LIVE' ) 
	BEGIN 
		SET @ErrorMessage = '@Mode parameter value must be either ''TEST'' or ''LIVE''.' ; 
		GOTO ERROR ; 
	END 

	--
	--  (0)  List of tables to update/populate: 
	--
        /*                                          */
        /*    1a - DatabaseRole                     */
        /*    1b - DatabaseSchema                   */
        /*                                          */
        /*    2a - TupleStructure                   */
        /*    2b - TupleStructureColumn             */
        /*                                          */
        /*    3a - ScalarValuedFunction             */
        /*    3b - ScalarValuedFunctionParameter    */
        /*                                          */
        /*    4a - TableValuedFunction              */
        /*    4b - TableValuedFunctionParameter     */
        /*    4c - TableValuedFunctionColumn        */
        /*                                          */
        /*    5a - StoredProcedure                  */
        /*    5b - StoredProcedureParameter         */
        /*                                          */
        /*    6a - SynonymAlias                     */
        /*                                          */
	--
	--

	CREATE TABLE #ScopedDatabase 
	(
		ID		int		not null	primary key 
	--
	,	DatabaseName							varchar(256)	not null	unique	
	--
	,	LatestCheckForSynchronizationUpdate		datetime		null 
	,	LatestObjectListChangeRecorded			datetime		null 
	--
	,	LatestSizeUpdateTimestamp				datetime		null	
	,	LatestTotalFileSize						float			null	
	--
	,	NEW_LatestCheckForSynchronizationUpdate		datetime	null 
	,	NEW_LatestObjectListChangeRecorded			datetime	null 
	--
	,	NEW_LatestSizeUpdateTimestamp				datetime	null	
	,	NEW_LatestTotalFileSize						float		null	
	--
	);  --
		--	tables to cache records from "sys" or "INFORMATION_SCHEMA" tables/views in scoped databases 
		-- 
		CREATE TABLE #Cache_sys_database_principals  -- select * from sys.database_principals 
		(
			ID					 bigint			not null	identity(1,1)	primary key		
		--						 				
		,	ScopedDatabaseID	 int			not null	
		--
		--
		,	[principal_id]		 bigint			not null 
		--
		,	[name]				 varchar(256)	not null 
		,	[type_desc]			 varchar(100)	not null 
		--						 
		,	create_date			 datetime		null 
		,	modify_date			 datetime		null 
		--						 
		,	is_fixed_role		 bit			not null 
		--
		--
		,	UNIQUE ( ScopedDatabaseID , [name] ) 
		,	UNIQUE ( ScopedDatabaseID , [principal_id] ) 
		--
		);
		--
		CREATE TABLE #Cache_sys_schemas  -- select * from sys.schemas  
		(
			ID					 bigint			not null	identity(1,1)	primary key		
		--						 				
		,	ScopedDatabaseID	 int			not null	
		--
		--
		,	[name]				 varchar(256)	not null 
		--						 
		,	[schema_id]			 bigint			not null 
		,	[principal_id]		 bigint			null 
		--
		--
		,	UNIQUE ( ScopedDatabaseID , [name] ) 
		,	UNIQUE ( ScopedDatabaseID , [schema_id] ) 
		--
		);
		--
		CREATE TABLE #Cache_sys_objects  -- select * from sys.objects   
		(
			ID					 bigint			not null	identity(1,1)	primary key		
		--						 				
		,	ScopedDatabaseID	 int			not null	
		--
		--
		,	[name]				 varchar(256)	not null 
		--						 
		,	[object_id]			 bigint			not null 
		,	[principal_id]		 bigint			null 
		,	[schema_id]			 bigint			not null 
		--
		,	[parent_object_id]	 bigint			null 
		--
		,	[type]				 varchar(50)	not null 
		,	[type_desc]			 varchar(100)	not null 
		--						 
		,	create_date			 datetime		null 
		,	modify_date			 datetime		null 
		--						 
		,	is_ms_shipped		 bit			not null 
		--
		--
		,	TABLE_SizeTimestamp		datetime	null
		,	TABLE_RowCount			bigint		null 
		,	TABLE_TotalSpaceKB		float		null 
		--
		,	ROUTINE_ReturnValue_DataType_Name			varchar(20)		null 
		,	ROUTINE_ReturnValue_DataType_MaxLength		int				null 
		,	ROUTINE_ReturnValue_DataType_Precision		int				null 
		,	ROUTINE_ReturnValue_DataType_Scale			int				null 
		--
		,	SYNONYM_base_object_name		varchar(1024)	null 		
		--
		--
		,	UNIQUE ( ScopedDatabaseID , [schema_id] , [name] ) 
		,	UNIQUE ( ScopedDatabaseID , [object_id] ) 
		--
		);
		--
		CREATE TABLE #Cache_sys_all_columns  -- select * from sys.all_columns    
		(
			ID					 bigint			not null	identity(1,1)	primary key		
		--						 				
		,	ScopedDatabaseID	 int			not null	
		--
		--
		,	[object_id]			 bigint			not null 
		--						 
		,	[column_id]			 bigint			not null 
		,	[name]				 varchar(256)	not null 
		--
		,	[type_name]			 varchar(20)	null 			
		,	max_length			 int			null 
		,	[precision] 		 int			null 
		,	[scale]				 int			null 
		,	is_nullable 		 bit			null 
		,	is_identity 		 bit			null 
		,	default_object_id  	 bigint			null 
		--
		--
		,	UNIQUE ( ScopedDatabaseID , [object_id] , [column_id] ) 
		,	UNIQUE ( ScopedDatabaseID , [object_id] , [name] ) 
		--
		);
		--
		CREATE TABLE #Cache_sys_all_parameters  -- select * from sys.all_parameters  
		(
			ID					 bigint			not null	identity(1,1)	primary key		
		--						 				
		,	ScopedDatabaseID	 int			not null	
		--
		--
		,	[object_id]			 bigint			not null 
		--						 
		,	[parameter_id]		 bigint			not null 
		,	[name]				 varchar(256)	not null 
		--
		,	[type_name]			 varchar(20)	null 			
		,	max_length			 int			null 
		,	[precision] 		 int			null 
		,	scale 				 int			null 
		,	is_output 			 bit			null 
		,	has_default_value    bit			null 
		,	is_readonly		  	 bit 			null 
		--
		--
		,	UNIQUE ( ScopedDatabaseID , [object_id] , [parameter_id] ) 
		,	UNIQUE ( ScopedDatabaseID , [object_id] , [name] ) 
		--
		);
		--
	--
	--  (1)  Declare temporary tables to replicate/"model" each of the persistent tables in the list above: 
	--
	CREATE TABLE #DatabaseRole -- 1a 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	ScopedDatabaseID	int				not null	
	,	RoleName			varchar(256)	not null	
	--
	,	Est_CreationTimestamp		datetime	null 
	,	Est_LastModifiedTimestamp	datetime	null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( ScopedDatabaseID , RoleName ) 
	--
	); 
	CREATE TABLE #DatabaseSchema -- 1b 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	ScopedDatabaseID	int				not null	
	,	SchemaName			varchar(256)	not null	
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	,	ObjectListChangeDetected	bit			null 
	--
	--
	,	UNIQUE	( ScopedDatabaseID , SchemaName ) 
	--
	);
	--
	--
	CREATE TABLE #TupleStructure -- 2a 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_DatabaseSchemaID	bigint			not null	
	,	ObjectName						varchar(256)	not null	
	,	TupleStructureTypeID			int				not null	
	--
	,	Est_CreationTimestamp		datetime	null	
	,	Est_LastModifiedTimestamp	datetime	null	
	--
	,	LatestSizeUpdateTimestamp   datetime	null 
	,	LatestRowCount				bigint		null	
	,	LatestTotalSpaceKB			float		null	 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	UpdateSizeFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_DatabaseSchemaID , ObjectName ) 
	--
	);
	CREATE TABLE #TupleStructureColumn -- 2b 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_TupleStructureID	bigint			not null	
	,	ColumnName						varchar(256)	not null	
	,	OrdinalNumber					int				not null 
	--
	,	DataType_Name					varchar(20)		null 
	,	DataType_MaxLength				int				null 
	,	DataType_Precision				int				null 
	,	DataType_Scale					int				null 
	,	IsNullable						bit				null 
	,	IsIdentity						bit				null 
	,	HasDefaultValue					bit				null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_TupleStructureID , ColumnName ) 
	,	UNIQUE	( internalTemp_TupleStructureID , OrdinalNumber ) 
	--
	);
	--
	--
	CREATE TABLE #ScalarValuedFunction -- 3a 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_DatabaseSchemaID	bigint			not null	
	,	ObjectName						varchar(256)	not null	
	--
	,	ReturnValue_DataType_Name			varchar(20)		null 
	,	ReturnValue_DataType_MaxLength		int				null 
	,	ReturnValue_DataType_Precision		int				null 
	,	ReturnValue_DataType_Scale			int				null 
	--
	,	Est_CreationTimestamp		datetime	null 
	,	Est_LastModifiedTimestamp	datetime	null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_DatabaseSchemaID , ObjectName ) 
	--
	);
	CREATE TABLE #ScalarValuedFunctionParameter -- 3b 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_ScalarValuedFunctionID		bigint		  not null	
	,	ParameterName							varchar(256)  not null	
	,	OrdinalNumber							int			  not null 
	--
	,	DataType_Name			varchar(20)	  null 
	,	DataType_MaxLength		int			  null 
	,	DataType_Precision		int			  null 
	,	DataType_Scale			int			  null 
	,	HasDefaultValue			bit			  null 
	,	IsOutput				bit			  null 
	,	IsReadOnly				bit			  null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_ScalarValuedFunctionID , ParameterName ) 
	,	UNIQUE	( internalTemp_ScalarValuedFunctionID , OrdinalNumber ) 
	--
	);
	--
	--
	CREATE TABLE #TableValuedFunction -- 4a 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_DatabaseSchemaID	bigint			not null	
	,	ObjectName						varchar(256)	not null	
	--
	,	IsInline					bit			not null	
	--
	,	Est_CreationTimestamp		datetime	null 
	,	Est_LastModifiedTimestamp	datetime	null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_DatabaseSchemaID , ObjectName ) 
	--
	);
	CREATE TABLE #TableValuedFunctionParameter -- 4b 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_TableValuedFunctionID		bigint		  not null	
	,	ParameterName							varchar(256)  not null	
	,	OrdinalNumber							int			  not null 
	--
	,	DataType_Name			varchar(20)	  null 
	,	DataType_MaxLength		int			  null 
	,	DataType_Precision		int			  null 
	,	DataType_Scale			int			  null 
	,	HasDefaultValue			bit			  null 
	,	IsOutput				bit			  null 
	,	IsReadOnly				bit			  null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_TableValuedFunctionID , ParameterName ) 
	,	UNIQUE	( internalTemp_TableValuedFunctionID , OrdinalNumber ) 
	--
	);
	CREATE TABLE #TableValuedFunctionColumn -- 4c 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_TableValuedFunctionID		bigint		  not null	
	,	ColumnName								varchar(256)  not null	
	,	OrdinalNumber							int			  not null 
	--
	,	DataType_Name			varchar(20)	  null 
	,	DataType_MaxLength		int			  null 
	,	DataType_Precision		int			  null 
	,	DataType_Scale			int			  null 
	,	IsNullable				bit			  null 
	,	IsIdentity				bit			  null 
	,	HasDefaultValue			bit			  null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_TableValuedFunctionID , ColumnName ) 
	,	UNIQUE	( internalTemp_TableValuedFunctionID , OrdinalNumber ) 
	--
	);
	--
	--
	CREATE TABLE #StoredProcedure -- 5a 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_DatabaseSchemaID	bigint			not null	
	,	ObjectName						varchar(256)	not null	
	--
	,	Est_CreationTimestamp		datetime	null 
	,	Est_LastModifiedTimestamp	datetime	null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_DatabaseSchemaID , ObjectName ) 
	--
	);
	CREATE TABLE #StoredProcedureParameter -- 5b 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_StoredProcedureID		bigint		  not null	
	,	ParameterName						varchar(256)  not null	
	,	OrdinalNumber						int			  not null 
	--
	,	DataType_Name			varchar(20)	  null 
	,	DataType_MaxLength		int			  null 
	,	DataType_Precision		int			  null 
	,	DataType_Scale			int			  null 
	,	HasDefaultValue			bit			  null 
	,	IsOutput				bit			  null 
	,	IsReadOnly				bit			  null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_StoredProcedureID , ParameterName ) 
	,	UNIQUE	( internalTemp_StoredProcedureID , OrdinalNumber ) 
	--
	);
	--
	--
	CREATE TABLE #SynonymAlias -- 6a 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	internalTemp_DatabaseSchemaID	bigint			not null	
	,	ObjectName						varchar(256)	not null	
	--
	,	Target_ServerName		varchar(256)	null	
	,	Target_DatabaseName		varchar(256)	null 	
	,	Target_SchemaName		varchar(256)	null 	
	,	Target_ObjectName		varchar(256)	null 
	--
	,	Est_CreationTimestamp		datetime	null 
	,	Est_LastModifiedTimestamp	datetime	null 
	--
	--
	,	PersistentTableRecordID		bigint		null 
	,	UpdateCoreFieldValues		bit			null 
	,	ReactivateRecord			bit			null 
	--
	--
	,	UNIQUE	( internalTemp_DatabaseSchemaID , ObjectName ) 
	--
	);
	--
	--
	--
	--
	CREATE TABLE #RecordForDeactivation 
	(
		ID		bigint	not null	identity(1,1)	primary key 
	--
	,	TableSchemaAndName			varchar(550)	not null 
	--
	,	PersistentTableRecordID		bigint			not null 
	--
	,   internalTemp_DatabaseSchemaID   bigint   null 
	,   ScopedDatabaseID				int	     not null 
	--
	--
	,	UNIQUE	( TableSchemaAndName , PersistentTableRecordID ) 
	--
	);
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 
	
	--
	--
	
	--
	--  (2)  Populate all temporary tables, in order of creation above:  
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Get list of "in-scope" databases for object-catalogue synchronization.' ) END ; 
	
	BEGIN TRY 

		INSERT INTO #ScopedDatabase 
		(	ID		
		--											
		,	DatabaseName						 
		--											
		,	LatestCheckForSynchronizationUpdate	 
		,	LatestObjectListChangeRecorded		 
		--
		,	LatestSizeUpdateTimestamp
		,	LatestTotalFileSize
		--												
		,	NEW_LatestCheckForSynchronizationUpdate			 
		--,	NEW_LatestObjectListChangeRecorded			
		--
		)	SELECT	SD.[ID] 
			--
			,		SD.DatabaseName						 
			--												
			,		SD.LatestCheckForSynchronizationUpdate	 
			,		SD.LatestObjectListChangeRecorded		 
			--
			,		SD.LatestSizeUpdateTimestamp
			,		SD.LatestTotalFileSize
			--													
			,		getdate()  as  NEW_LatestCheckForSynchronizationUpdate			 
			--,		null	   as  NEW_LatestObjectListChangeRecorded			
			--
			FROM	serverconfig.ScopedDatabase	 SD  
			-- 
			INNER JOIN  master.sys.sysdatabases  MX  WITH(NOLOCK)  
												 --
												 ON  SD.DatabaseName = MX.[name] 
												 --
			--
			WHERE	SD.KeepingRecordsSynchronized = 1 
			--
			AND		(
						SD.DatabaseName = @DatabaseName 
					OR	@DatabaseName IS NULL 
					)	
			--
			;

		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to populate #ScopedDatabase temporary table.' ; 
		GOTO ERROR ; 
	END CATCH 

	--
	--

		IF ( SELECT COUNT(*) FROM #ScopedDatabase X ) = 0 
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'No scoped databases were found, for synchronization!' ) END ; 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'End the routine without further action.' ) END ; 

			GOTO FINISH ; 
		END 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Cache relevant [sys] and [INFORMATION_SCHEMA] content from each database.' ) END ; 
	
	DECLARE #C_loop_ScopedDatabase CURSOR LOCAL READ_ONLY FORWARD_ONLY STATIC 
	
				FOR		SELECT	X.ID			as  ScopedDatabaseID 
						,		X.DatabaseName  as  DatabaseName
						FROM	#ScopedDatabase  X 
						--
						ORDER BY  X.ID  ASC  
						--
					  
	OPEN #C_loop_ScopedDatabase 
	
	WHILE 1=1 
	BEGIN 
	
		FETCH NEXT 
		FROM #C_loop_ScopedDatabase 
		INTO @Cursor_ScopedDatabaseID
		, @Cursor_DatabaseName ; 
		
		IF @@FETCH_STATUS != 0 BREAK ; 
		
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo ( '	Database: [' + @Cursor_DatabaseName + ']' ) END ; 
	
		BEGIN TRY 
		
		/****/	--
		/****/  --	Update database total file size  
		/****/  --	

			SET @RowCount = ( SELECT COUNT(*) FROM #ScopedDatabase X WHERE X.NEW_LatestTotalFileSize IS NOT NULL )
			
			SET @SQL = '

				UPDATE	SD 
				SET		SD.NEW_LatestTotalFileSize = X.TotalSize
				,		SD.NEW_LatestSizeUpdateTimestamp = getdate() 
				--
				FROM	#ScopedDatabase  SD  
				INNER JOIN	(
								SELECT	SUM(try_convert(float,DF.[size])) as TotalSize 
								FROM	[' + @Cursor_DatabaseName + '].[sys].[database_files]	DF  WITH(NOLOCK)  
							) 
								X	ON  SD.ID = ' + convert(varchar(50),@Cursor_ScopedDatabaseID) + '  
									AND X.TotalSize > 0.00 
				--
				;

			'

				EXEC ( @SQL ) ; 

			SET @RowCount = ( SELECT COUNT(*) FROM #ScopedDatabase X WHERE X.NEW_LatestTotalFileSize IS NOT NULL ) - @RowCount ; 
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( '  set total file size estimate :: rows (sys.database_files): ' + convert(varchar(20),@RowCount) ) END ; 
		
			--
			--
			
		/****/	--
		/****/  --	Pull from  sys.database_principals 
		/****/  --	

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_database_principals X )

			SET @SQL = '

				INSERT INTO #Cache_sys_database_principals 
				(
					ScopedDatabaseID	
				--
				--
				,	[principal_id] 
				-- 
				,	[name]				
				,	[type_desc]			
				--						
				,	create_date			
				,	modify_date			
				--						
				,	is_fixed_role	
				--
				)	
				
					SELECT  ' + convert(varchar(50),@Cursor_ScopedDatabaseID) + '  as  ScopedDatabaseID 
					--
					--
					,		DP.[principal_id] 
					--
					,		DP.[name] 
					,		DP.[type_desc] 
					--
					,		CASE WHEN DP.[name] IN ( ''dbo'' , ''public'' ) THEN null ELSE DP.create_date END  as  create_date 
					,		CASE WHEN DP.[name] IN ( ''public'' ) THEN null ELSE DP.modify_date END  as  modify_date 
					--
					,		DP.is_fixed_role 
					--
					FROM	[' + @Cursor_DatabaseName + '].[sys].[database_principals]  DP  WITH(NOLOCK)  
					--
					WHERE	(
								(	
									DP.[type_desc] = ''DATABASE_ROLE'' 
								AND DP.is_fixed_role = 0 
								) 
							--
							OR	DP.[name] = ''dbo'' 
							--
							) 
					--
					AND		DP.is_fixed_role IS NOT NULL 
					--
					AND     TRY_CONVERT(varchar(256),DP.[name]) IS NOT NULL 
					--
					AND		LEN(DP.[type_desc]) BETWEEN 1 AND 100 
					--
					AND		DP.[principal_id] IS NOT NULL 
					--
					;

			'

				EXEC ( @SQL ) ; 

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_database_principals X ) - @RowCount ; 
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( '  rows (sys.database_principals): ' + convert(varchar(20),@RowCount) ) END ; 
		
			--
			--
			
		/****/	--
		/****/  --	Pull from  sys.schemas  
		/****/  --	

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_schemas X )

			SET @SQL = '

				INSERT INTO #Cache_sys_schemas 
				(
					ScopedDatabaseID	
				--
				--
				,	[name]			
				--					
				,	[schema_id]		
				,	[principal_id]	
				--
				)	
				
					SELECT	X.ScopedDatabaseID	
					--
					--
					,		X.[name]			
					--						
					,		X.[schema_id]		
					,		X.[principal_id]	
					--
					FROM	(
								SELECT  ' + convert(varchar(50),@Cursor_ScopedDatabaseID) + '  as  ScopedDatabaseID 
								--
								--
								,		S.[name]			
								--					
								,		S.[schema_id]		
								,		S.[principal_id]	
								--
								FROM	[' + @Cursor_DatabaseName + '].[sys].[schemas]  S  WITH(NOLOCK)   
								--
								WHERE	LEN(S.[name]) BETWEEN 1 AND 256 
								AND		S.[schema_id] IS NOT NULL 
								--
							)
								X	LEFT  JOIN  #Cache_sys_database_principals  C_DP  ON  X.ScopedDatabaseID = C_DP.ScopedDatabaseID 
																					  AND X.[principal_id] = C_DP.[principal_id] 
					--	
					WHERE	C_DP.[principal_id] IS NOT NULL 
					--
					; 

			'

				EXEC ( @SQL ) ; 

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_schemas X ) - @RowCount ; 
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( '  rows (sys.schemas): ' + convert(varchar(20),@RowCount) ) END ; 
		
			--
			--
			
		/****/	--
		/****/  --	Pull from  sys.objects 
		/****/  --	

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_objects X )

			SET @SQL = '

				INSERT INTO #Cache_sys_objects 
				(
					ScopedDatabaseID	
				--
				--
				,	[name]				
				--						
				,	[object_id]			
				,	[principal_id]		
				,	[schema_id]			
				--						
				,	[parent_object_id]	
				--						
				,	[type]				
				,	[type_desc]			
				--						
				,	create_date			
				,	modify_date			
				--						
				,	is_ms_shipped		
				--
				,	TABLE_SizeTimestamp	
				,	TABLE_RowCount 
				,	TABLE_TotalSpaceKB 
				--
				,	ROUTINE_ReturnValue_DataType_Name		
				,	ROUTINE_ReturnValue_DataType_MaxLength	
				,	ROUTINE_ReturnValue_DataType_Precision	
				,	ROUTINE_ReturnValue_DataType_Scale		
				--
				,	SYNONYM_base_object_name 
				--
				) 
				
					SELECT	Y.ScopedDatabaseID	
					--
					--
					,		Y.[name]				
					--							
					,		Y.[object_id]			
					,		Y.[principal_id]		
					,		Y.[schema_id]			
					--							
					,		Y.[parent_object_id]	
					--							
					,		Y.[type]				
					,		Y.[type_desc]			
					--							
					,		Y.create_date			
					,		Y.modify_date			
					--							
					,		Y.is_ms_shipped		
					--
					,		TS_est.SizeTimestamp			as  TABLE_SizeTimestamp
					,		TS_est.MaxPartitionRowCount 	as  TABLE_RowCount 
					,		TS_est.TotalSpaceKB				as  TABLE_TotalSpaceKB 
					--
					,		R.[DATA_TYPE] 					as	ROUTINE_ReturnValue_DataType_Name		
					,		R.[CHARACTER_MAXIMUM_LENGTH]	as	ROUTINE_ReturnValue_DataType_MaxLength	
					,		R.[NUMERIC_PRECISION] 			as	ROUTINE_ReturnValue_DataType_Precision	
					,		R.[NUMERIC_SCALE] 				as	ROUTINE_ReturnValue_DataType_Scale		
					--
					,		SYN.[base_object_name]			as	SYNONYM_base_object_name
					--
					FROM	(
								SELECT  ' + convert(varchar(50),@Cursor_ScopedDatabaseID) + '  as  ScopedDatabaseID 
								--
								--
								,		coalesce(TT.[name],X.[name])  as  [name] 			
								--						
								,		X.[object_id]		
								,		X.[principal_id]	
								,		coalesce(TT.[schema_id],X.[schema_id])  as  [schema_id] 
								--						
								,		X.[parent_object_id]	
								--						
								,		X.[type]			
								,		X.[type_desc]		
								--						
								,		X.create_date		
								,		X.modify_date		
								--						
								,		X.is_ms_shipped	
								--
								FROM	[' + @Cursor_DatabaseName + '].[sys].[objects]  X  WITH(NOLOCK)  
								--
								LEFT  JOIN  (
												SELECT	TTs.[type_table_object_id] as [object_id]
												,		MAX(TTs.[name]) as [name] 
												,		MAX(TTs.[schema_id]) as [schema_id] 
												FROM	[' + @Cursor_DatabaseName + '].[sys].[table_types]  TTs  WITH(NOLOCK)  
												WHERE	TTs.[type_table_object_id] IS NOT NULL 
												AND		TTs.is_user_defined = 1 
												AND		TTs.[schema_id] IS NOT NULL 
												AND		TTs.[name] IS NOT NULL 
												GROUP BY  TTs.[type_table_object_id] 
												HAVING	  COUNT(*) = 1 
											)
												TT  ON  X.[object_id] = TT.[object_id] 
													AND X.[type_desc] = ''' + @sys_object_type_desc_UserDefinedTableType + ''' 
								--
								WHERE	LEN(coalesce(TT.[name],X.[name])) BETWEEN 1 AND 256 
								AND		coalesce(TT.[schema_id],X.[schema_id]) IS NOT NULL 
								AND		X.[object_id] IS NOT NULL 
								--
								AND		LEN(X.[type]) BETWEEN 1 AND 50 
								AND		LEN(X.[type_desc]) BETWEEN 1 AND 100 
								--
								AND		(
											(
												X.is_ms_shipped = 0 
											AND X.[type_desc] != ''' + @sys_object_type_desc_UserDefinedTableType + ''' 
											AND TT.[object_id] IS NULL 
											) 
										OR	(
												X.is_ms_shipped IN ( 1 , 0 )   
											AND X.[type_desc] = ''' + @sys_object_type_desc_UserDefinedTableType + ''' 
											AND TT.[object_id] IS NOT NULL 
											)
										) 
								--
							)
								Y	LEFT  JOIN  #Cache_sys_schemas  C_S  ON  Y.ScopedDatabaseID = C_S.ScopedDatabaseID 
																		 AND Y.[schema_id] = C_S.[schema_id] 
					--
					LEFT  JOIN	(
									SELECT		Tz.[object_id]	
									,			getdate()			as	SizeTimestamp	
									-- 
									,			MAX(coalesce(Pz.[rows],0))	as	MaxPartitionRowCount 
									,			try_convert(float,
												  SUM(coalesce(Az.[total_pages],0.00)) 
												 * 8.00 )				as	TotalSpaceKB 
									-- 
									FROM		[' + @Cursor_DatabaseName + '].[sys].[tables]	Tz  WITH(NOLOCK) 
									INNER JOIN  [' + @Cursor_DatabaseName + '].[sys].[indexes]  Iz  WITH(NOLOCK)  
																								--
																								ON  Tz.[object_id] = Iz.[object_id] 
																								--
									INNER JOIN [' + @Cursor_DatabaseName + '].[sys].[partitions]  Pz  WITH(NOLOCK) 
																								--
																								ON  Iz.[object_id] = Pz.[object_id] 
																							    AND Iz.[index_id] = Pz.[index_id] 
																								-- 
									INNER JOIN [' + @Cursor_DatabaseName + '].[sys].[allocation_units]  Az  WITH(NOLOCK)  
																								--
																								ON Pz.[partition_id] = Az.[container_id] 
																								--
									WHERE		Tz.[object_id] IS NOT NULL 
									GROUP BY	Tz.[object_id] 
									--
									HAVING		try_convert(float,SUM(coalesce(Az.[total_pages],0.00)) * 8.00) >= 0.00 
									OR			MAX(coalesce(Pz.[rows],0)) >= 0 
									--
								)	
									TS_est  ON  Y.[object_id] = TS_est.[object_id] 
					--	
					LEFT  JOIN	[' + @Cursor_DatabaseName + '].[sys].[schemas]  S  WITH(NOLOCK)  ON  Y.[schema_id] = S.[schema_id] 
					LEFT  JOIN	(
									SELECT		Rz.[ROUTINE_SCHEMA] 
									,			Rz.[ROUTINE_NAME] 
									-- 
									FROM		[' + @Cursor_DatabaseName 
										+ '].[INFORMATION_SCHEMA].[ROUTINES]  Rz  WITH(NOLOCK) 
									--
									WHERE		Rz.[DATA_TYPE] IS NOT NULL 
									GROUP BY	Rz.[ROUTINE_SCHEMA] 
									,			Rz.[ROUTINE_NAME] 
									--
									HAVING		COUNT(*) = 1 
									--
								)	
									RRV  ON  S.[name] = RRV.[ROUTINE_SCHEMA] 
										 AND Y.[name] = RRV.[ROUTINE_NAME] 
					LEFT  JOIN	[' + @Cursor_DatabaseName + '].[INFORMATION_SCHEMA].[ROUTINES]  R  WITH(NOLOCK) 
										 --
										 ON  RRV.[ROUTINE_SCHEMA] = R.[ROUTINE_SCHEMA] 
										 AND RRV.[ROUTINE_NAME] = R.[ROUTINE_NAME] 
										 AND R.[DATA_TYPE] IS NOT NULL 
					--
					LEFT  JOIN	(
									SELECT	SYNx.[object_id] 
									,		LEFT( MAX(SYNx.[base_object_name]) , 1028 )  as  [base_object_name] 
									-- 
									FROM	[' + @Cursor_DatabaseName + '].[sys].[synonyms]  SYNx  WITH(NOLOCK) 
									-- 
									WHERE	  SYNx.[base_object_name] IS NOT NULL 
									GROUP BY  SYNx.[object_id] 
									HAVING	  COUNT(*) = 1 
								)	
									SYN	 ON  Y.[object_id] = SYN.[object_id] 
					--	
					WHERE	C_S.[schema_id] IS NOT NULL 
					--
					AND		Y.[type_desc] IN 
						( ''' + @sys_object_type_desc_Table + ''' 	
						, ''' + @sys_object_type_desc_View + '''  	
						, ''' + @sys_object_type_desc_UserDefinedTableType + '''  
						, ''' + @sys_object_type_desc_StoredProcedure + '''  
						, ''' + @sys_object_type_desc_TableValuedFunction + '''  
						, ''' + @sys_object_type_desc_TableValuedFunction_INLINE + ''' 	
						, ''' + @sys_object_type_desc_ScalarValuedFunction + ''' 	
						, ''' + @sys_object_type_desc_Synonym + ''' ) 	
					--
					; 

			'

				EXEC ( @SQL ) ; 

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_objects X ) - @RowCount ; 
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( '  rows (sys.objects): ' + convert(varchar(20),@RowCount) ) END ; 
		
			--
			--
			
		/****/	--
		/****/  --	Pull from  sys.all_columns 
		/****/  --	

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_all_columns X )

			SET @SQL = '

				INSERT INTO #Cache_sys_all_columns 
				(
					ScopedDatabaseID	
				--
				--
				,	[object_id]			
				--						
				,	[column_id]			
				,	[name]				
				--
				,	[type_name]	
				,	max_length			
				,	[precision] 		
				,	scale 				
				,	is_nullable 		
				,	is_identity 		
				,	default_object_id 
				-- 
				) 
				
					SELECT	Y.ScopedDatabaseID	
					--
					--
					,		Y.[object_id]			
					--						
					,		Y.[column_id]			
					,		Y.[name]				
					--		
					,		Y.[type_name]	
					,		Y.max_length			
					,		Y.[precision] 		
					,		Y.[scale] 				
					,		Y.is_nullable 		
					,		Y.is_identity 		
					,		Y.default_object_id 
					-- 
					FROM	(
								SELECT  ' + convert(varchar(50),@Cursor_ScopedDatabaseID) + '  as  ScopedDatabaseID 
								--
								--
								,		N.[object_id]			
								--						
								,		N.[column_id]			
								,		N.[name]				
								--		
								,		coalesce(LEFT(Tx.[type_name],20),'''')  as  [type_name]
								,		N.max_length			
								,		N.[precision] 		
								,		N.[scale] 				
								,		N.is_nullable 		
								,		N.is_identity 		
								,		N.default_object_id 
								--
								FROM	[' + @Cursor_DatabaseName + '].[sys].[all_columns]  N  WITH(NOLOCK)  
								-- 
								LEFT  JOIN  ( SELECT	Txs.[system_type_id] 
											  ,			Txs.[user_type_id] 
											  ,			MAX(Txs.[name])		as  [type_name] 
											  -- 
											  FROM [' + @Cursor_DatabaseName + '].[sys].[types]  Txs  WITH(NOLOCK) 
											  --
											  WHERE		Txs.[name] IS NOT NULL 
											  --
											  GROUP BY  Txs.[system_type_id] 
											  ,			Txs.[user_type_id] 
											  -- 
											) 
												Tx	ON  N.[system_type_id] = Tx.[system_type_id] 
													AND N.[user_type_id] = Tx.[user_type_id] 
								--
								WHERE	LEN(N.[name]) BETWEEN 1 AND 256 
								AND		N.[object_id] IS NOT NULL 
								AND		try_convert(bigint,N.[column_id]) > 0 
								--
							)
								Y	INNER JOIN  #Cache_sys_objects  C_O  ON  Y.ScopedDatabaseID = C_O.ScopedDatabaseID 
																		 AND Y.[object_id] = C_O.[object_id] 
					--
					; 

			'

				EXEC ( @SQL ) ; 

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_all_columns X ) - @RowCount ; 
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( '  rows (sys.all_columns): ' + convert(varchar(20),@RowCount) ) END ; 
		
			--
			--
			
		/****/	--
		/****/  --	Pull from  sys.all_parameters 
		/****/  --	

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_all_parameters X )

			SET @SQL = '

				INSERT INTO #Cache_sys_all_parameters 
				(
					ScopedDatabaseID	
				--
				--
				,	[object_id]			
				--						
				,	[parameter_id]			
				,	[name]				
				--
				,	[type_name]	
				,	max_length			
				,	[precision] 		
				,	scale 				
				,	is_output 			
				,	has_default_value   
				,	is_readonly		
				-- 
				) 
				
					SELECT	Y.ScopedDatabaseID	
					--
					--
					,		Y.[object_id]			
					--						
					,		Y.[parameter_id]			
					,		Y.[name]				
					--		
					,		Y.[type_name]	
					,		Y.max_length			
					,		Y.[precision] 		
					,		Y.[scale] 				
					,		Y.is_output 			
					,		Y.has_default_value   
					,		Y.is_readonly		
					-- 
					FROM	(
								SELECT  ' + convert(varchar(50),@Cursor_ScopedDatabaseID) + '  as  ScopedDatabaseID 
								--
								--
								,		P.[object_id]			
								--						
								,		P.[parameter_id]			
								,		P.[name]				
								--		
								,		coalesce(LEFT(Tx.[type_name],20),'''')  as  [type_name]
								,		P.max_length			
								,		P.[precision] 		
								,		P.[scale] 				
								,		P.is_output 		
								,		P.has_default_value 		
								,		P.is_readonly 
								--
								FROM	[' + @Cursor_DatabaseName + '].[sys].[all_parameters]  P  WITH(NOLOCK)  
								-- 
								LEFT  JOIN  ( SELECT	Txs.[system_type_id] 
											  ,			Txs.[user_type_id] 
											  ,			MAX(CASE WHEN Txs.[is_table_type] = 1 
																 THEN ''TABLE'' 
																 ELSE Txs.[name]
															END)  as  [type_name] 
											  -- 
											  FROM [' + @Cursor_DatabaseName + '].[sys].[types]  Txs  WITH(NOLOCK) 
											  --
											  WHERE		Txs.[name] IS NOT NULL 
											  --
											  GROUP BY  Txs.[system_type_id] 
											  ,			Txs.[user_type_id] 
											  -- 
											) 
												Tx	ON  P.[system_type_id] = Tx.[system_type_id] 
													AND P.[user_type_id] = Tx.[user_type_id] 
								--
								WHERE	LEN(P.[name]) BETWEEN 1 AND 256 
								AND		P.[object_id] IS NOT NULL 
								AND		try_convert(bigint,P.[parameter_id]) > 0 
								--
							)
								Y	INNER JOIN  #Cache_sys_objects  C_O  ON  Y.ScopedDatabaseID = C_O.ScopedDatabaseID 
																		 AND Y.[object_id] = C_O.[object_id] 
					--
					; 

			'

				EXEC ( @SQL ) ; 

			SET @RowCount = ( SELECT COUNT(*) FROM #Cache_sys_all_parameters X ) - @RowCount ; 
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( '  rows (sys.all_parameters): ' + convert(varchar(20),@RowCount) ) END ; 
		
			--
			--

		END TRY 
		BEGIN CATCH 

			SET @ErrorMessage = 'An error was encountered while gathering [sys] / [INFORMATION_SCHEMA] content for database: [' + @Cursor_DatabaseName + '].' 
			GOTO ERROR 

		END CATCH	
		
		--
		--

	END 
	
	CLOSE #C_loop_ScopedDatabase 
	DEALLOCATE #C_loop_ScopedDatabase 

	--
	--
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #DatabaseRole.' ) END ; 

		INSERT INTO #DatabaseRole -- 1a 
		(
			ScopedDatabaseID			
		,	RoleName					
		--
		,	Est_CreationTimestamp			
		,	Est_LastModifiedTimestamp		
		--
		)	SELECT	X.ScopedDatabaseID 	as  ScopedDatabaseID			
			,		X.[name] 			as  RoleName					
			--	
			,		X.create_date 		as  Est_CreationTimestamp		
			,		X.modify_date		as  Est_LastModifiedTimestamp	
			--
			FROM	#Cache_sys_database_principals	 X  
			-- 
			ORDER BY  X.ScopedDatabaseID 
			,		  X.[name] 
			-- 
			;	
		
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #DatabaseSchema.' ) END ; 

		INSERT INTO #DatabaseSchema -- 1b 
		(
			ScopedDatabaseID		
		,	SchemaName				
		--
		)	SELECT	X.ScopedDatabaseID 	as  ScopedDatabaseID			
			,		X.[name] 			as  RoleName					
			--
			FROM	#Cache_sys_schemas	 X  
			-- 
			ORDER BY  X.ScopedDatabaseID 
			,		  X.[name] 
			--
			;	
	
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--
		
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #TupleStructure.' ) END ; 

		INSERT INTO #TupleStructure -- 2a 
		(
			internalTemp_DatabaseSchemaID		
		,	ObjectName							
		,	TupleStructureTypeID		
		--
		,	Est_CreationTimestamp		
		,	Est_LastModifiedTimestamp	
		--
		,	LatestSizeUpdateTimestamp 
		,	LatestRowCount
		,	LatestTotalSpaceKB
		--
		)	SELECT	S.ID 			as  internalTemp_DatabaseSchemaID			
			,		X.[name] 		as  ObjectName			
			,		T.ID			as	TupleStructureTypeID		
			--
			,		X.create_date	as	Est_CreationTimestamp		
			,		X.modify_date	as	Est_LastModifiedTimestamp	
			--
			,		X.TABLE_SizeTimestamp 	 as  LatestSizeUpdateTimestamp 
			,		X.TABLE_RowCount		 as  LatestRowCount
			,		X.TABLE_TotalSpaceKB	 as  LatestTotalSpaceKB
			--
			FROM	#Cache_sys_objects	 X  
			--
			INNER JOIN (
						  VALUES ( @sys_object_type_desc_Table , @TupleStructureType_CodeName_Table ) 
						  ,		 ( @sys_object_type_desc_View , @TupleStructureType_CodeName_View ) 
						  ,		 ( @sys_object_type_desc_UserDefinedTableType , @TupleStructureType_CodeName_UserDefinedTableType ) 
					   ) 
						  M  ( [type_desc] , CodeName )  ON  X.[type_desc] = M.[type_desc] 
			--
			INNER JOIN dbocatalogue.TupleStructureType  T  ON  M.CodeName = T.CodeName 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  X.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND X.[schema_id] = Y.[schema_id] 
			--	
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			--
			ORDER BY  S.ID 
			,		  T.ID 
			,		  X.[name] 
			-- 
			;	
	
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #TupleStructureColumn.' ) END ; 

		INSERT INTO #TupleStructureColumn -- 2b 
		(
			internalTemp_TupleStructureID	
		,	ColumnName						
		,	OrdinalNumber					
		--
		,	DataType_Name					
		,	DataType_MaxLength				
		,	DataType_Precision				
		,	DataType_Scale					
		,	IsNullable						
		,	IsIdentity					
		,	HasDefaultValue				
		--
		)	SELECT	T.ID 			as  internalTemp_TupleStructureID			
			,		X.[name] 		as  ColumnName			
			,		X.[column_id]	as	OrdinalNumber		
			--
			,		X.[type_name]	as  DataType_Name  
			,		X.max_length	as  DataType_MaxLength	
			,		X.[precision] 	as  DataType_Precision	
			,		X.scale 		as  DataType_Scale	
			,		X.is_nullable 	as  IsNullable	
			,		X.is_identity 	as  IsIdentity	
			,		CASE WHEN X.default_object_id != 0 
						 THEN 1 
						 ELSE 0 
					END				as  HasDefaultValue	
			--
			FROM		#Cache_sys_all_columns	 X  
			INNER JOIN	#Cache_sys_objects		 O  ON  X.ScopedDatabaseID = O.ScopedDatabaseID 
													AND X.[object_id] = O.[object_id] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  O.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND O.[schema_id] = Y.[schema_id] 
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			INNER JOIN #TupleStructure	    T  ON  S.ID = T.internalTemp_DatabaseSchemaID 
											   AND O.[name] = T.ObjectName 
			--
			ORDER BY	T.ID			ASC 
			,			X.[column_id]	ASC		
			--	
			;	

	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #ScalarValuedFunction.' ) END ; 

		INSERT INTO #ScalarValuedFunction -- 3a 
		(
			internalTemp_DatabaseSchemaID	
		,	ObjectName						
		--
		,	ReturnValue_DataType_Name		
		,	ReturnValue_DataType_MaxLength	
		,	ReturnValue_DataType_Precision	
		,	ReturnValue_DataType_Scale		
		--
		,	Est_CreationTimestamp		
		,	Est_LastModifiedTimestamp	
		--
		)	SELECT	S.ID 			as  internalTemp_DatabaseSchemaID			
			,		X.[name] 		as  ObjectName			
			--
			,		X.ROUTINE_ReturnValue_DataType_Name		   as  	ReturnValue_DataType_Name		
			,		X.ROUTINE_ReturnValue_DataType_MaxLength   as  	ReturnValue_DataType_MaxLength	
			,		X.ROUTINE_ReturnValue_DataType_Precision   as  	ReturnValue_DataType_Precision	
			,		X.ROUTINE_ReturnValue_DataType_Scale	   as  	ReturnValue_DataType_Scale		
			--
			,		X.create_date	as	Est_CreationTimestamp		
			,		X.modify_date	as	Est_LastModifiedTimestamp	
			--
			FROM	#Cache_sys_objects	 X  
			--
			INNER JOIN (
						  VALUES ( @sys_object_type_desc_ScalarValuedFunction ) 
					   ) 
						  M  ( [type_desc] )  ON  X.[type_desc] = M.[type_desc] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  X.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND X.[schema_id] = Y.[schema_id] 
			--	
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			--
			ORDER BY  S.ID 
			,		  X.[name] 
			-- 
			;	
	
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #ScalarValuedFunctionParameter.' ) END ; 

		INSERT INTO #ScalarValuedFunctionParameter -- 3b 
		(
			internalTemp_ScalarValuedFunctionID		
		,	ParameterName							
		,	OrdinalNumber							
		--
		,	DataType_Name			
		,	DataType_MaxLength		
		,	DataType_Precision		
		,	DataType_Scale			
		,	HasDefaultValue			
		,	IsOutput				
		,	IsReadOnly				
		--
		)	SELECT	F.ID 				as  internalTemp_ScalarValuedFunctionID			
			,		X.[name] 			as  ParameterName			
			,		X.[parameter_id]	as	OrdinalNumber		
			--
			,		X.[type_name]			as  DataType_Name  
			,		X.max_length			as  DataType_MaxLength	
			,		X.[precision] 			as  DataType_Precision	
			,		X.scale 				as  DataType_Scale	
			,		X.has_default_value		as  HasDefaultValue	
			,		X.is_output 			as  IsOutput	
			,		X.is_readonly			as  IsReadOnly	
			--
			FROM		#Cache_sys_all_parameters	 X  
			INNER JOIN	#Cache_sys_objects			 O  ON  X.ScopedDatabaseID = O.ScopedDatabaseID 
														AND X.[object_id] = O.[object_id] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  O.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND O.[schema_id] = Y.[schema_id] 
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			INNER JOIN #ScalarValuedFunction  F  ON  S.ID = F.internalTemp_DatabaseSchemaID 
											     AND O.[name] = F.ObjectName 
			--
			ORDER BY	F.ID				ASC 
			,			X.[parameter_id]	ASC		
			--	
			;	
	
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #TableValuedFunction.' ) END ; 

		INSERT INTO #TableValuedFunction -- 4a 
		(
			internalTemp_DatabaseSchemaID		
		,	ObjectName					
		--
		,	Est_CreationTimestamp		
		,	Est_LastModifiedTimestamp	
		--
		,	IsInline 
		--
		)	SELECT	S.ID 			as  internalTemp_DatabaseSchemaID			
			,		X.[name] 		as  ObjectName			
			--
			,		X.create_date	as	Est_CreationTimestamp		
			,		X.modify_date	as	Est_LastModifiedTimestamp	
			--
			,		M.IsInline		as	IsInline 
			--
			FROM	#Cache_sys_objects	 X  
			--
			INNER JOIN (
						  VALUES ( @sys_object_type_desc_TableValuedFunction		, 0 ) 
						  ,		 ( @sys_object_type_desc_TableValuedFunction_INLINE , 1 ) 
					   ) 
						  M  ( [type_desc] , IsInline )  ON  X.[type_desc] = M.[type_desc] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  X.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND X.[schema_id] = Y.[schema_id] 
			--	
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			--
			ORDER BY  S.ID 
			,		  X.[name] 
			-- 
			;	
	
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #TableValuedFunctionParameter.' ) END ; 

		INSERT INTO #TableValuedFunctionParameter -- 4b 
		(
			internalTemp_TableValuedFunctionID		
		,	ParameterName							
		,	OrdinalNumber							
		--
		,	DataType_Name			
		,	DataType_MaxLength		
		,	DataType_Precision		
		,	DataType_Scale			
		,	HasDefaultValue			
		,	IsOutput				
		,	IsReadOnly				
		--
		)	SELECT	F.ID 				as  internalTemp_TableValuedFunctionID			
			,		X.[name] 			as  ParameterName			
			,		X.[parameter_id]	as	OrdinalNumber		
			--
			,		X.[type_name]			as  DataType_Name  
			,		X.max_length			as  DataType_MaxLength	
			,		X.[precision] 			as  DataType_Precision	
			,		X.scale 				as  DataType_Scale	
			,		X.has_default_value		as  HasDefaultValue	
			,		X.is_output 			as  IsOutput	
			,		X.is_readonly			as  IsReadOnly	
			--
			FROM		#Cache_sys_all_parameters	 X  
			INNER JOIN	#Cache_sys_objects			 O  ON  X.ScopedDatabaseID = O.ScopedDatabaseID 
														AND X.[object_id] = O.[object_id] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  O.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND O.[schema_id] = Y.[schema_id] 
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			INNER JOIN #TableValuedFunction   F  ON  S.ID = F.internalTemp_DatabaseSchemaID 
											     AND O.[name] = F.ObjectName 
			--
			ORDER BY	F.ID				ASC 
			,			X.[parameter_id]	ASC		
			--	
			;	
	
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #TableValuedFunctionColumn.' ) END ; 

		INSERT INTO #TableValuedFunctionColumn -- 4c 
		(
			internalTemp_TableValuedFunctionID		
		,	ColumnName								
		,	OrdinalNumber							
		--
		,	DataType_Name			
		,	DataType_MaxLength		
		,	DataType_Precision		
		,	DataType_Scale			
		,	IsNullable				
		,	IsIdentity				
		,	HasDefaultValue			
		--
		)	SELECT	T.ID 			as  internalTemp_TupleStructureID			
			,		X.[name] 		as  ColumnName			
			,		X.[column_id]	as	OrdinalNumber		
			--
			,		X.[type_name]	as  DataType_Name  
			,		X.max_length	as  DataType_MaxLength	
			,		X.[precision] 	as  DataType_Precision	
			,		X.scale 		as  DataType_Scale	
			,		X.is_nullable 	as  IsNullable	
			,		X.is_identity 	as  IsIdentity	
			,		CASE WHEN X.default_object_id != 0 
						 THEN 1 
						 ELSE 0 
					END				as  HasDefaultValue	
			--
			FROM		#Cache_sys_all_columns	 X  
			INNER JOIN	#Cache_sys_objects		 O  ON  X.ScopedDatabaseID = O.ScopedDatabaseID 
													AND X.[object_id] = O.[object_id] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  O.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND O.[schema_id] = Y.[schema_id] 
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			INNER JOIN #TableValuedFunction	 T  ON  S.ID = T.internalTemp_DatabaseSchemaID 
											    AND O.[name] = T.ObjectName 
			--
			ORDER BY	T.ID			ASC		
			,			X.[column_id]	ASC		
			--	
			;	
		
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #StoredProcedure.' ) END ; 

		INSERT INTO #StoredProcedure -- 5a 
		(
			internalTemp_DatabaseSchemaID	
		,	ObjectName						
		--
		,	Est_CreationTimestamp		
		,	Est_LastModifiedTimestamp	
		--
		)	SELECT	S.ID 			as  internalTemp_DatabaseSchemaID	
			,		X.[name] 		as  ObjectName			
			--
			,		X.create_date	as	Est_CreationTimestamp		
			,		X.modify_date	as	Est_LastModifiedTimestamp	
			--
			FROM	#Cache_sys_objects	 X  
			--
			INNER JOIN (
						  VALUES ( @sys_object_type_desc_StoredProcedure ) 
					   ) 
						  M  ( [type_desc] )  ON  X.[type_desc] = M.[type_desc] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  X.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND X.[schema_id] = Y.[schema_id] 
			--	
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			--
			ORDER BY  S.ID 
			,		  X.[name] 
			-- 
			;	
	
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #StoredProcedureParameter.' ) END ; 

		INSERT INTO #StoredProcedureParameter -- 5b 
		(
			internalTemp_StoredProcedureID		
		,	ParameterName						
		,	OrdinalNumber						
		--
		,	DataType_Name			
		,	DataType_MaxLength		
		,	DataType_Precision		
		,	DataType_Scale			
		,	HasDefaultValue			
		,	IsOutput				
		,	IsReadOnly				
		--
		)	SELECT	F.ID 				as  internalTemp_StoredProcedureID			
			,		X.[name] 			as  ParameterName			
			,		X.[parameter_id]	as	OrdinalNumber		
			--
			,		X.[type_name]			as  DataType_Name  
			,		X.max_length			as  DataType_MaxLength	
			,		X.[precision] 			as  DataType_Precision	
			,		X.scale 				as  DataType_Scale	
			,		X.has_default_value		as  HasDefaultValue	
			,		X.is_output 			as  IsOutput	
			,		X.is_readonly			as  IsReadOnly	
			--
			FROM		#Cache_sys_all_parameters	 X  
			INNER JOIN	#Cache_sys_objects			 O  ON  X.ScopedDatabaseID = O.ScopedDatabaseID 
														AND X.[object_id] = O.[object_id] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  O.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND O.[schema_id] = Y.[schema_id] 
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			INNER JOIN #StoredProcedure   F  ON  S.ID = F.internalTemp_DatabaseSchemaID 
											 AND O.[name] = F.ObjectName 
			--
			ORDER BY	F.ID				ASC 
			,			X.[parameter_id]	ASC		
			--	
			;	
		
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Populate #SynonymAlias.' ) END ; 

		INSERT INTO #SynonymAlias -- 6a 
		(
			internalTemp_DatabaseSchemaID	
		,	ObjectName						
		--
		,	Target_ServerName		
		,	Target_DatabaseName		
		,	Target_SchemaName		
		,	Target_ObjectName		
		--
		,	Est_CreationTimestamp		
		,	Est_LastModifiedTimestamp	
		--
		)	SELECT	S.ID 			as  internalTemp_DatabaseSchemaID	
			,		X.[name] 		as  ObjectName			
			--
			,		PARSENAME(X.SYNONYM_base_object_name,4)  as  Target_ServerName
			,		PARSENAME(X.SYNONYM_base_object_name,3)  as  Target_DatabaseName	
			,		PARSENAME(X.SYNONYM_base_object_name,2)  as  Target_SchemaName	
			,		PARSENAME(X.SYNONYM_base_object_name,1)  as  Target_ObjectName	
			--
			,		X.create_date	as	Est_CreationTimestamp		
			,		X.modify_date	as	Est_LastModifiedTimestamp	
			--
			FROM	#Cache_sys_objects	 X  
			--
			INNER JOIN (
						  VALUES ( @sys_object_type_desc_Synonym ) 
					   ) 
						  M  ( [type_desc] )  ON  X.[type_desc] = M.[type_desc] 
			--
			INNER JOIN #Cache_sys_schemas	Y  ON  X.ScopedDatabaseID = Y.ScopedDatabaseID 
											   AND X.[schema_id] = Y.[schema_id] 
			--	
			INNER JOIN #DatabaseSchema		S  ON  X.ScopedDatabaseID = S.ScopedDatabaseID 
											   AND Y.[name] = S.SchemaName 
			--
			ORDER BY  S.ID 
			,		  X.[name] 
			-- 
			;	
		
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--
	--
	--
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Compare latest object lists to existing persistent records.' ) END ; 
	
	BEGIN TRY 
		--
		--  [dbocatalogue].[DatabaseRole] -- 1a  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.Est_CreationTimestamp != Y.Est_CreationTimestamp 
												   OR   ( X.Est_CreationTimestamp IS NULL AND Y.Est_CreationTimestamp IS NOT NULL ) 
												   OR   ( X.Est_CreationTimestamp IS NOT NULL AND Y.Est_CreationTimestamp IS NULL ) 
												   OR   X.Est_LastModifiedTimestamp != Y.Est_LastModifiedTimestamp 
												   OR   ( X.Est_LastModifiedTimestamp IS NULL AND Y.Est_LastModifiedTimestamp IS NOT NULL ) 
												   OR   ( X.Est_LastModifiedTimestamp IS NOT NULL AND Y.Est_LastModifiedTimestamp IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #DatabaseRole              X	
		INNER JOIN  dbocatalogue.DatabaseRole  Y  ON  X.ScopedDatabaseID = Y.ScopedDatabaseID 
												  AND X.RoleName = Y.RoleName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID ) 
			SELECT  'dbocatalogue.DatabaseRole' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID] 
			,		SD.ID as ScopedDatabaseID , null as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseRole  Z  ON  SD.ID = Z.ScopedDatabaseID 
			LEFT  JOIN	#DatabaseRole			   X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [DatabaseRole] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 

	--
	--
	
	BEGIN TRY 
		--
		--  [dbocatalogue].[DatabaseSchema] -- 1b  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = 0  --  irrelevant for schema records as of 2020-09-26 
		,			X.ObjectListChangeDetected = null  --  update later after comparing records in other tables 
		--
		FROM        #DatabaseSchema              X	
		INNER JOIN  dbocatalogue.DatabaseSchema  Y  ON  X.ScopedDatabaseID = Y.ScopedDatabaseID 
												    AND X.SchemaName = Y.SchemaName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID ) 
			SELECT  'dbocatalogue.DatabaseSchema' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID] 
			,		SD.ID as ScopedDatabaseID , null as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  Z  ON  SD.ID = Z.ScopedDatabaseID 
			LEFT  JOIN	#DatabaseSchema              X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [DatabaseSchema] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 

	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[TupleStructure] -- 2a  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.TupleStructureTypeID != Y.TupleStructureTypeID 
												   OR   X.Est_CreationTimestamp != Y.Est_CreationTimestamp 
												   OR ( X.Est_CreationTimestamp IS NULL AND Y.Est_CreationTimestamp IS NOT NULL ) 
												   OR ( X.Est_CreationTimestamp IS NOT NULL AND Y.Est_CreationTimestamp IS NULL ) 
												   OR   X.Est_LastModifiedTimestamp != Y.Est_LastModifiedTimestamp 
												   OR ( X.Est_LastModifiedTimestamp IS NULL AND Y.Est_LastModifiedTimestamp IS NOT NULL ) 
												   OR ( X.Est_LastModifiedTimestamp IS NOT NULL AND Y.Est_LastModifiedTimestamp IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		,			X.UpdateSizeFieldValues = CASE WHEN @UpdateSizeEstimates = 1 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #TupleStructure  X  
		INNER JOIN	#DatabaseSchema	 T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.TupleStructure  Y  ON  S.ID = Y.DatabaseSchemaID 
												    AND X.ObjectName = Y.ObjectName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID ) 
			SELECT  'dbocatalogue.TupleStructure' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID] 
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.TupleStructure  Z  ON  S.ID = Z.DatabaseSchemaID 
			LEFT  JOIN	#TupleStructure  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [TupleStructure] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 

	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[TupleStructureColumn] -- 2b  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.OrdinalNumber != Y.OrdinalNumber 
												   OR   X.DataType_Name != Y.DataType_Name 
												   OR ( X.DataType_Name IS NULL AND Y.DataType_Name IS NOT NULL ) 
												   OR ( X.DataType_Name IS NOT NULL AND Y.DataType_Name IS NULL ) 
												   OR   X.DataType_MaxLength != Y.DataType_MaxLength 
												   OR ( X.DataType_MaxLength IS NULL AND Y.DataType_MaxLength IS NOT NULL ) 
												   OR ( X.DataType_MaxLength IS NOT NULL AND Y.DataType_MaxLength IS NULL ) 
												   OR   X.DataType_Precision != Y.DataType_Precision 
												   OR ( X.DataType_Precision IS NULL AND Y.DataType_Precision IS NOT NULL ) 
												   OR ( X.DataType_Precision IS NOT NULL AND Y.DataType_Precision IS NULL ) 
												   OR   X.DataType_Scale != Y.DataType_Scale 
												   OR ( X.DataType_Scale IS NULL AND Y.DataType_Scale IS NOT NULL ) 
												   OR ( X.DataType_Scale IS NOT NULL AND Y.DataType_Scale IS NULL ) 
												   OR   X.IsNullable != Y.IsNullable 
												   OR ( X.IsNullable IS NULL AND Y.IsNullable IS NOT NULL ) 
												   OR ( X.IsNullable IS NOT NULL AND Y.IsNullable IS NULL ) 
												   OR   X.IsIdentity != Y.IsIdentity 
												   OR ( X.IsIdentity IS NULL AND Y.IsIdentity IS NOT NULL ) 
												   OR ( X.IsIdentity IS NOT NULL AND Y.IsIdentity IS NULL ) 
												   OR   X.HasDefaultValue != Y.HasDefaultValue 
												   OR ( X.HasDefaultValue IS NULL AND Y.HasDefaultValue IS NOT NULL ) 
												   OR ( X.HasDefaultValue IS NOT NULL AND Y.HasDefaultValue IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #TupleStructureColumn  X  
		INNER JOIN	#TupleStructure  T_TS  ON  X.internalTemp_TupleStructureID = T_TS.ID 
		INNER JOIN	#DatabaseSchema	 T_S  ON  T_TS.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.TupleStructure  TS ON  S.ID = TS.DatabaseSchemaID 
												    AND T_TS.ObjectName = TS.ObjectName 
		INNER JOIN	dbocatalogue.TupleStructureColumn  Y  ON  TS.ID = Y.TupleStructureID 
														  AND X.ColumnName = Y.ColumnName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID ) 
			SELECT  'dbocatalogue.TupleStructureColumn' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID] 
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.TupleStructure  TS ON  S.ID = TS.DatabaseSchemaID 
			INNER JOIN  dbocatalogue.TupleStructureColumn  Z  ON  TS.ID = Z.TupleStructureID  
			LEFT  JOIN	#TupleStructureColumn  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [TupleStructureColumn] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[ScalarValuedFunction] -- 3a  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.ReturnValue_DataType_Name != Y.ReturnValue_DataType_Name 
												   OR ( X.ReturnValue_DataType_Name IS NULL AND Y.ReturnValue_DataType_Name IS NOT NULL ) 
												   OR ( X.ReturnValue_DataType_Name IS NOT NULL AND Y.ReturnValue_DataType_Name IS NULL )
												   OR   X.ReturnValue_DataType_MaxLength != Y.ReturnValue_DataType_MaxLength 
												   OR ( X.ReturnValue_DataType_MaxLength IS NULL AND Y.ReturnValue_DataType_MaxLength IS NOT NULL ) 
												   OR ( X.ReturnValue_DataType_MaxLength IS NOT NULL AND Y.ReturnValue_DataType_MaxLength IS NULL ) 
												   OR   X.ReturnValue_DataType_Precision != Y.ReturnValue_DataType_Precision 
												   OR ( X.ReturnValue_DataType_Precision IS NULL AND Y.ReturnValue_DataType_Precision IS NOT NULL ) 
												   OR ( X.ReturnValue_DataType_Precision IS NOT NULL AND Y.ReturnValue_DataType_Precision IS NULL ) 
												   OR   X.ReturnValue_DataType_Scale != Y.ReturnValue_DataType_Scale 
												   OR ( X.ReturnValue_DataType_Scale IS NULL AND Y.ReturnValue_DataType_Scale IS NOT NULL ) 
												   OR ( X.ReturnValue_DataType_Scale IS NOT NULL AND Y.ReturnValue_DataType_Scale IS NULL ) 
												   OR   X.Est_CreationTimestamp != Y.Est_CreationTimestamp 
												   OR ( X.Est_CreationTimestamp IS NULL AND Y.Est_CreationTimestamp IS NOT NULL ) 
												   OR ( X.Est_CreationTimestamp IS NOT NULL AND Y.Est_CreationTimestamp IS NULL ) 
												   OR   X.Est_LastModifiedTimestamp != Y.Est_LastModifiedTimestamp 
												   OR ( X.Est_LastModifiedTimestamp IS NULL AND Y.Est_LastModifiedTimestamp IS NOT NULL ) 
												   OR ( X.Est_LastModifiedTimestamp IS NOT NULL AND Y.Est_LastModifiedTimestamp IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #ScalarValuedFunction  X  
		INNER JOIN	#DatabaseSchema	 T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.ScalarValuedFunction  Y  ON  S.ID = Y.DatabaseSchemaID 
												          AND X.ObjectName = Y.ObjectName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID ) 
			SELECT  'dbocatalogue.ScalarValuedFunction' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID] 
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.ScalarValuedFunction  Z  ON  S.ID = Z.DatabaseSchemaID 
			LEFT  JOIN	#ScalarValuedFunction  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [ScalarValuedFunction] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 

	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[ScalarValuedFunctionParameter] -- 3b  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.OrdinalNumber != Y.OrdinalNumber 
												   OR   X.DataType_Name != Y.DataType_Name 
												   OR ( X.DataType_Name IS NULL AND Y.DataType_Name IS NOT NULL ) 
												   OR ( X.DataType_Name IS NOT NULL AND Y.DataType_Name IS NULL ) 
												   OR   X.DataType_MaxLength != Y.DataType_MaxLength 
												   OR ( X.DataType_MaxLength IS NULL AND Y.DataType_MaxLength IS NOT NULL ) 
												   OR ( X.DataType_MaxLength IS NOT NULL AND Y.DataType_MaxLength IS NULL ) 
												   OR   X.DataType_Precision != Y.DataType_Precision 
												   OR ( X.DataType_Precision IS NULL AND Y.DataType_Precision IS NOT NULL ) 
												   OR ( X.DataType_Precision IS NOT NULL AND Y.DataType_Precision IS NULL ) 
												   OR   X.DataType_Scale != Y.DataType_Scale 
												   OR ( X.DataType_Scale IS NULL AND Y.DataType_Scale IS NOT NULL ) 
												   OR ( X.DataType_Scale IS NOT NULL AND Y.DataType_Scale IS NULL ) 
												   OR   X.HasDefaultValue != Y.HasDefaultValue 
												   OR ( X.HasDefaultValue IS NULL AND Y.HasDefaultValue IS NOT NULL ) 
												   OR ( X.HasDefaultValue IS NOT NULL AND Y.HasDefaultValue IS NULL ) 
												   OR   X.IsOutput != Y.IsOutput 
												   OR ( X.IsOutput IS NULL AND Y.IsOutput IS NOT NULL ) 
												   OR ( X.IsOutput IS NOT NULL AND Y.IsOutput IS NULL ) 
												   OR   X.IsReadOnly != Y.IsReadOnly 
												   OR ( X.IsReadOnly IS NULL AND Y.IsReadOnly IS NOT NULL ) 
												   OR ( X.IsReadOnly IS NOT NULL AND Y.IsReadOnly IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #ScalarValuedFunctionParameter  X  
		INNER JOIN	#ScalarValuedFunction  T_SVF  ON  X.internalTemp_ScalarValuedFunctionID = T_SVF.ID 
		INNER JOIN	#DatabaseSchema	 T_S  ON  T_SVF.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.ScalarValuedFunction SVF ON  S.ID = SVF.DatabaseSchemaID 
												          AND T_SVF.ObjectName = SVF.ObjectName 
		INNER JOIN	dbocatalogue.ScalarValuedFunctionParameter  Y  ON  SVF.ID = Y.ScalarValuedFunctionID 
														           AND X.ParameterName = Y.ParameterName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID ) 
			SELECT  'dbocatalogue.ScalarValuedFunctionParameter' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID]
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.ScalarValuedFunction SVF ON  S.ID = SVF.DatabaseSchemaID 
			INNER JOIN  dbocatalogue.ScalarValuedFunctionParameter  Z  ON  SVF.ID = Z.ScalarValuedFunctionID  
			LEFT  JOIN	#ScalarValuedFunctionParameter  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [ScalarValuedFunctionParameter] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[TableValuedFunction] -- 4a  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.Est_CreationTimestamp != Y.Est_CreationTimestamp 
												   OR ( X.Est_CreationTimestamp IS NULL AND Y.Est_CreationTimestamp IS NOT NULL ) 
												   OR ( X.Est_CreationTimestamp IS NOT NULL AND Y.Est_CreationTimestamp IS NULL ) 
												   OR   X.Est_LastModifiedTimestamp != Y.Est_LastModifiedTimestamp 
												   OR ( X.Est_LastModifiedTimestamp IS NULL AND Y.Est_LastModifiedTimestamp IS NOT NULL ) 
												   OR ( X.Est_LastModifiedTimestamp IS NOT NULL AND Y.Est_LastModifiedTimestamp IS NULL ) 
												   OR   X.IsInline != Y.IsInline 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #TableValuedFunction  X  
		INNER JOIN	#DatabaseSchema	 T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.TableValuedFunction  Y  ON  S.ID = Y.DatabaseSchemaID 
												         AND X.ObjectName = Y.ObjectName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID )  
			SELECT  'dbocatalogue.TableValuedFunction' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID]
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.TableValuedFunction  Z  ON  S.ID = Z.DatabaseSchemaID 
			LEFT  JOIN	#TableValuedFunction  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [TableValuedFunction] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[TableValuedFunctionParameter] -- 4b  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.OrdinalNumber != Y.OrdinalNumber 
												   OR   X.DataType_Name != Y.DataType_Name 
												   OR ( X.DataType_Name IS NULL AND Y.DataType_Name IS NOT NULL ) 
												   OR ( X.DataType_Name IS NOT NULL AND Y.DataType_Name IS NULL ) 
												   OR   X.DataType_MaxLength != Y.DataType_MaxLength 
												   OR ( X.DataType_MaxLength IS NULL AND Y.DataType_MaxLength IS NOT NULL ) 
												   OR ( X.DataType_MaxLength IS NOT NULL AND Y.DataType_MaxLength IS NULL ) 
												   OR   X.DataType_Precision != Y.DataType_Precision 
												   OR ( X.DataType_Precision IS NULL AND Y.DataType_Precision IS NOT NULL ) 
												   OR ( X.DataType_Precision IS NOT NULL AND Y.DataType_Precision IS NULL ) 
												   OR   X.DataType_Scale != Y.DataType_Scale 
												   OR ( X.DataType_Scale IS NULL AND Y.DataType_Scale IS NOT NULL ) 
												   OR ( X.DataType_Scale IS NOT NULL AND Y.DataType_Scale IS NULL ) 
												   OR   X.HasDefaultValue != Y.HasDefaultValue 
												   OR ( X.HasDefaultValue IS NULL AND Y.HasDefaultValue IS NOT NULL ) 
												   OR ( X.HasDefaultValue IS NOT NULL AND Y.HasDefaultValue IS NULL ) 
												   OR   X.IsOutput != Y.IsOutput 
												   OR ( X.IsOutput IS NULL AND Y.IsOutput IS NOT NULL ) 
												   OR ( X.IsOutput IS NOT NULL AND Y.IsOutput IS NULL ) 
												   OR   X.IsReadOnly != Y.IsReadOnly 
												   OR ( X.IsReadOnly IS NULL AND Y.IsReadOnly IS NOT NULL ) 
												   OR ( X.IsReadOnly IS NOT NULL AND Y.IsReadOnly IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #TableValuedFunctionParameter  X  
		INNER JOIN	#TableValuedFunction  T_TVF  ON  X.internalTemp_TableValuedFunctionID = T_TVF.ID 
		INNER JOIN	#DatabaseSchema	 T_S  ON  T_TVF.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.TableValuedFunction TVF ON  S.ID = TVF.DatabaseSchemaID 
												         AND T_TVF.ObjectName = TVF.ObjectName 
		INNER JOIN	dbocatalogue.TableValuedFunctionParameter  Y  ON  TVF.ID = Y.TableValuedFunctionID 
														          AND X.ParameterName = Y.ParameterName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID )  
			SELECT  'dbocatalogue.TableValuedFunctionParameter' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID]
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.TableValuedFunction TVF ON  S.ID = TVF.DatabaseSchemaID 
			INNER JOIN  dbocatalogue.TableValuedFunctionParameter  Z  ON  TVF.ID = Z.TableValuedFunctionID  
			LEFT  JOIN	#TableValuedFunctionParameter  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [TableValuedFunctionParameter] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[TableValuedFunctionColumn] -- 4c   
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.OrdinalNumber != Y.OrdinalNumber 
												   OR   X.DataType_Name != Y.DataType_Name 
												   OR ( X.DataType_Name IS NULL AND Y.DataType_Name IS NOT NULL ) 
												   OR ( X.DataType_Name IS NOT NULL AND Y.DataType_Name IS NULL ) 
												   OR   X.DataType_MaxLength != Y.DataType_MaxLength 
												   OR ( X.DataType_MaxLength IS NULL AND Y.DataType_MaxLength IS NOT NULL ) 
												   OR ( X.DataType_MaxLength IS NOT NULL AND Y.DataType_MaxLength IS NULL ) 
												   OR   X.DataType_Precision != Y.DataType_Precision 
												   OR ( X.DataType_Precision IS NULL AND Y.DataType_Precision IS NOT NULL ) 
												   OR ( X.DataType_Precision IS NOT NULL AND Y.DataType_Precision IS NULL ) 
												   OR   X.DataType_Scale != Y.DataType_Scale 
												   OR ( X.DataType_Scale IS NULL AND Y.DataType_Scale IS NOT NULL ) 
												   OR ( X.DataType_Scale IS NOT NULL AND Y.DataType_Scale IS NULL ) 
												   OR   X.IsNullable != Y.IsNullable 
												   OR ( X.IsNullable IS NULL AND Y.IsNullable IS NOT NULL ) 
												   OR ( X.IsNullable IS NOT NULL AND Y.IsNullable IS NULL ) 
												   OR   X.IsIdentity != Y.IsIdentity 
												   OR ( X.IsIdentity IS NULL AND Y.IsIdentity IS NOT NULL ) 
												   OR ( X.IsIdentity IS NOT NULL AND Y.IsIdentity IS NULL ) 
												   OR   X.HasDefaultValue != Y.HasDefaultValue 
												   OR ( X.HasDefaultValue IS NULL AND Y.HasDefaultValue IS NOT NULL ) 
												   OR ( X.HasDefaultValue IS NOT NULL AND Y.HasDefaultValue IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #TableValuedFunctionColumn  X  
		INNER JOIN	#TableValuedFunction  T_TVF  ON  X.internalTemp_TableValuedFunctionID = T_TVF.ID 
		INNER JOIN	#DatabaseSchema	 T_S  ON  T_TVF.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.TableValuedFunction TVF ON  S.ID = TVF.DatabaseSchemaID 
												         AND T_TVF.ObjectName = TVF.ObjectName 
		INNER JOIN	dbocatalogue.TableValuedFunctionColumn  Y  ON  TVF.ID = Y.TableValuedFunctionID 
														       AND X.ColumnName = Y.ColumnName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID] 
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID )    
			SELECT  'dbocatalogue.TableValuedFunctionColumn' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID]
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.TableValuedFunction TVF ON  S.ID = TVF.DatabaseSchemaID 
			INNER JOIN  dbocatalogue.TableValuedFunctionColumn  Z  ON  TVF.ID = Z.TableValuedFunctionID  
			LEFT  JOIN	#TableValuedFunctionColumn  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [TableValuedFunctionColumn] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[StoredProcedure] -- 5a  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.Est_CreationTimestamp != Y.Est_CreationTimestamp 
												   OR ( X.Est_CreationTimestamp IS NULL AND Y.Est_CreationTimestamp IS NOT NULL ) 
												   OR ( X.Est_CreationTimestamp IS NOT NULL AND Y.Est_CreationTimestamp IS NULL ) 
												   OR   X.Est_LastModifiedTimestamp != Y.Est_LastModifiedTimestamp 
												   OR ( X.Est_LastModifiedTimestamp IS NULL AND Y.Est_LastModifiedTimestamp IS NOT NULL ) 
												   OR ( X.Est_LastModifiedTimestamp IS NOT NULL AND Y.Est_LastModifiedTimestamp IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #StoredProcedure  X  
		INNER JOIN	#DatabaseSchema	 T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.StoredProcedure  Y  ON  S.ID = Y.DatabaseSchemaID 
												     AND X.ObjectName = Y.ObjectName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID]
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID )    
			SELECT  'dbocatalogue.StoredProcedure' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID]
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.StoredProcedure  Z  ON  S.ID = Z.DatabaseSchemaID 
			LEFT  JOIN	#StoredProcedure  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [StoredProcedure] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[StoredProcedureParameter] -- 5b  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.OrdinalNumber != Y.OrdinalNumber 
												   OR   X.DataType_Name != Y.DataType_Name 
												   OR ( X.DataType_Name IS NULL AND Y.DataType_Name IS NOT NULL ) 
												   OR ( X.DataType_Name IS NOT NULL AND Y.DataType_Name IS NULL ) 
												   OR   X.DataType_MaxLength != Y.DataType_MaxLength 
												   OR ( X.DataType_MaxLength IS NULL AND Y.DataType_MaxLength IS NOT NULL ) 
												   OR ( X.DataType_MaxLength IS NOT NULL AND Y.DataType_MaxLength IS NULL ) 
												   OR   X.DataType_Precision != Y.DataType_Precision 
												   OR ( X.DataType_Precision IS NULL AND Y.DataType_Precision IS NOT NULL ) 
												   OR ( X.DataType_Precision IS NOT NULL AND Y.DataType_Precision IS NULL ) 
												   OR   X.DataType_Scale != Y.DataType_Scale 
												   OR ( X.DataType_Scale IS NULL AND Y.DataType_Scale IS NOT NULL ) 
												   OR ( X.DataType_Scale IS NOT NULL AND Y.DataType_Scale IS NULL ) 
												   OR   X.HasDefaultValue != Y.HasDefaultValue 
												   OR ( X.HasDefaultValue IS NULL AND Y.HasDefaultValue IS NOT NULL ) 
												   OR ( X.HasDefaultValue IS NOT NULL AND Y.HasDefaultValue IS NULL ) 
												   OR   X.IsOutput != Y.IsOutput 
												   OR ( X.IsOutput IS NULL AND Y.IsOutput IS NOT NULL ) 
												   OR ( X.IsOutput IS NOT NULL AND Y.IsOutput IS NULL ) 
												   OR   X.IsReadOnly != Y.IsReadOnly 
												   OR ( X.IsReadOnly IS NULL AND Y.IsReadOnly IS NOT NULL ) 
												   OR ( X.IsReadOnly IS NOT NULL AND Y.IsReadOnly IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #StoredProcedureParameter  X  
		INNER JOIN	#StoredProcedure  T_SP  ON  X.internalTemp_StoredProcedureID = T_SP.ID 
		INNER JOIN	#DatabaseSchema	 T_S  ON  T_SP.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.StoredProcedure SP ON  S.ID = SP.DatabaseSchemaID 
												         AND T_SP.ObjectName = SP.ObjectName 
		INNER JOIN	dbocatalogue.StoredProcedureParameter  Y  ON  SP.ID = Y.StoredProcedureID 
														          AND X.ParameterName = Y.ParameterName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID]
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID )    
			SELECT  'dbocatalogue.StoredProcedureParameter' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID]
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.StoredProcedure SP ON  S.ID = SP.DatabaseSchemaID 
			INNER JOIN  dbocatalogue.StoredProcedureParameter  Z  ON  SP.ID = Z.StoredProcedureID  
			LEFT  JOIN	#StoredProcedureParameter  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [StoredProcedureParameter] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	BEGIN TRY 
		--
		--  [dbocatalogue].[SynonymAlias] -- 6a  
		--
		UPDATE		X	
		SET			X.PersistentTableRecordID = Y.ID 
		,			X.ReactivateRecord = CASE WHEN Y.RecordIsActive = 0 THEN 1 ELSE 0 END 
		--
		,			X.UpdateCoreFieldValues = CASE WHEN X.Target_ServerName != Y.Target_ServerName 
												   OR ( X.Target_ServerName IS NULL AND Y.Target_ServerName IS NOT NULL ) 
												   OR ( X.Target_ServerName IS NOT NULL AND Y.Target_ServerName IS NULL ) 
												   OR   X.Target_DatabaseName != Y.Target_DatabaseName 
												   OR ( X.Target_DatabaseName IS NULL AND Y.Target_DatabaseName IS NOT NULL ) 
												   OR ( X.Target_DatabaseName IS NOT NULL AND Y.Target_DatabaseName IS NULL ) 
												   OR   X.Target_SchemaName != Y.Target_SchemaName 
												   OR ( X.Target_SchemaName IS NULL AND Y.Target_SchemaName IS NOT NULL ) 
												   OR ( X.Target_SchemaName IS NOT NULL AND Y.Target_SchemaName IS NULL ) 
												   OR   X.Target_ObjectName != Y.Target_ObjectName 
												   OR ( X.Target_ObjectName IS NULL AND Y.Target_ObjectName IS NOT NULL ) 
												   OR ( X.Target_ObjectName IS NOT NULL AND Y.Target_ObjectName IS NULL ) 
												   OR   X.Est_CreationTimestamp != Y.Est_CreationTimestamp 
												   OR ( X.Est_CreationTimestamp IS NULL AND Y.Est_CreationTimestamp IS NOT NULL ) 
												   OR ( X.Est_CreationTimestamp IS NOT NULL AND Y.Est_CreationTimestamp IS NULL ) 
												   OR   X.Est_LastModifiedTimestamp != Y.Est_LastModifiedTimestamp 
												   OR ( X.Est_LastModifiedTimestamp IS NULL AND Y.Est_LastModifiedTimestamp IS NOT NULL ) 
												   OR ( X.Est_LastModifiedTimestamp IS NOT NULL AND Y.Est_LastModifiedTimestamp IS NULL ) 
												   THEN 1 
												   ELSE 0 
											  END 
		--
		FROM        #SynonymAlias  X  
		INNER JOIN	#DatabaseSchema	 T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
		INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
													AND T_S.SchemaName = S.SchemaName 
		INNER JOIN  dbocatalogue.SynonymAlias  Y  ON  S.ID = Y.DatabaseSchemaID 
												  AND X.ObjectName = Y.ObjectName 
		--
		;	INSERT INTO #RecordForDeactivation ( [TableSchemaAndName] , [PersistentTableRecordID]
											   , ScopedDatabaseID , internalTemp_DatabaseSchemaID )     
			SELECT  'dbocatalogue.SynonymAlias' as [TableSchemaAndName] , Z.ID as [PersistentTableRecordID]
			,		SD.ID as ScopedDatabaseID , T_S.ID as internalTemp_DatabaseSchemaID 
			FROM  #ScopedDatabase  SD  
			INNER JOIN  dbocatalogue.DatabaseSchema  S  ON  SD.ID = S.ScopedDatabaseID 
			LEFT  JOIN  #DatabaseSchema			   T_S  ON  SD.ID = T_S.ScopedDatabaseID 
														AND S.SchemaName = T_S.SchemaName 
			INNER JOIN  dbocatalogue.SynonymAlias  Z  ON  S.ID = Z.DatabaseSchemaID 
			LEFT  JOIN	#SynonymAlias  X  ON  Z.ID = X.PersistentTableRecordID 
			WHERE	X.ID IS NULL 
			AND		Z.RecordIsActive = 1 
			--
			;
	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error occurred while attempting to match existing persistent [SynonymAlias] records with staging table.' ;  
		GOTO ERROR ; 
	END CATCH 
			
	--
	--
		
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Comparison complete.' ) END ; 
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Flag #DatabaseSchema records associated to new, dropped, or changing objects.' ) END ; 
	
		UPDATE	X 
		--
		SET		X.ObjectListChangeDetected = CASE WHEN R.internalTemp_DatabaseSchemaID IS NOT NULL 
												  OR   TS.RecordCount   > 0   --  TupleStructure 
												  OR   TSC.RecordCount  > 0   --  TupleStructureColumn 
												  OR   SVF.RecordCount  > 0   --  ScalarValuedFunction  
												  OR   SVFP.RecordCount > 0   --  ScalarValuedFunctionParameter  
												  OR   TVF.RecordCount  > 0   --  TableValuedFunction 
												  OR   TVFP.RecordCount > 0   --  TableValuedFunctionParameter 
												  OR   TVFC.RecordCount > 0   --  TableValuedFunctionColumn
												  OR   SP.RecordCount   > 0   --  StoredProcedure 
												  OR   SPP.RecordCount  > 0   --  StoredProcedureParameter
												  OR   I.RecordCount    > 0   --  SynonymAlias  
												  --
												  THEN 1 
												  ELSE 0 
											 END 
		--
		FROM	#DatabaseSchema		X	
		--
		--
		LEFT  JOIN	(  SELECT  distinct  Rs.internalTemp_DatabaseSchemaID 
					   FROM  #RecordForDeactivation  Rs  
					)
						R	ON  X.ID = R.internalTemp_DatabaseSchemaID 
		--
		--
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #TupleStructure  TSx  
					   WHERE  TSx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( TSx.PersistentTableRecordID IS NULL 
							OR TSx.UpdateCoreFieldValues = 1 ) )  as  TS 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #TupleStructureColumn  TSCx  
					   INNER JOIN #TupleStructure  TSx  ON  TSCx.internalTemp_TupleStructureID = TSx.ID 
					   WHERE  TSx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( TSCx.PersistentTableRecordID IS NULL 
							OR TSCx.UpdateCoreFieldValues = 1 ) )  as  TSC 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #ScalarValuedFunction  SVFx  
					   WHERE  SVFx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( SVFx.PersistentTableRecordID IS NULL 
							OR SVFx.UpdateCoreFieldValues = 1 ) )  as  SVF 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #ScalarValuedFunctionParameter  SVFPx  
					   INNER JOIN #ScalarValuedFunction  SVFx  ON  SVFPx.internalTemp_ScalarValuedFunctionID = SVFx.ID 
					   WHERE  SVFx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( SVFPx.PersistentTableRecordID IS NULL 
							OR SVFPx.UpdateCoreFieldValues = 1 ) )  as  SVFP 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #TableValuedFunction  TVFx  
					   WHERE  TVFx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( TVFx.PersistentTableRecordID IS NULL 
							OR TVFx.UpdateCoreFieldValues = 1 ) )  as  TVF 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #TableValuedFunctionParameter  TVFPx  
					   INNER JOIN #TableValuedFunction  TVFx  ON  TVFPx.internalTemp_TableValuedFunctionID = TVFx.ID 
					   WHERE  TVFx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( TVFPx.PersistentTableRecordID IS NULL 
							OR TVFPx.UpdateCoreFieldValues = 1 ) )  as  TVFP 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #TableValuedFunctionColumn  TVFCx  
					   INNER JOIN #TableValuedFunction  TVFx  ON  TVFCx.internalTemp_TableValuedFunctionID = TVFx.ID 
					   WHERE  TVFx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( TVFCx.PersistentTableRecordID IS NULL 
							OR TVFCx.UpdateCoreFieldValues = 1 ) )  as  TVFC 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #StoredProcedure  SPx  
					   WHERE  SPx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( SPx.PersistentTableRecordID IS NULL 
							OR SPx.UpdateCoreFieldValues = 1 ) )  as  SP 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #StoredProcedureParameter  SPPx  
					   INNER JOIN #StoredProcedure  SPx  ON  SPPx.internalTemp_StoredProcedureID = SPx.ID 
					   WHERE  SPx.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( SPPx.PersistentTableRecordID IS NULL 
							OR SPPx.UpdateCoreFieldValues = 1 ) )  as  SPP 
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #SynonymAlias  Ix  
					   WHERE  Ix.internalTemp_DatabaseSchemaID = X.ID 
					   AND  ( Ix.PersistentTableRecordID IS NULL 
							OR Ix.UpdateCoreFieldValues = 1 ) )  as  I  
		--
		--
		;
		
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Flag #ScopedDatabase records associated to new, dropped, or changing objects.' ) END ; 
	
		UPDATE	X 
		--
		SET		X.NEW_LatestObjectListChangeRecorded = CASE WHEN R.ScopedDatabaseID IS NOT NULL 
															OR   S.ScopedDatabaseID IS NOT NULL 
															OR   DR.RecordCount > 0   --  DatabaseRole 
															OR   DS.RecordCount > 0   --  DatabaseSchema 
															THEN getdate() 
															ELSE null 
													   END 
		--
		FROM	#ScopedDatabase  X	
		--
		--
		LEFT  JOIN	(  SELECT  distinct  Rs.ScopedDatabaseID  
					   FROM  #RecordForDeactivation  Rs  
					)
						R	ON  X.ID = R.ScopedDatabaseID  
		--
		--
		LEFT  JOIN	(  SELECT  distinct  Ss.ScopedDatabaseID  
					   FROM  #DatabaseSchema  Ss  
					   -- 
					   WHERE  Ss.ObjectListChangeDetected = 1 
					   -- 
					)
						S	ON  X.ID = S.ScopedDatabaseID  
		--
		--
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #DatabaseRole  DRx  
					   WHERE  DRx.ScopedDatabaseID = X.ID 
					   AND  ( DRx.PersistentTableRecordID IS NULL 
							OR DRx.UpdateCoreFieldValues = 1 ) )  as  DR  
		--	
		OUTER APPLY (  SELECT COUNT(*) as RecordCount  
					   FROM   #DatabaseSchema  DSx  
					   WHERE  DSx.ScopedDatabaseID = X.ID 
					   AND  ( DSx.PersistentTableRecordID IS NULL 
							OR DSx.UpdateCoreFieldValues = 1 ) )  as  DS   
		--
		--
		;

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' @Mode  =  ''' + @Mode + '''' ) END ; 

	--
	--

		IF @Mode = 'TEST' 
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Display summary of planned table updates.' ) END ; 

				SELECT		'[serverconfig].[ScopedDatabase] Record:'  as  Information 
				--	
				,			X.ID	
				,			X.DatabaseName 
				--
				,			X.NEW_LatestCheckForSynchronizationUpdate 
				,			X.NEW_LatestObjectListChangeRecorded 
				--
				,			@UpdateSizeEstimates as PARAMETER_UpdateSizeEstimates 
				,			X.NEW_LatestSizeUpdateTimestamp
				,			X.NEW_LatestTotalFileSize 
				--
				FROM		#ScopedDatabase		X	
				ORDER BY	X.ID  ASC  
				--
				; 
				
			SET @RowCount = @@ROWCOUNT 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Display summary of new or changed records.' ) END ; 
	
				SELECT	'Summary of new or changed records:'  as  Information 
				--
				,		'[dbocatalogue].[' + X.TableName + ']'  as  TableName 
				,		CASE WHEN X.PersistentTableRecordID IS NULL 
							 THEN 'NEW RECORD' 
							 WHEN X.ReactivateRecord = 1 
							 THEN 'RE-ACTIVATED RECORD' 
							 WHEN X.UpdateCoreFieldValues = 1 
							 THEN 'UPDATING CORE FIELD VALUES' 
							 ELSE '???'
						END  as  ChangeDescription 
				--
				,		X.ScopedDatabaseID 
				,		SD.DatabaseName 
				--
				,		X.DBObjectName 
				,		X.RelatedDBSchema 
				,		X.ParentObjectName 
				,		X.OrdinalNumber 
				--
				FROM	(
							SELECT	C.ScopedDatabaseID 
							,		'DatabaseRole'  as  TableName -- 1a 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.RoleName					as  DBObjectName 
							,		convert(varchar(256),null)  as  RelatedDBSchema 
							--
							,		convert(varchar(256),null)  as  ParentObjectName  
							,		convert(int,null)  as  OrdinalNumber 
							--
							FROM	#DatabaseRole  C  
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--

							UNION ALL 

							SELECT	C.ScopedDatabaseID 
							,		'DatabaseSchema'  as  TableName -- 1b 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.SchemaName				as  DBObjectName 
							,		C.SchemaName				as  RelatedDBSchema 
							--
							,		convert(varchar(256),null)  as  ParentObjectName  
							,		convert(int,null)  as  OrdinalNumber 
							--
							FROM	#DatabaseSchema  C  
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'TupleStructure'  as  TableName -- 2a 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ObjectName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		convert(varchar(256),null)  as  ParentObjectName  
							,		convert(int,null)  as  OrdinalNumber 
							--
							FROM	#TupleStructure  C  
							INNER JOIN  #DatabaseSchema  S  ON  C.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'TupleStructureColumn'  as  TableName -- 2b 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ColumnName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		TS.ObjectName  as  ParentObjectName  
							,		C.OrdinalNumber  as  OrdinalNumber 
							--
							FROM	#TupleStructureColumn  C  
							INNER JOIN  #TupleStructure  TS  ON  C.internalTemp_TupleStructureID = TS.ID 
							INNER JOIN  #DatabaseSchema  S  ON  TS.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'ScalarValuedFunction'  as  TableName -- 3a 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ObjectName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		convert(varchar(256),null)  as  ParentObjectName  
							,		convert(int,null)  as  OrdinalNumber 
							--
							FROM	#ScalarValuedFunction  C  
							INNER JOIN  #DatabaseSchema  S  ON  C.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'ScalarValuedFunctionParameter'  as  TableName -- 3b 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ParameterName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		SVF.ObjectName  as  ParentObjectName  
							,		C.OrdinalNumber  as  OrdinalNumber 
							--
							FROM	#ScalarValuedFunctionParameter  C  
							INNER JOIN  #ScalarValuedFunction  SVF  ON  C.internalTemp_ScalarValuedFunctionID = SVF.ID 
							INNER JOIN  #DatabaseSchema  S  ON  SVF.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'TableValuedFunction'  as  TableName -- 4a 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ObjectName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		convert(varchar(256),null)  as  ParentObjectName  
							,		convert(int,null)  as  OrdinalNumber 
							--
							FROM	#TableValuedFunction  C  
							INNER JOIN  #DatabaseSchema  S  ON  C.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'TableValuedFunctionParameter'  as  TableName -- 4b 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ParameterName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		TVF.ObjectName  as  ParentObjectName  
							,		C.OrdinalNumber  as  OrdinalNumber 
							--
							FROM	#TableValuedFunctionParameter  C  
							INNER JOIN  #TableValuedFunction  TVF  ON  C.internalTemp_TableValuedFunctionID = TVF.ID 
							INNER JOIN  #DatabaseSchema  S  ON  TVF.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'TableValuedFunctionColumn'  as  TableName -- 4c 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ColumnName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		TVF.ObjectName  as  ParentObjectName  
							,		C.OrdinalNumber  as  OrdinalNumber 
							--
							FROM	#TableValuedFunctionColumn  C  
							INNER JOIN  #TableValuedFunction  TVF  ON  C.internalTemp_TableValuedFunctionID = TVF.ID 
							INNER JOIN  #DatabaseSchema  S  ON  TVF.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'StoredProcedure'  as  TableName -- 5a 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ObjectName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		convert(varchar(256),null)  as  ParentObjectName  
							,		convert(int,null)  as  OrdinalNumber 
							--
							FROM	#StoredProcedure  C  
							INNER JOIN  #DatabaseSchema  S  ON  C.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'StoredProcedureParameter'  as  TableName -- 5b 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ParameterName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		SP.ObjectName  as  ParentObjectName  
							,		C.OrdinalNumber  as  OrdinalNumber 
							--
							FROM	#StoredProcedureParameter  C  
							INNER JOIN  #StoredProcedure  SP  ON  C.internalTemp_StoredProcedureID = SP.ID 
							INNER JOIN  #DatabaseSchema  S  ON  SP.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--
							
							UNION ALL 

							SELECT	S.ScopedDatabaseID 
							,		'SynonymAlias'  as  TableName -- 6a 
							--
							,		C.PersistentTableRecordID 
							,		C.UpdateCoreFieldValues	
							,		C.ReactivateRecord 
							-- 
							,		C.ObjectName				as  DBObjectName 
							,		S.SchemaName				as  RelatedDBSchema 
							--
							,		convert(varchar(256),null)  as  ParentObjectName  
							,		convert(int,null)  as  OrdinalNumber 
							--
							FROM	#SynonymAlias  C  
							INNER JOIN  #DatabaseSchema  S  ON  C.internalTemp_DatabaseSchemaID = S.ID
							--
							WHERE	C.PersistentTableRecordID IS NULL 
							OR		C.UpdateCoreFieldValues = 1 
							OR		C.ReactivateRecord = 1 
							--

						)	
							X	
				--
				INNER JOIN  #ScopedDatabase	 SD  ON  X.ScopedDatabaseID = SD.ID 
				--
				ORDER BY	X.ScopedDatabaseID 
				,			X.RelatedDBSchema 
				,			X.TableName
				,			X.ParentObjectName 
				,			X.OrdinalNumber 
				,			X.DBObjectName 
				--
				;

			SET @RowCount = @@ROWCOUNT 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Display records to be "de-activated".' ) END ; 
			
				SELECT	'Summary of records for de-activation:'  as  Information 
				--	
				,		SD.ID  as  ScopedDatabaseID 
				,		SD.DatabaseName 
				--
				,		RFD.TableSchemaAndName 
				,		COUNT(*)  as  RecordCount	
				--
				FROM	#RecordForDeactivation	RFD		
				INNER JOIN #ScopedDatabase  SD  ON  RFD.ScopedDatabaseID = SD.ID 
				--
				GROUP BY	SD.ID   
				,			SD.DatabaseName 
				--
				,			RFD.TableSchemaAndName 
				-- 
				ORDER BY	SD.ID   
				--
				,			RFD.TableSchemaAndName 
				-- 
				; 
			
			SET @RowCount = @@ROWCOUNT 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

		END 

		ELSE IF @Mode = 'LIVE' 
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Execute planned table updates.' ) END ; 
			
			--
			--

				--
				--	DatabaseRole  -- 1a 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.DatabaseRole' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [DatabaseRole] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.DatabaseRole  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.DatabaseRole'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [DatabaseRole] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#DatabaseRole  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [DatabaseRole] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.DatabaseRole 
						(
							ScopedDatabaseID 
						,	RoleName 
						,	Est_CreationTimestamp
						,	Est_LastModifiedTimestamp
						) 
							SELECT	X.ScopedDatabaseID 
							,		X.RoleName 
							,		X.Est_CreationTimestamp 
							,		X.Est_LastModifiedTimestamp 
							--
							FROM	#DatabaseRole  X  
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [DatabaseRole] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#DatabaseRole  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [DatabaseRole] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RoleName = X.RoleName  -- in case of capitalization/accent changes 
						--
						,		E.Est_CreationTimestamp = X.Est_CreationTimestamp 
						,		E.Est_LastModifiedTimestamp = X.Est_LastModifiedTimestamp
						--
						FROM    #DatabaseRole  X  
						INNER JOIN	dbocatalogue.DatabaseRole  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [DatabaseRole] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#DatabaseRole  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [DatabaseRole] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #DatabaseRole  X  
						INNER JOIN	dbocatalogue.DatabaseRole  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [DatabaseRole] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--

				--
				--	DatabaseSchema  -- 1b 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.DatabaseSchema' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [DatabaseSchema] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.DatabaseSchema  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.DatabaseSchema'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [DatabaseSchema] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#DatabaseSchema  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [DatabaseSchema] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.DatabaseSchema 
						(
							ScopedDatabaseID 
						,	SchemaName  
						--
						,	LatestObjectListChangeRecorded 
						--
						) 
							SELECT	X.ScopedDatabaseID 
							,		X.SchemaName 
							--
							,		CASE WHEN X.ObjectListChangeDetected = 1 
										 THEN getdate() 
										 ELSE null 
									END  as  LatestObjectListChangeRecorded 
							--
							FROM	#DatabaseSchema  X  
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [DatabaseSchema] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#DatabaseSchema  X  
							WHERE   (
										X.UpdateCoreFieldValues = 1 
									OR	X.ObjectListChangeDetected = 1 
									) 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [DatabaseSchema] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.SchemaName = X.SchemaName  -- in case of capitalization/accent changes 
						--
						,		E.LatestObjectListChangeRecorded = CASE WHEN X.ObjectListChangeDetected = 1 
																	    THEN getdate() 
																	    ELSE null 
																   END 
						--
						FROM    #DatabaseSchema  X  
						INNER JOIN	dbocatalogue.DatabaseSchema  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						OR		X.ObjectListChangeDetected = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [DatabaseSchema] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#DatabaseSchema  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [DatabaseSchema] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #DatabaseSchema  X  
						INNER JOIN	dbocatalogue.DatabaseSchema  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [DatabaseSchema] table.' 
						GOTO ERROR 
					END CATCH 
				END 

			--
			--
			
				--
				--	TupleStructure  -- 2a 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.TupleStructure' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [TupleStructure] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.TupleStructure  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.TupleStructure'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [TupleStructure] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TupleStructure  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [TupleStructure] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.TupleStructure 
						(
							DatabaseSchemaID 
						,	ObjectName 
						,	TupleStructureTypeID 
						,	Est_CreationTimestamp
						,	Est_LastModifiedTimestamp
						,	LatestSizeUpdateTimestamp 
						,	LatestRowCount 
						,	LatestTotalSpaceKB 
						) 
							SELECT	S.ID  as  DatabaseSchemaID 
							,		X.ObjectName 
							,		X.TupleStructureTypeID 
							,		X.Est_CreationTimestamp
							,		X.Est_LastModifiedTimestamp
							,		CASE WHEN @UpdateSizeEstimates = 1 THEN X.LatestSizeUpdateTimestamp ELSE null END  as  LatestSizeUpdateTimestamp
							,		CASE WHEN @UpdateSizeEstimates = 1 THEN X.LatestRowCount ELSE null END  as  LatestRowCount
							,		CASE WHEN @UpdateSizeEstimates = 1 THEN X.LatestTotalSpaceKB ELSE null END  as  LatestTotalSpaceKB 
							--
							FROM	#TupleStructure  X  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [TupleStructure] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TupleStructure  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [TupleStructure] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ObjectName = X.ObjectName  -- in case of capitalization/accent changes 
						--
						,		E.TupleStructureTypeID = X.TupleStructureTypeID 
						,		E.Est_CreationTimestamp = X.Est_CreationTimestamp 
						,		E.Est_LastModifiedTimestamp = X.Est_LastModifiedTimestamp
						--
						FROM    #TupleStructure  X  
						INNER JOIN	dbocatalogue.TupleStructure  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [TupleStructure] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#TupleStructure  X  
							WHERE   X.UpdateSizeFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "size fields" in existing [TupleStructure] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.LatestSizeUpdateTimestamp = X.LatestSizeUpdateTimestamp 
						,		E.LatestRowCount = X.LatestRowCount 
						,		E.LatestTotalSpaceKB = X.LatestTotalSpaceKB
						--
						FROM    #TupleStructure  X  
						INNER JOIN	dbocatalogue.TupleStructure  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateSizeFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [TupleStructure] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TupleStructure  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [TupleStructure] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #TupleStructure  X  
						INNER JOIN	dbocatalogue.TupleStructure  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [TupleStructure] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
			
				--
				--	TupleStructureColumn  -- 2b 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.TupleStructureColumn' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [TupleStructureColumn] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.TupleStructureColumn  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.TupleStructureColumn'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [TupleStructureColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TupleStructureColumn  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [TupleStructureColumn] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.TupleStructureColumn 
						(
							TupleStructureID  
						,	ColumnName 
						,	OrdinalNumber 
						,	DataType_Name  
						,	DataType_MaxLength 
						,	DataType_Precision 
						,	DataType_Scale 
						,	IsNullable 
						,	IsIdentity 
						,	HasDefaultValue 
						) 
							SELECT	TS.ID  as  TupleStructureID 
							,		X.ColumnName 
							,		X.OrdinalNumber 
							,		X.DataType_Name  
							,		X.DataType_MaxLength 
							,		X.DataType_Precision 
							,		X.DataType_Scale 
							,		X.IsNullable 
							,		X.IsIdentity 
							,		X.HasDefaultValue 
							--
							FROM	#TupleStructureColumn  X  
							LEFT  JOIN	#TupleStructure  T_TS ON  X.internalTemp_TupleStructureID = T_TS.ID  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  T_TS.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							LEFT  JOIN	dbocatalogue.TupleStructure  TS  ON  S.ID = TS.DatabaseSchemaID 
																		 AND T_TS.ObjectName = TS.ObjectName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [TupleStructureColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TupleStructureColumn  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [TupleStructureColumn] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ColumnName = X.ColumnName  -- in case of capitalization/accent changes 
						--
						,		E.OrdinalNumber = X.OrdinalNumber 
						,		E.DataType_Name = X.DataType_Name  
						,		E.DataType_MaxLength = X.DataType_MaxLength 
						,		E.DataType_Precision = X.DataType_Precision 
						,		E.DataType_Scale = X.DataType_Scale 
						,		E.IsNullable = X.IsNullable 
						,		E.IsIdentity = X.IsIdentity 
						,		E.HasDefaultValue = X.HasDefaultValue 
						--
						FROM    #TupleStructureColumn  X  
						INNER JOIN	dbocatalogue.TupleStructureColumn  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [TupleStructureColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#TupleStructureColumn  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [TupleStructureColumn] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #TupleStructureColumn  X  
						INNER JOIN	dbocatalogue.TupleStructureColumn  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [TupleStructureColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--

				--
				--	ScalarValuedFunction  -- 3a 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.ScalarValuedFunction' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [ScalarValuedFunction] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.ScalarValuedFunction  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.ScalarValuedFunction'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [ScalarValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#ScalarValuedFunction  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [ScalarValuedFunction] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.ScalarValuedFunction 
						(
							DatabaseSchemaID 
						,	ObjectName 
						,	ReturnValue_DataType_Name  
						,	ReturnValue_DataType_MaxLength   
						,	ReturnValue_DataType_Precision   
						,	ReturnValue_DataType_Scale  
						,	Est_CreationTimestamp
						,	Est_LastModifiedTimestamp
						) 
							SELECT	S.ID  as  DatabaseSchemaID 
							,		X.ObjectName 
							,		X.ReturnValue_DataType_Name  
							,		X.ReturnValue_DataType_MaxLength   
							,		X.ReturnValue_DataType_Precision   
							,		X.ReturnValue_DataType_Scale  
							,		X.Est_CreationTimestamp
							,		X.Est_LastModifiedTimestamp
							--
							FROM	#ScalarValuedFunction  X  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [ScalarValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#ScalarValuedFunction  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [ScalarValuedFunction] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ObjectName = X.ObjectName  -- in case of capitalization/accent changes 
						--
						,		E.ReturnValue_DataType_Name = X.ReturnValue_DataType_Name    
						,		E.ReturnValue_DataType_MaxLength = X.ReturnValue_DataType_MaxLength   
						,		E.ReturnValue_DataType_Precision = X.ReturnValue_DataType_Precision   
						,		E.ReturnValue_DataType_Scale = X.ReturnValue_DataType_Scale  
						,		E.Est_CreationTimestamp = X.Est_CreationTimestamp
						,		E.Est_LastModifiedTimestamp = X.Est_LastModifiedTimestamp
						--
						FROM    #ScalarValuedFunction  X  
						INNER JOIN	dbocatalogue.ScalarValuedFunction  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [ScalarValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#ScalarValuedFunction  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [ScalarValuedFunction] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #ScalarValuedFunction  X  
						INNER JOIN	dbocatalogue.ScalarValuedFunction  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [ScalarValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
			
				--
				--	ScalarValuedFunctionParameter  -- 3b 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.ScalarValuedFunctionParameter' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [ScalarValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.ScalarValuedFunctionParameter  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.ScalarValuedFunctionParameter'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [ScalarValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#ScalarValuedFunctionParameter  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [ScalarValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.ScalarValuedFunctionParameter 
						(
							ScalarValuedFunctionID  
						,	ParameterName 
						,	OrdinalNumber 
						,	DataType_Name  
						,	DataType_MaxLength 
						,	DataType_Precision 
						,	DataType_Scale 
						,	HasDefaultValue 
						,	IsOutput 
						,	IsReadOnly 
						) 
							SELECT	SVF.ID  as  ScalarValuedFunctionID 
							,		X.ParameterName 
							,		X.OrdinalNumber 
							,		X.DataType_Name  
							,		X.DataType_MaxLength 
							,		X.DataType_Precision 
							,		X.DataType_Scale 
							,		X.HasDefaultValue 
							,		X.IsOutput 
							,		X.IsReadOnly 
							--
							FROM	#ScalarValuedFunctionParameter  X  
							LEFT  JOIN	#ScalarValuedFunction T_SVF ON  X.internalTemp_ScalarValuedFunctionID = T_SVF.ID  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  T_SVF.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							LEFT  JOIN	dbocatalogue.ScalarValuedFunction SVF ON  S.ID = SVF.DatabaseSchemaID 
																			  AND T_SVF.ObjectName = SVF.ObjectName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [ScalarValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#ScalarValuedFunctionParameter  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [ScalarValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ParameterName = X.ParameterName  -- in case of capitalization/accent changes 
						--
						,		E.OrdinalNumber = X.OrdinalNumber 
						,		E.DataType_Name = X.DataType_Name  
						,		E.DataType_MaxLength = X.DataType_MaxLength 
						,		E.DataType_Precision = X.DataType_Precision 
						,		E.DataType_Scale = X.DataType_Scale 
						,		E.HasDefaultValue = X.HasDefaultValue 
						,		E.IsOutput = X.IsOutput 
						,		E.IsReadOnly = X.IsReadOnly 
						--
						FROM    #ScalarValuedFunctionParameter  X  
						INNER JOIN	dbocatalogue.ScalarValuedFunctionParameter  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [ScalarValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#ScalarValuedFunctionParameter  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [ScalarValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #ScalarValuedFunctionParameter  X  
						INNER JOIN	dbocatalogue.ScalarValuedFunctionParameter  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [ScalarValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
		
				--
				--	TableValuedFunction  -- 4a 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.TableValuedFunction' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [TableValuedFunction] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.TableValuedFunction  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.TableValuedFunction'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [TableValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunction  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [TableValuedFunction] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.TableValuedFunction 
						(
							DatabaseSchemaID 
						,	ObjectName 
						,	Est_CreationTimestamp
						,	Est_LastModifiedTimestamp
						,	IsInline 
						) 
							SELECT	S.ID  as  DatabaseSchemaID 
							,		X.ObjectName 
							,		X.Est_CreationTimestamp
							,		X.Est_LastModifiedTimestamp
							,		X.IsInline
							--
							FROM	#TableValuedFunction  X  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [TableValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunction  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [TableValuedFunction] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ObjectName = X.ObjectName  -- in case of capitalization/accent changes 
						--
						,		E.Est_CreationTimestamp = X.Est_CreationTimestamp
						,		E.Est_LastModifiedTimestamp = X.Est_LastModifiedTimestamp
						,		E.IsInline = X.IsInline
						--
						FROM    #TableValuedFunction  X  
						INNER JOIN	dbocatalogue.TableValuedFunction  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [TableValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunction  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [TableValuedFunction] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #TableValuedFunction  X  
						INNER JOIN	dbocatalogue.TableValuedFunction  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [TableValuedFunction] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
			
				--
				--	TableValuedFunctionParameter  -- 4b 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.TableValuedFunctionParameter' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [TableValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.TableValuedFunctionParameter  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.TableValuedFunctionParameter'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [TableValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunctionParameter  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [TableValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.TableValuedFunctionParameter 
						(
							TableValuedFunctionID  
						,	ParameterName 
						,	OrdinalNumber 
						,	DataType_Name  
						,	DataType_MaxLength 
						,	DataType_Precision 
						,	DataType_Scale 
						,	HasDefaultValue 
						,	IsOutput 
						,	IsReadOnly 
						) 
							SELECT	TVF.ID  as  TableValuedFunctionID 
							,		X.ParameterName 
							,		X.OrdinalNumber 
							,		X.DataType_Name  
							,		X.DataType_MaxLength 
							,		X.DataType_Precision 
							,		X.DataType_Scale 
							,		X.HasDefaultValue 
							,		X.IsOutput 
							,		X.IsReadOnly 
							--
							FROM	#TableValuedFunctionParameter  X  
							LEFT  JOIN	#TableValuedFunction T_TVF ON  X.internalTemp_TableValuedFunctionID = T_TVF.ID  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  T_TVF.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							LEFT  JOIN	dbocatalogue.TableValuedFunction TVF ON  S.ID = TVF.DatabaseSchemaID 
																			 AND T_TVF.ObjectName = TVF.ObjectName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [TableValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunctionParameter  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [TableValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ParameterName = X.ParameterName  -- in case of capitalization/accent changes 
						--
						,		E.OrdinalNumber = X.OrdinalNumber 
						,		E.DataType_Name = X.DataType_Name  
						,		E.DataType_MaxLength = X.DataType_MaxLength 
						,		E.DataType_Precision = X.DataType_Precision 
						,		E.DataType_Scale = X.DataType_Scale 
						,		E.HasDefaultValue = X.HasDefaultValue 
						,		E.IsOutput = X.IsOutput 
						,		E.IsReadOnly = X.IsReadOnly 
						--
						FROM    #TableValuedFunctionParameter  X  
						INNER JOIN	dbocatalogue.TableValuedFunctionParameter  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [TableValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunctionParameter  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [TableValuedFunctionParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #TableValuedFunctionParameter  X  
						INNER JOIN	dbocatalogue.TableValuedFunctionParameter  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [TableValuedFunctionParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
			
				--
				--	TableValuedFunctionColumn  -- 4c 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.TableValuedFunctionColumn' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [TableValuedFunctionColumn] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.TableValuedFunctionColumn  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.TableValuedFunctionColumn'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [TableValuedFunctionColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunctionColumn  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [TableValuedFunctionColumn] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.TableValuedFunctionColumn 
						(
							TableValuedFunctionID  
						,	ColumnName 
						,	OrdinalNumber 
						,	DataType_Name  
						,	DataType_MaxLength 
						,	DataType_Precision 
						,	DataType_Scale 
						,	IsNullable  
						,	IsIdentity 
						,	HasDefaultValue 
						) 
							SELECT	TVF.ID  as  TableValuedFunctionID 
							,		X.ColumnName 
							,		X.OrdinalNumber 
							,		X.DataType_Name  
							,		X.DataType_MaxLength 
							,		X.DataType_Precision 
							,		X.DataType_Scale 
							,		X.IsNullable 
							,		X.IsIdentity 
							,		X.HasDefaultValue 
							--
							FROM	#TableValuedFunctionColumn  X  
							LEFT  JOIN	#TableValuedFunction T_TVF ON  X.internalTemp_TableValuedFunctionID = T_TVF.ID  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  T_TVF.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							LEFT  JOIN	dbocatalogue.TableValuedFunction TVF ON  S.ID = TVF.DatabaseSchemaID 
																			 AND T_TVF.ObjectName = TVF.ObjectName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [TableValuedFunctionColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunctionColumn  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [TableValuedFunctionColumn] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ColumnName = X.ColumnName  -- in case of capitalization/accent changes 
						--
						,		E.OrdinalNumber = X.OrdinalNumber 
						,		E.DataType_Name = X.DataType_Name  
						,		E.DataType_MaxLength = X.DataType_MaxLength 
						,		E.DataType_Precision = X.DataType_Precision 
						,		E.DataType_Scale = X.DataType_Scale 
						,		E.IsNullable = X.IsNullable 
						,		E.IsIdentity = X.IsIdentity 
						,		E.HasDefaultValue = X.HasDefaultValue 
						--
						FROM    #TableValuedFunctionColumn  X  
						INNER JOIN	dbocatalogue.TableValuedFunctionColumn  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [TableValuedFunctionColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#TableValuedFunctionColumn  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [TableValuedFunctionColumn] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #TableValuedFunctionColumn  X  
						INNER JOIN	dbocatalogue.TableValuedFunctionColumn  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [TableValuedFunctionColumn] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
		
				--
				--	StoredProcedure  -- 5a 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.StoredProcedure' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [StoredProcedure] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.StoredProcedure  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.StoredProcedure'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [StoredProcedure] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#StoredProcedure  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [StoredProcedure] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.StoredProcedure 
						(
							DatabaseSchemaID 
						,	ObjectName 
						,	Est_CreationTimestamp
						,	Est_LastModifiedTimestamp
						) 
							SELECT	S.ID  as  DatabaseSchemaID 
							,		X.ObjectName 
							,		X.Est_CreationTimestamp
							,		X.Est_LastModifiedTimestamp
							--
							FROM	#StoredProcedure  X  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [StoredProcedure] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#StoredProcedure  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [StoredProcedure] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ObjectName = X.ObjectName  -- in case of capitalization/accent changes 
						--
						,		E.Est_CreationTimestamp = X.Est_CreationTimestamp
						,		E.Est_LastModifiedTimestamp = X.Est_LastModifiedTimestamp
						--
						FROM    #StoredProcedure  X  
						INNER JOIN	dbocatalogue.StoredProcedure  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [StoredProcedure] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#StoredProcedure  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [StoredProcedure] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #StoredProcedure  X  
						INNER JOIN	dbocatalogue.StoredProcedure  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [StoredProcedure] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
			
				--
				--	StoredProcedureParameter  -- 5b 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.StoredProcedureParameter' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [StoredProcedureParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.StoredProcedureParameter  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.StoredProcedureParameter'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [StoredProcedureParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#StoredProcedureParameter  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [StoredProcedureParameter] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.StoredProcedureParameter 
						(
							StoredProcedureID  
						,	ParameterName 
						,	OrdinalNumber 
						,	DataType_Name  
						,	DataType_MaxLength 
						,	DataType_Precision 
						,	DataType_Scale 
						,	HasDefaultValue 
						,	IsOutput 
						,	IsReadOnly 
						) 
							SELECT	SP.ID  as  StoredProcedureID 
							,		X.ParameterName 
							,		X.OrdinalNumber 
							,		X.DataType_Name  
							,		X.DataType_MaxLength 
							,		X.DataType_Precision 
							,		X.DataType_Scale 
							,		X.HasDefaultValue 
							,		X.IsOutput 
							,		X.IsReadOnly 
							--
							FROM	#StoredProcedureParameter  X  
							LEFT  JOIN	#StoredProcedure T_SP ON  X.internalTemp_StoredProcedureID = T_SP.ID  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  T_SP.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							LEFT  JOIN	dbocatalogue.StoredProcedure SP ON  S.ID = SP.DatabaseSchemaID 
																		AND T_SP.ObjectName = SP.ObjectName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [StoredProcedureParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#StoredProcedureParameter  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [StoredProcedureParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ParameterName = X.ParameterName  -- in case of capitalization/accent changes 
						--
						,		E.OrdinalNumber = X.OrdinalNumber 
						,		E.DataType_Name = X.DataType_Name  
						,		E.DataType_MaxLength = X.DataType_MaxLength 
						,		E.DataType_Precision = X.DataType_Precision 
						,		E.DataType_Scale = X.DataType_Scale 
						,		E.HasDefaultValue = X.HasDefaultValue 
						,		E.IsOutput = X.IsOutput 
						,		E.IsReadOnly = X.IsReadOnly 
						--
						FROM    #StoredProcedureParameter  X  
						INNER JOIN	dbocatalogue.StoredProcedureParameter  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [StoredProcedureParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#StoredProcedureParameter  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [StoredProcedureParameter] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #StoredProcedureParameter  X  
						INNER JOIN	dbocatalogue.StoredProcedureParameter  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [StoredProcedureParameter] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--

				--
				--	SynonymAlias  -- 6a 
				--
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#RecordForDeactivation  X  
							WHERE	X.TableSchemaAndName = 'dbocatalogue.SynonymAlias' ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'De-activate existing [SynonymAlias] records.' ) END ; 
					BEGIN TRY 
						UPDATE  D  
						SET   D.RecordIsActive = 0 
						,     D.RecordDeactivationTimestamp = getdate() 
						FROM  #RecordForDeactivation  X 
						INNER JOIN  dbocatalogue.SynonymAlias  D  ON  X.PersistentTableRecordID = D.ID 
						WHERE  X.TableSchemaAndName = 'dbocatalogue.SynonymAlias'
						AND    D.RecordIsActive = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to de-activate existing records in the [SynonymAlias] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#SynonymAlias  X  
							WHERE	X.PersistentTableRecordID IS NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Create new [SynonymAlias] records.' ) END ; 
					BEGIN TRY 
						INSERT INTO dbocatalogue.SynonymAlias 
						(
							DatabaseSchemaID 
						,	ObjectName 
						,	Target_ServerName 
						,	Target_DatabaseName
						,	Target_SchemaName
						,	Target_ObjectName
						,	Est_CreationTimestamp
						,	Est_LastModifiedTimestamp
						) 
							SELECT	S.ID  as  DatabaseSchemaID 
							,		X.ObjectName 
							,		X.Target_ServerName 
							,		X.Target_DatabaseName
							,		X.Target_SchemaName
							,		X.Target_ObjectName
							,		X.Est_CreationTimestamp
							,		X.Est_LastModifiedTimestamp
							--
							FROM	#SynonymAlias  X  
							LEFT  JOIN  #DatabaseSchema  T_S  ON  X.internalTemp_DatabaseSchemaID = T_S.ID 
							LEFT  JOIN  dbocatalogue.DatabaseSchema  S  ON  T_S.ScopedDatabaseID = S.ScopedDatabaseID 
																		AND T_S.SchemaName = S.SchemaName 
							WHERE	X.PersistentTableRecordID IS NULL 
							--
							;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to insert into the [SynonymAlias] table.' 
						GOTO ERROR 
					END CATCH 
				END 

		/****/  IF EXISTS ( SELECT  null 
							FROM	#SynonymAlias  X  
							WHERE   X.UpdateCoreFieldValues = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update "core fields" in existing [SynonymAlias] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.ObjectName = X.ObjectName  -- in case of capitalization/accent changes 
						--
						,		E.Target_ServerName = X.Target_ServerName 
						,		E.Target_DatabaseName = X.Target_DatabaseName
						,		E.Target_SchemaName = X.Target_SchemaName
						,		E.Target_ObjectName = X.Target_ObjectName
						,		E.Est_CreationTimestamp = X.Est_CreationTimestamp
						,		E.Est_LastModifiedTimestamp = X.Est_LastModifiedTimestamp
						--
						FROM    #SynonymAlias  X  
						INNER JOIN	dbocatalogue.SynonymAlias  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.UpdateCoreFieldValues = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to update "core fields" in the [SynonymAlias] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
		/****/  IF EXISTS ( SELECT  null 
							FROM	#SynonymAlias  X  
							WHERE   X.ReactivateRecord = 1 
							AND     X.PersistentTableRecordID IS NOT NULL ) 
				BEGIN 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Re-activate currently inactive [SynonymAlias] records.' ) END ; 
					BEGIN TRY 
						UPDATE	E 
						--
						SET		E.RecordIsActive = 1 
						,		E.RecordDeactivationTimestamp = null 
						--
						FROM    #SynonymAlias  X  
						INNER JOIN	dbocatalogue.SynonymAlias  E  ON  X.PersistentTableRecordID = E.ID 
						--
						WHERE	X.ReactivateRecord = 1 
						--
						;

						SET @RowCount = @@ROWCOUNT 
						IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
					END TRY 
					BEGIN CATCH 
						SET @ErrorMessage = 'An error occurred while attempting to re-activate records in the [SynonymAlias] table.' 
						GOTO ERROR 
					END CATCH 
				END 
				
			--
			--
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [ScopedDatabase] records.' ) END ; 
			
			BEGIN TRY 
			
				UPDATE		E 
				SET			E.LatestCheckForSynchronizationUpdate = X.NEW_LatestCheckForSynchronizationUpdate 
				,			E.LatestObjectListChangeRecorded = CASE WHEN X.NEW_LatestObjectListChangeRecorded IS NOT NULL 
																	THEN X.NEW_LatestObjectListChangeRecorded 
																	ELSE E.LatestObjectListChangeRecorded 
															   END 
				,			E.LatestSizeUpdateTimestamp = CASE WHEN @UpdateSizeEstimates = 1 
															   THEN X.NEW_LatestSizeUpdateTimestamp 
															   ELSE E.LatestSizeUpdateTimestamp 
														  END 
				,			E.LatestTotalFileSize = CASE WHEN @UpdateSizeEstimates = 1 
														 THEN X.NEW_LatestTotalFileSize 
														 ELSE E.LatestTotalFileSize 
												    END 
								
				FROM		#ScopedDatabase				 X	
				INNER JOIN	serverconfig.ScopedDatabase	 E  ON  X.ID = E.ID 
				--
				;

				SET @RowCount = @@ROWCOUNT 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

			END TRY 
			BEGIN CATCH 
				SET @ErrorMessage = 'An error occurred while attempting to update [ScopedDatabase] records.' 
				GOTO ERROR 
			END CATCH 

			--
			--

		END		

	--
	--

	FINISH: 
	
	--
	DROP TABLE #ScopedDatabase ; 
	--
	DROP TABLE #Cache_sys_database_principals ; 
	DROP TABLE #Cache_sys_schemas ; 
	DROP TABLE #Cache_sys_objects ; 
	DROP TABLE #Cache_sys_all_columns ; 
	DROP TABLE #Cache_sys_all_parameters ; 
	--
	DROP TABLE #DatabaseRole ; -- 1a 
	DROP TABLE #DatabaseSchema ; -- 1b 
	--
	DROP TABLE #TupleStructure ; -- 2a 
	DROP TABLE #TupleStructureColumn ; -- 2b 
	--
	DROP TABLE #ScalarValuedFunction ; -- 3a 
	DROP TABLE #ScalarValuedFunctionParameter ; -- 3b 
	--
	DROP TABLE #TableValuedFunction ; -- 4a 
	DROP TABLE #TableValuedFunctionParameter ; -- 4b 
	DROP TABLE #TableValuedFunctionColumn -- 4c 
	--
	DROP TABLE #StoredProcedure ; -- 5a 
	DROP TABLE #StoredProcedureParameter ; -- 5b 
	--
	DROP TABLE #SynonymAlias ; -- 6a 
	--
	--
	DROP TABLE #RecordForDeactivation 
	-- 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	RETURN 1 ; 

	--
	--
	
	ERROR: 
	
	--
	IF OBJECT_ID('tempdb..#ScopedDatabase') IS NOT NULL DROP TABLE #ScopedDatabase ;  
	--
	IF OBJECT_ID('tempdb..#Cache_sys_database_principals') IS NOT NULL DROP TABLE #Cache_sys_database_principals ;  
	IF OBJECT_ID('tempdb..#Cache_sys_schemas') IS NOT NULL DROP TABLE #Cache_sys_schemas ;  
	IF OBJECT_ID('tempdb..#Cache_sys_objects') IS NOT NULL DROP TABLE #Cache_sys_objects ;  
	IF OBJECT_ID('tempdb..#Cache_sys_all_columns') IS NOT NULL DROP TABLE #Cache_sys_all_columns ;  
	IF OBJECT_ID('tempdb..#Cache_sys_all_parameters') IS NOT NULL DROP TABLE #Cache_sys_all_parameters ;  
	--
	IF OBJECT_ID('tempdb..#DatabaseRole') IS NOT NULL DROP TABLE #DatabaseRole ; -- 1a 
	IF OBJECT_ID('tempdb..#DatabaseSchema') IS NOT NULL DROP TABLE #DatabaseSchema ; -- 1b 
	--
	IF OBJECT_ID('tempdb..#TupleStructure') IS NOT NULL DROP TABLE #TupleStructure ; -- 2a 
	IF OBJECT_ID('tempdb..#TupleStructureColumn') IS NOT NULL DROP TABLE #TupleStructureColumn ; -- 2b 
	--
	IF OBJECT_ID('tempdb..#ScalarValuedFunction') IS NOT NULL DROP TABLE #ScalarValuedFunction ; -- 3a 
	IF OBJECT_ID('tempdb..#ScalarValuedFunctionParameter') IS NOT NULL DROP TABLE #ScalarValuedFunctionParameter ; -- 3b 
	--
	IF OBJECT_ID('tempdb..#TableValuedFunction') IS NOT NULL DROP TABLE #TableValuedFunction ; -- 4a 
	IF OBJECT_ID('tempdb..#TableValuedFunctionParameter') IS NOT NULL DROP TABLE #TableValuedFunctionParameter ; -- 4b 
	IF OBJECT_ID('tempdb..#TableValuedFunctionColumn') IS NOT NULL DROP TABLE #TableValuedFunctionColumn -- 4c 
	--
	IF OBJECT_ID('tempdb..#StoredProcedure') IS NOT NULL DROP TABLE #StoredProcedure ; -- 5a 
	IF OBJECT_ID('tempdb..#StoredProcedureParameter') IS NOT NULL DROP TABLE #StoredProcedureParameter ; -- 5b 
	--
	IF OBJECT_ID('tempdb..#SynonymAlias') IS NOT NULL DROP TABLE #SynonymAlias ; -- 6a 
	--
	--
	IF OBJECT_ID('tempdb..#RecordForDeactivation') IS NOT NULL DROP TABLE #RecordForDeactivation ; 
	-- 

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END 

	RETURN -1 ; 

END 
GO
-- 
-- END FILE :: a003_dbocatalogue_usp_Synchronize_ScopedDatabaseObjectLists.sql 
-- 