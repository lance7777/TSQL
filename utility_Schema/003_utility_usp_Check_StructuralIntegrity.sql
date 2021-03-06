--
-- BEGIN FILE :: 003_utility_usp_Check_StructuralIntegrity.sql 
--
USE [EXAMPLE]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [utility].[usp_Check_StructuralIntegrity]
--
	@DEBUG		bit		=	0 
--
AS
/**************************************************************************************

	Checks all tables in database for 
	 the existence of related objects 
	  and adherence to object naming conventions. 

	 Displays any identified issues to be addressed. 

	
		Example: 


			EXEC	utility.usp_Check_StructuralIntegrity
						@DEBUG	 =	1	
			;


	Date			Action	
	----------		----------------------------
	2020-04-11		Created initial version. 
	2020-08-11		Prepared for GITHUB.
	2021-03-20		Exclude/ignore "index name" convention rule-checks for Table-Valued Function results. 

**************************************************************************************/
BEGIN
	SET NOCOUNT ON;

	DECLARE		@ErrorMessage							varchar(200)	
	,			@RowCount								int				
	--
	,			@Schema_History_Suffix					varchar(20)		=	'_history'	
	--	
	;
	
	--
	--  (0)  List of checks to perform: 
	--
		/*    																		       */
		/*    1a - each table's first column is [ID] (int or bigint) 					   */
		/*    1b - each table has consistently named primary key on [ID] column 		   */
		/*    																		       */
		/*    2a - each index is consistently named 									   */
		/*    2b - each foreign key is consistently named 							       */
		/*    2c - check constraints are consistently named 				               */
		/*    2d - default constraints are consistently named 				               */
		/*    																		       */
		/*    3a - tables contain expected audit fields 								   */
		/*    3b - tables have associated history tables and triggers, when appropriate    */
		/*    																		       */
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 
	
	--
	--
	
	--
	--  (1)  Check that all tables have first column [ID] (int or bigint) as the primary key
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check that the first column is named [ID] in all tables, with int or bigint data-type.' ) END ; 
	
	-- Check: (1a) 
	BEGIN TRY 

		SELECT		'Unexpected first column name or data-type:'  as  IssueDescription   
		--
		,			T.TABLE_SCHEMA 
		,			T.TABLE_NAME 
		,			C.ORDINAL_POSITION 
		,			C.COLUMN_NAME 
		,			C.DATA_TYPE 
		--
		INTO  #U_usp_C_SI_check_1a 
		--
		FROM		INFORMATION_SCHEMA.TABLES   T 
		LEFT  JOIN	INFORMATION_SCHEMA.COLUMNS  C  ON  T.TABLE_SCHEMA = C.TABLE_SCHEMA 
												   AND T.TABLE_NAME = C.TABLE_NAME 
												   AND C.ORDINAL_POSITION = 1
		--
		WHERE		T.TABLE_TYPE = 'BASE TABLE' 
		AND			(
						C.COLUMN_NAME IS NULL 
					OR  C.COLUMN_NAME != 'ID' 
					OR  C.DATA_TYPE IS NULL 
					OR  C.DATA_TYPE NOT IN ( 'int' , 'bigint' ) 
					) 
		--
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (1a) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_1a  X 
			--
			ORDER BY  X.TABLE_SCHEMA 
			,		  X.TABLE_NAME 
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_1a
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (1a).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (1a) 
	
	-- Check: (1b) 
	BEGIN TRY 

		SELECT		'Missing or unexpected primary key:'  as  IssueDescription 
		--
		,			T.TABLE_SCHEMA 
		,			T.TABLE_NAME 
		,			TC.CONSTRAINT_TYPE 
		,			TC.CONSTRAINT_SCHEMA 
		,			TC.CONSTRAINT_NAME 
		--
		,			CCU_summary.ColumnCount 
		,			CCU_summary.SingleColumnName 
		,			CCU_summary.TableMatch 
		--
		INTO  #U_usp_C_SI_check_1b 
		--
		FROM		INFORMATION_SCHEMA.TABLES			  T 
		LEFT  JOIN	INFORMATION_SCHEMA.TABLE_CONSTRAINTS  TC  ON  T.TABLE_SCHEMA = TC.TABLE_SCHEMA 
															  AND T.TABLE_NAME = TC.TABLE_NAME 
															  AND TC.CONSTRAINT_TYPE = 'PRIMARY KEY' 
		--
		LEFT  JOIN	( 
						SELECT		TCx.CONSTRAINT_SCHEMA 
						,			TCx.CONSTRAINT_NAME 
						--
						,			COUNT(*)					as  ColumnCount 
						,			CASE WHEN COUNT(*) = 1 
										 THEN MAX(CCUx.COLUMN_NAME) 
										 ELSE null 
									END							as  SingleColumnName 
						,			SUM(CASE WHEN Tx.TABLE_SCHEMA = CCUx.TABLE_SCHEMA 
											 AND  Tx.TABLE_NAME = CCUx.TABLE_NAME 
											 THEN 1 
											 ELSE 0 
										END)					as  TableMatch 
						--
						FROM		INFORMATION_SCHEMA.TABLES			        Tx 
						INNER JOIN  INFORMATION_SCHEMA.TABLE_CONSTRAINTS        TCx   ON  Tx.TABLE_SCHEMA = TCx.TABLE_SCHEMA 
																				      AND Tx.TABLE_NAME = TCx.TABLE_NAME 
																				      AND Tx.TABLE_TYPE = 'BASE TABLE' 
																				      AND TCx.CONSTRAINT_TYPE = 'PRIMARY KEY' 
						LEFT  JOIN	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE  CCUx  ON  TCx.CONSTRAINT_SCHEMA = CCUx.CONSTRAINT_SCHEMA 
																					  AND TCx.CONSTRAINT_NAME = CCUx.CONSTRAINT_NAME 
						GROUP BY	TCx.CONSTRAINT_SCHEMA 
						,			TCx.CONSTRAINT_NAME 
					) 
						CCU_summary  ON  TC.CONSTRAINT_SCHEMA = CCU_summary.CONSTRAINT_SCHEMA 
									 AND TC.CONSTRAINT_NAME = CCU_summary.CONSTRAINT_NAME
		--
		WHERE		T.TABLE_TYPE = 'BASE TABLE' 
		AND			(
						TC.CONSTRAINT_SCHEMA IS NULL 
					OR  TC.CONSTRAINT_SCHEMA != T.TABLE_SCHEMA
					OR  TC.CONSTRAINT_NAME IS NULL 
						--
						--  primary key constraints should be 'PK_' + [TABLE_NAME] for non-history tables 
						--                         and 'PK_history' + [TABLE_NAME] for history tables
						-- 
					OR  TC.CONSTRAINT_NAME != 'PK_' + CASE WHEN RIGHT(T.TABLE_SCHEMA,LEN(@Schema_History_Suffix)) = @Schema_History_Suffix 
							                               THEN 'history_'
														   ELSE ''
													  END + T.TABLE_NAME 
					--
					OR	CCU_summary.ColumnCount IS NULL 
					OR  CCU_summary.ColumnCount != 1 
					OR	CCU_summary.SingleColumnName IS NULL 
					OR  CCU_summary.SingleColumnName != 'ID' 
					OR  CCU_summary.TableMatch IS NULL 
					OR  CCU_summary.TableMatch != 1 
					--
					)
		-- 
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (1b) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_1b  X 
			--
			ORDER BY  X.TABLE_SCHEMA 
			,		  X.TABLE_NAME 
			,		  X.CONSTRAINT_SCHEMA 
			,		  X.CONSTRAINT_NAME 
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_1b
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (1b).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (1b) 
	
	--
	--

	--
	--  (2)  Check that all indexes, foreign keys, check constraints, and default constraints are consistently named 
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check object name consistency for indexes, foreign keys, check constraints, and default constraints.' ) END ; 
	
	-- Check: (2a) 
	BEGIN TRY 

		SELECT		'Unexpected index name:'  as  IssueDescription   
		--
		,			S.[name]		as  [Schema_Name]
		,			O.[name]		as  [Table_Name]
		,			I.[name]		as  Index_Name 
		,			I.is_unique		as  is_unique 
		,			I.[type_desc]   as  [type_desc] 
		--
		INTO  #U_usp_C_SI_check_2a 
		--
		FROM		sys.indexes  I 
		LEFT  JOIN  sys.objects  O  ON  I.[object_id] = O.[object_id]
		LEFT  JOIN  sys.schemas  S  ON  O.[schema_id] = S.[schema_id]
		-- 
		WHERE		O.is_ms_shipped = 0 
		AND			I.is_primary_key = 0 
		--
		AND			coalesce(O.[type_desc],'x') NOT IN ( 'SQL_TABLE_VALUED_FUNCTION' , 'SQL_INLINE_TABLE_VALUED_FUNCTION' )  -- !! hard to name these ones !!
		--
		AND			(
						I.[name] IS NULL 
					OR  O.[name] IS NULL 
					OR  (
						--
						--  indexes should be 'UIX_' + [TABLE_NAME] + {'[_]%'} if unique 
						--                 and 'IX_' + [TABLE_NAME] + {'[_]%'} otherwise
						-- 
							I.[name] != CASE WHEN I.is_unique = 1 
											 THEN 'UIX_'
											 ELSE 'IX_'
										END + O.[name] 
						AND I.[name] NOT LIKE CASE WHEN I.is_unique = 1 
												   THEN 'UIX_'
												   ELSE 'IX_'
											  END + O.[name] + '[_]%'
						)
					)
		--
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (2a) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_2a  X 
			--
			ORDER BY  X.[Schema_Name] 
			,		  X.[Table_Name] 
			,		  X.Index_Name  
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_2a
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (2a).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (2a) 
	
	-- Check: (2b) 
	BEGIN TRY 

		SELECT		'Unexpected foreign key name:'  as  IssueDescription 
		--
		,			RC.CONSTRAINT_SCHEMA
		,			RC.CONSTRAINT_NAME
		,			CCU.TABLE_SCHEMA
		,			CCU.TABLE_NAME
		,			CCU.COLUMN_NAME
		,			RC.UNIQUE_CONSTRAINT_SCHEMA
		,			RC.UNIQUE_CONSTRAINT_NAME
		--
		INTO  #U_usp_C_SI_check_2b 
		--
		FROM		INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS  RC 
		LEFT  JOIN	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE  CCU  ON  RC.CONSTRAINT_SCHEMA = CCU.CONSTRAINT_SCHEMA 
																	 AND RC.CONSTRAINT_NAME = CCU.CONSTRAINT_NAME 
		-- 
		WHERE		(
						CCU.TABLE_SCHEMA IS NULL 
					OR  CCU.CONSTRAINT_SCHEMA != CCU.TABLE_SCHEMA 
					OR  RC.UNIQUE_CONSTRAINT_SCHEMA IS NULL 
					OR  CCU.TABLE_NAME IS NULL 
					OR  CCU.COLUMN_NAME IS NULL 
					OR  (
						--
						--  foreign keys should be 'FK_' + [TABLE_NAME] + '_' + [constrained COLUMN_NAME] 
						--                          if the referenced column belongs to a table in the same schema as the constraint,
						--		 and 'FK_CS_' + [TABLE_NAME] + '_' + [constrained COLUMN_NAME] otherwise ('Cross-Schema' constraints)
						-- 
							RC.CONSTRAINT_NAME != 'FK_' + CASE WHEN RC.UNIQUE_CONSTRAINT_SCHEMA != RC.CONSTRAINT_SCHEMA 
															   THEN 'CS_' 
															   ELSE '' 
														  END + CCU.TABLE_NAME + '_' + CCU.COLUMN_NAME 
						)
					)
		--
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (2b) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_2b  X 
			--
			ORDER BY  X.CONSTRAINT_SCHEMA 
			,		  X.CONSTRAINT_NAME 
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_2b
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (2b).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (2b) 
	
	-- Check: (2c) 
	BEGIN TRY 

		SELECT		'Unexpected check constraint name:'  as  IssueDescription 
		--
		,			CTU.TABLE_SCHEMA
		,			CTU.TABLE_NAME
		,			CC.CONSTRAINT_SCHEMA
		,			CC.CONSTRAINT_NAME
		--
		INTO  #U_usp_C_SI_check_2c 
		--
		FROM		INFORMATION_SCHEMA.CHECK_CONSTRAINTS       CC 
		LEFT  JOIN	INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE  CTU  ON  CC.CONSTRAINT_SCHEMA = CTU.CONSTRAINT_SCHEMA 
																	AND CC.CONSTRAINT_NAME = CTU.CONSTRAINT_NAME
		-- 
		WHERE		(
						CTU.TABLE_SCHEMA IS NULL 
					OR  CTU.CONSTRAINT_SCHEMA != CTU.TABLE_SCHEMA 
					OR  (
						--
						--  check constraints should be named 'CK_' + [TABLE_NAME] + '_' + '%' for non-history tables 
						--                        and 'CK_history_' + [TABLE_NAME] + '_' + '%' for history tables
						-- 
							CC.CONSTRAINT_NAME NOT LIKE 'CK_' + CASE WHEN RIGHT(CTU.TABLE_SCHEMA,LEN(@Schema_History_Suffix)) = @Schema_History_Suffix 
																	 THEN 'history_'
																	 ELSE ''
																END + CTU.TABLE_NAME + '[_]%' 
						)
					)
		--
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (2c) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_2c  X 
			--
			ORDER BY  X.CONSTRAINT_SCHEMA 
			,		  X.CONSTRAINT_NAME 
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_2c
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (2c).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (2c) 
	
	-- Check: (2d) 
	BEGIN TRY 

		SELECT		'Unexpected default constraint name:'  as  IssueDescription 
		--
		,			S.[name]   as  [Schema_Name] 
		,			T.[name]   as  [Table_Name] 
		,			AC.[name]  as  Column_Name 
		,			DC.[name]  as  Constraint_Name 
		--
		INTO  #U_usp_C_SI_check_2d 
		--
		FROM		sys.default_constraints  DC  
		LEFT  JOIN	sys.all_columns			 AC  ON  DC.[object_id] = AC.default_object_id 
		LEFT  JOIN  sys.tables				 T   ON  AC.[object_id] = T.[object_id] 
		LEFT  JOIN	sys.schemas				 S   ON  T.[schema_id] = S.[schema_id] 
		-- 
		WHERE		DC.is_ms_shipped = 0
		AND			(
						S.[name] IS NULL 
					OR  T.[name] IS NULL 
					OR  AC.[name] IS NULL 
					OR  DC.[name] IS NULL 
					OR  (
						--
						--  default constraints should be 'DF_' + [TABLE_NAME] + '_' + [COLUMN_NAME] for non-history tables 
						--                    and 'DF_history_' + [TABLE_NAME] + '_' + [COLUMN_NAME] for history tables
						-- 
							DC.[name] != 'DF_' + CASE WHEN RIGHT(S.[name],LEN(@Schema_History_Suffix)) = @Schema_History_Suffix 
													  THEN 'history_'
													  ELSE ''
											     END + T.[name] + '_' + AC.[name] 
						)
					)
		--
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (2d) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_2d  X 
			--
			ORDER BY  X.[Schema_Name] 
			,		  X.[Table_Name]
			,		  X.Column_Name 
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_2d
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (2d).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (2d) 
	
	--
	--

	--
	--  (3)  Check that all expected audit fields, history tables, and triggers exist 
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check existence of expected audit fields, history tables, and table triggers.' ) END ; 
	
	-- Check: (3a) 
	BEGIN TRY 

		SELECT		'Missing audit field:'  as  IssueDescription 
		--
		,			T.TABLE_SCHEMA 
		,			T.TABLE_NAME
		,			EC.Column_Name
		,			CASE WHEN C.COLUMN_NAME IS NULL THEN 1 ELSE 0 END			as  MissingColumn 
		,			CASE WHEN DC_summary.Column_Name IS NULL THEN 1 ELSE 0 END  as  MissingDefaultConstraint 
		--
		INTO  #U_usp_C_SI_check_3a 
		--
		FROM		INFORMATION_SCHEMA.TABLES   T  
		INNER JOIN  (
						VALUES ( 'InsertTime' , 0 ) 
						,	   ( 'InsertBy'   , 0 ) 
						,	   ( 'UpdateTime' , 1 ) 
						,	   ( 'UpdateBy'   , 1 ) 
					)  
						EC  ( Column_Name , ExcludeFromHistoryTables )  ON  T.TABLE_TYPE = 'BASE TABLE' 
																		AND (
																			    T.TABLE_SCHEMA IS NULL 
																		    OR  RIGHT(T.TABLE_SCHEMA,LEN(@Schema_History_Suffix)) != @Schema_History_Suffix 
																		    OR  EC.ExcludeFromHistoryTables = 0
																			)
		--	
		LEFT  JOIN	INFORMATION_SCHEMA.COLUMNS  C  ON  T.TABLE_SCHEMA = C.TABLE_SCHEMA 
												   AND T.TABLE_NAME = C.TABLE_NAME 
												   AND EC.Column_Name = C.COLUMN_NAME 
		--
		LEFT  JOIN  (
						SELECT		Sx.[name]   as  [Schema_Name] 
						,			Tx.[name]   as  [Table_Name] 
						,			ACx.[name]  as  Column_Name 
						--
						FROM		sys.default_constraints  DCx  
						INNER JOIN	sys.all_columns			 ACx  ON  DCx.[object_id] = ACx.default_object_id 
						INNER JOIN  sys.tables				 Tx   ON  ACx.[object_id] = Tx.[object_id] 
						INNER JOIN	sys.schemas				 Sx   ON  Tx.[schema_id] = Sx.[schema_id] 
						--
						WHERE		DCx.is_ms_shipped = 0
						--
					)
						DC_summary  ON  T.TABLE_SCHEMA = DC_summary.[Schema_Name] 
									AND T.TABLE_NAME = DC_summary.[Table_Name] 
									AND EC.Column_Name = DC_summary.Column_Name 
		-- 
		WHERE		(
						C.COLUMN_NAME IS NULL 
					OR  DC_summary.Column_Name IS NULL 
					)
		--
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (3a) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_3a  X 
			--
			ORDER BY  X.TABLE_SCHEMA 
			,		  X.TABLE_NAME
			,		  X.Column_Name
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_3a
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (3a).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (3a) 

	-- Check: (3b) 
	BEGIN TRY 

		SELECT		'Missing history table or trigger:'  as  IssueDescription 
		--
		,			T.TABLE_SCHEMA 
		,			T.TABLE_NAME 
		,			CASE WHEN T.TABLE_SCHEMA IS NOT NULL 
						 AND  RIGHT(T.TABLE_SCHEMA,LEN(@Schema_History_Suffix)) != @Schema_History_Suffix 
						 AND  HT.TABLE_NAME IS NULL 
						 THEN 1 
						 ELSE 0 
					END				as  MissingHistoryTable 
		--
		,			coalesce(Trigger_Summary.TriggerCount_Standard_OnInsertOrUpdate,0)  as  TriggerCount_Standard_OnInsertOrUpdate 
		,			coalesce(Trigger_Summary.TriggerCount_Standard_OnDelete,0)          as  TriggerCount_Standard_OnDelete 
		,			coalesce(Trigger_Summary.TriggerCount_History_InsteadOfUpdate,0)    as  TriggerCount_History_InsteadOfUpdate 
		--
		INTO  #U_usp_C_SI_check_3b 
		--
		FROM		INFORMATION_SCHEMA.TABLES   T  
		LEFT  JOIN	INFORMATION_SCHEMA.TABLES	HT  ON  T.TABLE_NAME = HT.TABLE_NAME 
													AND RIGHT(T.TABLE_SCHEMA,LEN(@Schema_History_Suffix)) != @Schema_History_Suffix 
													AND T.TABLE_SCHEMA + @Schema_History_Suffix = HT.TABLE_SCHEMA 
		--
		LEFT  JOIN  (
						SELECT		Sx.[name]   as  [Schema_Name] 
						,			Tx.[name]   as  [Table_Name] 
						--
						,			SUM(CASE WHEN RIGHT(Sx.[name],LEN(@Schema_History_Suffix)) != @Schema_History_Suffix 
											 AND  TGx.[name] = 'TG_' + Tx.[name] + '_InsertUpdate' 
											 AND  TGx.is_instead_of_trigger = 0 
											 AND  TGEx.InsertCount = 1 
											 AND  TGEx.UpdateCount = 1 
											 AND  TGEx.DeleteCount = 0 
											 AND  TGEx.RecordCount = 2 
											 THEN 1 
											 ELSE 0 
										END)			as	TriggerCount_Standard_OnInsertOrUpdate 
						--
						,			SUM(CASE WHEN RIGHT(Sx.[name],LEN(@Schema_History_Suffix)) != @Schema_History_Suffix 
											 AND  TGx.[name] = 'TG_' + Tx.[name] + '_Delete' 
											 AND  TGx.is_instead_of_trigger = 0 
											 AND  TGEx.InsertCount = 0 
											 AND  TGEx.UpdateCount = 0 
											 AND  TGEx.DeleteCount = 1 
											 AND  TGEx.RecordCount = 1 
											 THEN 1 
											 ELSE 0 
										END)			as	TriggerCount_Standard_OnDelete 
						--
						,			SUM(CASE WHEN RIGHT(Sx.[name],LEN(@Schema_History_Suffix)) = @Schema_History_Suffix 
											 AND  TGx.[name] = 'TG_history_' + Tx.[name] + '_Update' 
											 AND  TGx.is_instead_of_trigger = 1 
											 AND  TGEx.InsertCount = 0 
											 AND  TGEx.UpdateCount = 1 
											 AND  TGEx.DeleteCount = 0 
											 AND  TGEx.RecordCount = 1 
											 THEN 1 
											 ELSE 0 
										END)			as	TriggerCount_History_InsteadOfUpdate 
						--
						FROM		sys.triggers  TGx 
						INNER JOIN	sys.tables    Tx   ON  TGx.parent_id = Tx.[object_id] 
						INNER JOIN	sys.schemas   Sx   ON  Tx.[schema_id] = Sx.[schema_id] 
						LEFT  JOIN  (
										SELECT   TGExy.[object_id] 
										,		 SUM(CASE WHEN TGExy.[type_desc] = 'INSERT' THEN 1 ELSE 0 END)  as  InsertCount 
										,		 SUM(CASE WHEN TGExy.[type_desc] = 'UPDATE' THEN 1 ELSE 0 END)  as  UpdateCount 
										,		 SUM(CASE WHEN TGExy.[type_desc] = 'DELETE' THEN 1 ELSE 0 END)  as  DeleteCount 
										,		 COUNT(*)														as  RecordCount 
										FROM	 sys.trigger_events  TGExy 
										--WHERE	 TGExy.is_trigger_event = 1  
										GROUP BY TGExy.[object_id] 
									) 
									   TGEx  ON  TGx.[object_id] = TGEx.[object_id] 
						-- 
						WHERE		TGx.is_ms_shipped = 0 
						AND			TGx.is_disabled = 0 
						-- 
						GROUP BY	Sx.[name] 
						,			Tx.[name] 
						--	
					)  
						Trigger_Summary  ON  T.TABLE_SCHEMA = Trigger_Summary.[Schema_Name] 
										 AND T.TABLE_NAME = Trigger_Summary.[Table_Name] 
		--
		WHERE		T.TABLE_TYPE = 'BASE TABLE' 
		AND			(
						T.TABLE_SCHEMA IS NULL 
					OR  (
							RIGHT(T.TABLE_SCHEMA,LEN(@Schema_History_Suffix)) != @Schema_History_Suffix 
						AND (
							    HT.TABLE_NAME IS NULL 
							OR  coalesce(Trigger_Summary.TriggerCount_Standard_OnInsertOrUpdate,0) != 1 
							OR  coalesce(Trigger_Summary.TriggerCount_Standard_OnDelete,0) != 1 
							)
						) 
					OR  (
							RIGHT(T.TABLE_SCHEMA,LEN(@Schema_History_Suffix)) = @Schema_History_Suffix 
						AND coalesce(Trigger_Summary.TriggerCount_History_InsteadOfUpdate,0) != 1 
						) 
					)
		--
		; 
	
		SET @RowCount = @@ROWCOUNT 

		IF ( @RowCount > 0 )
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' check (3b) rows: ' + convert(varchar(20),@RowCount) ) END ; 

			SELECT	X.* 
			--
			FROM	#U_usp_C_SI_check_3b  X 
			--
			ORDER BY  X.TABLE_SCHEMA 
			,		  X.TABLE_NAME 
			-- 
			; 
		END 

		DROP TABLE #U_usp_C_SI_check_3b
		--
		;

	END TRY 
	BEGIN CATCH 

		SET @ErrorMessage = 'An error was encountered during check (3b).' 
		GOTO ERROR ; 

	END CATCH 
	-- // (3b) 
	
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'All checks completed. Review any displayed result-sets for detected issues.' ) END ; 
	
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
-- END FILE :: 003_utility_usp_Check_StructuralIntegrity.sql  
-- 