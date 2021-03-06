--
-- BEGIN FILE :: 002_utility_usp_Create_HistoryTable.sql  
--
USE [EXAMPLE]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [utility].[usp_Create_HistoryTable]
	@Schema_Name				nvarchar(256)	=	null	
,	@Table_Name					nvarchar(256)	=	null	
--
,	@IncludeContextInfoChecks	bit				=	0		
--
,	@Mode						varchar(4)		=	'VIEW'		--	'VIEW' , 'RUN'
--
,	@DEBUG						bit				=	0		
--
AS
/**************************************************************************************

	Creates a 'history' tracking table for a given input table, 
	 and configures associated triggers on the input underlying table. 

	
		Example: 


			EXEC	utility.usp_Create_HistoryTable 
						@Schema_Name				=	'dbo'		
					,	@Table_Name					=	'Example'	
					--
					,	@IncludeContextInfoChecks	=	0	
					--	
					,	@Mode						=	'VIEW'		--	'VIEW' , 'RUN' 
					--
					,	@DEBUG						=	1	
			;


	Date			Action	
	----------		----------------------------
	2020-03-07		Created initial version. 
	2020-08-11		Readied to post online. 
	2021-01-26		Include up to 4 columns [Reference_{InsertTime,UpdateTime,InsertBy,UpdateBy}] in generated '_history'-schema tables 
					 (each only if its corresponding "audit column" exists in the target/underlying table). 
	2021-03-20		Properly handling "varchar(max)" or "nvarchar(max)" data-types in target/underlying tables (gave errors before). 

**************************************************************************************/
BEGIN
	SET NOCOUNT ON;

	DECLARE		@ErrorMessage							varchar(200)	
	,			@RowCount								int				
	--
	,			@Schema_History_Suffix					nvarchar(20)		=	'_history'	
	--	
	,			@Underlying_ID_DataType					nvarchar(256)		
	--
	,			@Cursor_Column_Name						nvarchar(256)	
	,			@Cursor_Data_Type						nvarchar(256)	
	,			@Cursor_Character_Maximum_Length		int				
	,			@Cursor_Numeric_Precision				int				
	,			@Cursor_Numeric_Scale					int				
	,			@Cursor_RankNumber						int				
	--
	,			@SQL_ColumnList_ForTableCreation		varchar(max)	
	,			@SQL_ColumnList_ForTableInsert			varchar(max)	
	,			@SQL_ColumnList_ForUnderlyingSelect		varchar(max)	
	--
	,			@Underlying_InsertBy_ColumnExists		bit		
	,			@Underlying_InsertTime_ColumnExists		bit		
	,			@Underlying_UpdateBy_ColumnExists		bit		
	,			@Underlying_UpdateTime_ColumnExists		bit		
	--
	,			@Reference_AuditColumn_NamePrefix		varchar(50)		=	'Reference_' 
	--
	,			@Reference_InsertBy_ColumnNameTaken		bit	  
	,			@Reference_InsertTime_ColumnNameTaken	bit	  
	,			@Reference_UpdateBy_ColumnNameTaken		bit	  
	,			@Reference_UpdateTime_ColumnNameTaken	bit	  
	--
	,			@SQL									varchar(max)	
	,			@SQL_Batch								varchar(max)	
	--
	;
	
	--
	--

	IF @Mode IS NULL 
	BEGIN 
		SET @Mode = 'VIEW' 
	END	

	IF	@Mode IS NOT NULL 
	AND @Mode NOT IN ('VIEW','RUN')	
	BEGIN 
		SET @ErrorMessage = 'The provided @Mode value is unexpected.' 
		GOTO ERROR ; 
	END	

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 
	
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check existence and configuration of target table (check input parameters).' ) END ; 
	
		--
		--	Check that the target table exists 
		--
		IF NOT EXISTS ( SELECT	null 
						FROM	INFORMATION_SCHEMA.TABLES  T 
						WHERE	T.[TABLE_SCHEMA] = @Schema_Name 
						AND		T.[TABLE_NAME] = @Table_Name ) 
		BEGIN 
			SET @ErrorMessage = 'The provided @Schema_Name and @Table_Name combination does not exist in the database.' 
			GOTO ERROR ; 
		END	
		
		--
		--	Check that an appropriate schema exists for the new 'history' table 
		--
		IF NOT EXISTS (	SELECT	null 
						FROM	INFORMATION_SCHEMA.SCHEMATA  S 
						WHERE	S.[SCHEMA_NAME] = @Schema_Name + @Schema_History_Suffix ) 
		BEGIN 
			SET @ErrorMessage = 'The expected schema for the new history table does not exist in the database.' 
			GOTO ERROR ; 
		END 
	
	--
	--

		IF @Mode = 'RUN' 
		BEGIN 

			--
			--	Check that the proposed name for the new table is not taken by an existing object 
			--
			IF EXISTS ( SELECT		null 
						FROM		sys.objects  O 
						INNER JOIN	sys.schemas	 S  ON  O.[schema_id] = S.[schema_id] 
						--
						WHERE	S.[name] = @Schema_Name	+ @Schema_History_Suffix
						AND		O.[name] = @Table_Name ) 
			BEGIN 
				SET @ErrorMessage = 'The proposed object name for the new history table already exists in the database.' 
				GOTO ERROR ; 
			END	
		
			--
			--	Check that the target table does not have any triggers (if triggers were requested) 
			--
			IF  EXISTS ( SELECT		null	
						 FROM		sys.schemas	  S	
						 INNER JOIN	sys.tables	  T	 ON	 S.[schema_id] = T.[schema_id] 
						 						  	 AND S.[name] = @Schema_Name 
						 						  	 AND T.[name] = @Table_Name 
						 INNER JOIN	sys.triggers  X	 ON	 T.[object_id] = X.[parent_id] )	
			BEGIN 
				SET @ErrorMessage = 'Triggers exist on the target table. Drop existing triggers before running this script.'
				GOTO ERROR ; 
			END	
	
		END	

	--
	--
	
		--
		--	Check that the target table has a primary key [ID] column with integer data-type 
		--
		SELECT		@Underlying_ID_DataType = C.[DATA_TYPE] 
		FROM		INFORMATION_SCHEMA.COLUMNS	C 
		WHERE		C.[TABLE_SCHEMA] = @Schema_Name 
		AND			C.[TABLE_NAME] = @Table_Name 
		AND			C.[COLUMN_NAME] = 'ID' 
		AND			C.[DATA_TYPE] IN ('int','bigint') 
		--
		;

		IF @Underlying_ID_DataType IS NULL 
		BEGIN 
			SET @ErrorMessage = 'Either the target table has no ID column, or its ID column has an unexpected data-type.' 
			GOTO ERROR ; 
		END	

			IF ( SELECT		COUNT(*) 
				 FROM		INFORMATION_SCHEMA.TABLE_CONSTRAINTS		C	
				 INNER JOIN	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE	U	ON	C.[CONSTRAINT_NAME] = U.[CONSTRAINT_NAME] 
																			AND C.[TABLE_SCHEMA] = U.[TABLE_SCHEMA] 
																			AND C.[TABLE_NAME] = U.[TABLE_NAME] 
				 WHERE		C.[TABLE_SCHEMA] = @Schema_Name 
				 AND		C.[TABLE_NAME] = @Table_Name 
				 AND		C.[CONSTRAINT_TYPE] = 'PRIMARY KEY' ) != 1 
			OR ( SELECT		COUNT(*) 
				 FROM		INFORMATION_SCHEMA.TABLE_CONSTRAINTS		C	
				 INNER JOIN	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE	U	ON	C.[CONSTRAINT_NAME] = U.[CONSTRAINT_NAME] 
																			AND C.[TABLE_SCHEMA] = U.[TABLE_SCHEMA] 
																			AND C.[TABLE_NAME] = U.[TABLE_NAME] 
				 WHERE		C.[TABLE_SCHEMA] = @Schema_Name 
				 AND		C.[TABLE_NAME] = @Table_Name 
				 AND		C.[CONSTRAINT_TYPE] = 'PRIMARY KEY' 
				 AND		U.[COLUMN_NAME] = 'ID' ) != 1 
			BEGIN 
				SET @ErrorMessage = 'The ID column is not the primary key for the target table.' 
				GOTO ERROR ; 
			END	

	--
	--

		--
		--	Check that the target table does not include reserved history column names 
		--
		IF EXISTS ( SELECT	null 
					FROM	INFORMATION_SCHEMA.COLUMNS	C 
					WHERE	C.[TABLE_SCHEMA] = @Schema_Name 
					AND		C.[TABLE_NAME] = @Table_Name 
					AND		C.[COLUMN_NAME] IN ('ReferenceID','ActionCode') ) 	
		BEGIN 
			SET @ErrorMessage = 'The target table includes a column with a disallowed name: ''ReferenceID'' or ''ActionCode''.' 
			GOTO ERROR ; 
		END	

		--
		--	Check trigger-related column datatypes on target table 
		--
		IF	EXISTS ( SELECT	null 
					 FROM	INFORMATION_SCHEMA.COLUMNS	C 
					 WHERE	C.[TABLE_SCHEMA] = @Schema_Name 
					 AND	C.[TABLE_NAME] = @Table_Name 
					 AND	C.[COLUMN_NAME] IN ('InsertTime','UpdateTime') 
					 AND	C.[DATA_TYPE] NOT IN ('datetime','smalldatetime') ) 
		BEGIN 
			SET @ErrorMessage = 'A trigger-related column ''InsertTime'' or ''UpdateTime'' has an unexpected data-type.' 
			GOTO ERROR ; 
		END	
		
		IF	EXISTS ( SELECT	null 
					 FROM	INFORMATION_SCHEMA.COLUMNS	C 
					 WHERE	C.[TABLE_SCHEMA] = @Schema_Name 
					 AND	C.[TABLE_NAME] = @Table_Name 
					 AND	C.[COLUMN_NAME] IN ('InsertBy','UpdateBy') 
					 AND	C.[DATA_TYPE] NOT LIKE ('%varchar%'/*,'date'*/) ) 
		BEGIN 
			SET @ErrorMessage = 'A trigger-related column ''InsertBy'' or ''UpdateBy'' has an unexpected data-type.' 
			GOTO ERROR ; 
		END	
		
	--
	--

		SELECT	@Underlying_InsertTime_ColumnExists	 =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = 'InsertTime' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		,		@Underlying_InsertBy_ColumnExists	 =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = 'InsertBy'   THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		,		@Underlying_UpdateTime_ColumnExists	 =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = 'UpdateTime' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		,		@Underlying_UpdateBy_ColumnExists	 =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = 'UpdateBy'   THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		--
		,		@Reference_InsertBy_ColumnNameTaken	   =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = @Reference_AuditColumn_NamePrefix + 'InsertTime' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		,		@Reference_InsertTime_ColumnNameTaken  =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = @Reference_AuditColumn_NamePrefix + 'InsertBy'   THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		,		@Reference_UpdateBy_ColumnNameTaken	   =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = @Reference_AuditColumn_NamePrefix + 'UpdateTime' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		,		@Reference_UpdateTime_ColumnNameTaken  =  CASE WHEN SUM(CASE WHEN C.COLUMN_NAME = @Reference_AuditColumn_NamePrefix + 'UpdateBy'   THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END 
		-- 
		FROM	INFORMATION_SCHEMA.COLUMNS	C 
		WHERE	C.[TABLE_SCHEMA] = @Schema_Name 
		AND		C.[TABLE_NAME] = @Table_Name 
		--
		AND		C.[COLUMN_NAME] IN ( 'InsertTime' 
		                           , 'InsertBy' 
								   , 'UpdateTime' 
								   , 'UpdateBy' 
								   -- 
								   , @Reference_AuditColumn_NamePrefix + 'InsertTime' 
								   , @Reference_AuditColumn_NamePrefix + 'InsertBy' 
								   , @Reference_AuditColumn_NamePrefix + 'UpdateTime' 
								   , @Reference_AuditColumn_NamePrefix + 'UpdateBy' 
								   -- 
								   )  
		-- 
		;  

	--
	--

		--
		--	Adjust (if necessary) uppercase & lowercase letters in input parameters 
		--

		SELECT		@Schema_Name = T.[TABLE_SCHEMA] 
		,			@Table_Name = T.[TABLE_NAME] 
		--
		FROM		INFORMATION_SCHEMA.TABLES  T 
		WHERE		T.[TABLE_SCHEMA] = @Schema_Name 
		AND			T.[TABLE_NAME] = @Table_Name 
		--
		;

	--
	--
	--
	--	BEGIN CONSTRUCTING REQUESTED SQL STATEMENTS 
	--
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Generate relevant table column lists for SQL statements.' ) END ; 
		
		SET @SQL_ColumnList_ForTableCreation	 =  ''  ; 
		SET @SQL_ColumnList_ForTableInsert		 =  ''  ; 
		SET @SQL_ColumnList_ForUnderlyingSelect	 =  ''  ; 

	--
	--

	DECLARE #ColumnCursor CURSOR LOCAL READ_ONLY FORWARD_ONLY STATIC 
	
				FOR		SELECT		C.[COLUMN_NAME]	
						,			C.[DATA_TYPE] 
						--
						,			C.[CHARACTER_MAXIMUM_LENGTH] 
						,			C.[NUMERIC_PRECISION] 
						,			C.[NUMERIC_SCALE] 
						--
						,			RANK() OVER ( ORDER BY CASE WHEN X.OrderRank IS NULL 
																THEN 0 
																ELSE 1 
														   END DESC  
														,  X.OrderRank ASC 
														,  C.ORDINAL_POSITION ASC )	 as  RankNumber 
						--	
						FROM	INFORMATION_SCHEMA.COLUMNS	C 
						--
						LEFT  JOIN  (   SELECT  Z.AuditField_Name 
										,		@Reference_AuditColumn_NamePrefix + Z.AuditField_Name  as  Reference_AuditColumn_Name  
										,		Z.OrderRank 
										,		Z.Reference_ColumnNameTaken 
										-- 
										FROM (
												VALUES  ( 'InsertTime' , 1 , @Reference_InsertTime_ColumnNameTaken ) 
												,		( 'InsertBy'   , 2 , @Reference_InsertBy_ColumnNameTaken   ) 
												,		( 'UpdateTime' , 3 , @Reference_UpdateTime_ColumnNameTaken ) 
												,		( 'UpdateBy'   , 4 , @Reference_UpdateBy_ColumnNameTaken   ) 
											 ) 
											    Z  ( AuditField_Name , OrderRank , Reference_ColumnNameTaken ) 
									    -- 
									) 
									   X  ON  C.COLUMN_NAME = X.AuditField_Name   
						--
						WHERE	C.[TABLE_SCHEMA] = @Schema_Name 
						AND		C.[TABLE_NAME] = @Table_Name 
						--
						AND		(  X.AuditField_Name IS NULL 
								OR coalesce(X.Reference_ColumnNameTaken,1) = 0 ) 
						--
						AND		C.COLUMN_NAME NOT IN ('ReferenceID','ActionCode') 
						-- 
						ORDER BY	CASE WHEN X.OrderRank IS NOT NULL 
										 THEN 1  
										 ELSE 0  
									END DESC  
						,			X.OrderRank ASC 
						,			C.ORDINAL_POSITION ASC 
						--
					  
	OPEN #ColumnCursor  
	
	WHILE 1=1 
	BEGIN 

		FETCH NEXT 
		FROM	#ColumnCursor 
		INTO	@Cursor_Column_Name						
			,	@Cursor_Data_Type						
			--
			,	@Cursor_Character_Maximum_Length		
			,	@Cursor_Numeric_Precision			
			,	@Cursor_Numeric_Scale				
			--
			,	@Cursor_RankNumber	
			--

		IF @@FETCH_STATUS != 0 BREAK ; 
		

		SET @SQL_ColumnList_ForTableCreation = @SQL_ColumnList_ForTableCreation 
			+ '		, ' + CASE WHEN @Cursor_Column_Name = 'ID' 
							   THEN '[ReferenceID]' 
							   --
							   WHEN @Cursor_Column_Name IN ( 'InsertTime' , 'InsertBy' , 'UpdateTime' , 'UpdateBy' ) 
							   THEN '[' + @Reference_AuditColumn_NamePrefix + @Cursor_Column_Name + ']' 
							   --
							   ELSE '[' + @Cursor_Column_Name + ']' 
							   --
						  END 
				    + ' ' + @Cursor_Data_Type + CASE WHEN @Cursor_Data_Type IN ('char','varchar','nchar','nvarchar') 
												     THEN '(' + CASE WHEN @Cursor_Character_Maximum_Length = -1 -- !! represents MAX ?? !! 
																	 THEN 'max' 
																	 ELSE try_convert(varchar(50),@Cursor_Character_Maximum_Length) 
																END + ')' 
													 WHEN @Cursor_Data_Type = 'decimal' 
													 THEN '(' + convert(varchar(50),@Cursor_Numeric_Precision) + ',' + convert(varchar(50),@Cursor_Numeric_Scale) + ')' 
												     ELSE '' 
											    END 
				  + ' null 
			  ' ; 
			  
		SET @SQL_ColumnList_ForTableInsert = @SQL_ColumnList_ForTableInsert 
			+ '	,	' + CASE WHEN @Cursor_Column_Name = 'ID' 
							 THEN '[ReferenceID]' 
							 --
							 WHEN @Cursor_Column_Name IN ( 'InsertTime' , 'InsertBy' , 'UpdateTime' , 'UpdateBy' ) 
							 THEN '[' + @Reference_AuditColumn_NamePrefix + @Cursor_Column_Name + ']' 
							 -- 
							 ELSE '[' + @Cursor_Column_Name + ']' 
							 --
						END + CASE WHEN @Cursor_RankNumber < @@CURSOR_ROWS THEN ' 
			  ' ELSE '' END ; 

		SET @SQL_ColumnList_ForUnderlyingSelect = @SQL_ColumnList_ForUnderlyingSelect 
			+ '		,		X.[' + @Cursor_Column_Name + ']' + CASE WHEN @Cursor_RankNumber < @@CURSOR_ROWS THEN ' 
			  ' ELSE '' END ; 

	END 

	CLOSE #ColumnCursor 
	DEALLOCATE #ColumnCursor 

		--
		--

		SET @SQL_ColumnList_ForTableCreation	 =  RTRIM( @SQL_ColumnList_ForTableCreation    )  ; 
		SET @SQL_ColumnList_ForTableInsert		 =  RTRIM( @SQL_ColumnList_ForTableInsert	   )  ; 
		SET @SQL_ColumnList_ForUnderlyingSelect  =  RTRIM( @SQL_ColumnList_ForUnderlyingSelect )  ; 
		
		--
		--

			IF @SQL_ColumnList_ForTableCreation IS NULL 
			OR @SQL_ColumnList_ForTableInsert IS NULL 
			OR @SQL_ColumnList_ForUnderlyingSelect IS NULL 
			BEGIN 
				SET @ErrorMessage = 'One or more than one ''ColumnList'' string variable has NULL value.' 
				GOTO ERROR ; 
			END	

		--
		--

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Generate SQL script.' ) END ; 

	--
	--

		SET @SQL = ' 

			--
			-- create history table 
			--

			CREATE TABLE ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
			(
				ID				' + CASE WHEN @Underlying_ID_DataType = 'bigint' 
										 THEN 'bigint' 
										 ELSE 'int' 
									END + '			identity(1,1)	not null 
			--
			,	InsertTime		datetime		not null 
			,	InsertBy		varchar(256)	not null 
			,	ActionCode		char(1)			not null 
			--

			'
		+	@SQL_ColumnList_ForTableCreation 	
		+	'
			--
			,	CONSTRAINT PK_history_' + @Table_Name + ' PRIMARY KEY CLUSTERED 
				( 
					ID	ASC	
				) 
			)
			;	

			; GO ; 

			--
			--

			ALTER TABLE ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
				ADD CONSTRAINT CK_history_' + @Table_Name + '_ActionCode CHECK ( ActionCode IN (''U'',''D'') ) 
			; GO ; 
			ALTER TABLE ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
				CHECK CONSTRAINT CK_history_' + @Table_Name + '_ActionCode 
			; GO ; 
			
			--
			--

			ALTER TABLE ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
				ADD CONSTRAINT DF_history_' + @Table_Name + '_InsertBy DEFAULT ( suser_sname() ) FOR InsertBy 
			; GO ; 
			ALTER TABLE ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
				ADD CONSTRAINT DF_history_' + @Table_Name + '_InsertTime DEFAULT ( getdate() ) FOR InsertTime 
			; GO ; 

			--
			--

			; GO ; 

			CREATE TRIGGER ' + @Schema_Name + @Schema_History_Suffix + '.TG_history_' + @Table_Name + '_Update ON ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
			INSTEAD OF UPDATE 
			AS 
				SET NOCOUNT ON ; 
			; GO ; 
			
			--
			--

			;

		' 

		SET @SQL = @SQL + ' 

			--
			--	create triggers on underlying table 
			--

			; GO ; 

			CREATE TRIGGER ' + @Schema_Name + '.TG_' + @Table_Name + '_Delete ON ' + @Schema_Name + '.' + @Table_Name + ' 
			AFTER DELETE 
			AS 
				SET NOCOUNT ON ; 
			' + CASE WHEN @IncludeContextInfoChecks = 1 
					 THEN '	
			IF convert(varchar(127),CONTEXT_INFO()) IS NULL 
			OR convert(varchar(127),CONTEXT_INFO()) NOT IN ( ''DELETE_TRIGGERS_DISABLED'' ) 
			BEGIN 
			--
			-- 
			' ELSE '' 
			END	+ ' 
				INSERT INTO ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
				( 
					ActionCode 
				--
			' + @SQL_ColumnList_ForTableInsert + ' 
				) 

					SELECT	''D'' 
					--
			' + @SQL_ColumnList_ForUnderlyingSelect + ' 
					FROM	deleted		X 
					; 
			' + CASE WHEN @IncludeContextInfoChecks = 1 
					 THEN ' 
			--
			--
			END ' ELSE '' 
			END	+ ' 
			; GO ; 

			CREATE TRIGGER ' + @Schema_Name + '.TG_' + @Table_Name + '_InsertUpdate ON ' + @Schema_Name + '.' + @Table_Name + ' 
			AFTER INSERT, UPDATE 
			AS 
				SET NOCOUNT ON ; 

				IF EXISTS ( SELECT	null 
							FROM	deleted  X	) 
				BEGIN -- trigger is firing after an UPDATE statement 
			' + CASE WHEN @IncludeContextInfoChecks = 1 
					 THEN 
			' 
					IF convert(varchar(127),CONTEXT_INFO()) IS NULL 
					OR convert(varchar(127),CONTEXT_INFO()) NOT IN ( ''UPDATE_TRIGGERS_DISABLED'' ) 
					BEGIN  
					--
					-- ' ELSE '' 
			END	+ ' 
				
				--
				--
				
					' + CASE WHEN @Underlying_UpdateTime_ColumnExists = 1 
							 OR   @Underlying_UpdateBy_ColumnExists = 1 
							 THEN 'UPDATE		P 
					SET ' + CASE WHEN @Underlying_UpdateTime_ColumnExists = 1 
								 AND  @Underlying_UpdateBy_ColumnExists = 1 
								 THEN '		P.UpdateTime = getdate() 
					,			P.UpdateBy = suser_sname() 
					'			 WHEN @Underlying_UpdateTime_ColumnExists = 1 
								 AND  @Underlying_UpdateBy_ColumnExists = 0 
								 THEN '		P.UpdateTime = getdate() 
					'			 WHEN @Underlying_UpdateTime_ColumnExists = 0 
								 AND  @Underlying_UpdateBy_ColumnExists = 1 
								 THEN '		P.UpdateBy = suser_sname() 
					'		END 
				+	'FROM		inserted	I 
					INNER JOIN	' + @Schema_Name + '.' + @Table_Name + ' P ON I.ID = P.ID 
					; 
					   ' ELSE '' 
						 END 
				+ ' 
				INSERT INTO ' + @Schema_Name + @Schema_History_Suffix + '.' + @Table_Name + ' 
				( 
					ActionCode 
				--
			' + @SQL_ColumnList_ForTableInsert + ' 
				) 

					SELECT	''U'' 
					-- 
			' + @SQL_ColumnList_ForUnderlyingSelect + ' 
					FROM	deleted		X 
					;

				' + CASE WHEN @IncludeContextInfoChecks = 1 
					 THEN ' 
					--
					--
					END 
			' 	ELSE '' 
			END	+ ' 
				END	' + CASE WHEN @Underlying_InsertTime_ColumnExists = 1 
							 OR	  @Underlying_InsertBy_ColumnExists = 1 
							 OR	  @Underlying_UpdateTime_ColumnExists = 1 
							 OR	  @Underlying_UpdateBy_ColumnExists = 1 
							 THEN ' 
				ELSE BEGIN 
				' + CASE WHEN @IncludeContextInfoChecks = 1 
						 THEN ' 
					IF convert(varchar(127),CONTEXT_INFO()) IS NULL 
					OR convert(varchar(127),CONTEXT_INFO()) NOT IN ( ''INSERT_TRIGGERS_DISABLED'' ) 
					BEGIN 
					--
					-- ' ELSE '' 
					END	+ ' 

					UPDATE		P 
					SET			' +	CASE WHEN @Underlying_InsertTime_ColumnExists = 1 
									 THEN 'P.InsertTime = getdate() 
					'				   + CASE WHEN @Underlying_InsertBy_ColumnExists = 1 
											  OR   @Underlying_UpdateTime_ColumnExists = 1 
											  OR   @Underlying_UpdateBy_ColumnExists = 1 
											  THEN ',			' 
											  ELSE '			' 
										 END 
									  ELSE '' 
								END 
							  + CASE WHEN @Underlying_InsertBy_ColumnExists = 1 
									 THEN 'P.InsertBy = suser_sname() 
					'				   + CASE WHEN @Underlying_UpdateTime_ColumnExists = 1 
											  OR   @Underlying_UpdateBy_ColumnExists = 1 
											  THEN ',			' 
											  ELSE '			' 
										 END 
									  ELSE '' 
								END 
							  + CASE WHEN @Underlying_UpdateTime_ColumnExists = 1 
									 THEN 'P.UpdateTime = getdate() 
					'				   + CASE WHEN @Underlying_UpdateBy_ColumnExists = 1 
											  THEN ',			' 
											  ELSE '			' 
										 END 
									  ELSE '' 
								END 
							  + CASE WHEN @Underlying_UpdateBy_ColumnExists = 1 
									 THEN 'P.UpdateBy = suser_sname() ' 
									 ELSE '' 
								END + ' 
					FROM		inserted	I 
					INNER JOIN	' + @Schema_Name + '.' + @Table_Name + ' P ON I.ID = P.ID 
					;
					' + CASE WHEN @IncludeContextInfoChecks = 1 
							 THEN ' 
					--
					--
					END ' ELSE '' 
					END	+ ' 

				END 
				' 
					ELSE '' 
					END	+ ' 
			; GO ; 

			' 

	--
	--
	--
	--	FINISHED CONSTRUCTING REQUESTED SQL STATEMENTS 
	--
	--
	--
	
	IF @Mode = 'VIEW' 
	BEGIN 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Print SQL script.' ) END ; 

			PRINT REPLACE( @SQL	, '; GO ;' , 'GO' ) 
			;

	END	
	ELSE IF @Mode = 'RUN' 
	BEGIN 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Execute SQL script.' ) END ; 

			BEGIN TRY 
				BEGIN TRANSACTION 
					
					WHILE LEN( @SQL ) > 0 
					BEGIN 
						
						SET @SQL_Batch = CASE WHEN CHARINDEX( '; GO ;' , @SQL , 0 ) = 0 
											  THEN @SQL 
											  ELSE LEFT( @SQL , CHARINDEX( '; GO ;' , @SQL , 0 ) - 1 ) 
										 END 

						SET @SQL = CASE WHEN CHARINDEX( '; GO ;' , @SQL , 0 ) = 0 
										THEN '' 
										ELSE RIGHT( @SQL , LEN(@SQL) - LEN(@SQL_Batch) - LEN('; GO ;') ) 
								   END 
						
						EXEC ( @SQL_Batch )	
						;

					END	

				COMMIT TRANSACTION 
			END TRY 
			BEGIN CATCH 
				ROLLBACK TRANSACTION 

				SET @ErrorMessage = 'An error was encountered while executing SQL script.' 
				GOTO ERROR 
			END CATCH 

	END 

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
-- END FILE :: 002_utility_usp_Create_HistoryTable.sql 
--