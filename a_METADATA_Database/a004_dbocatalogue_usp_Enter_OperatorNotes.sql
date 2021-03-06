--
-- BEGIN FILE :: a004_dbocatalogue_usp_Enter_OperatorNotes.sql 
--
USE [a_METADATA] 
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbocatalogue.usp_Enter_OperatorNotes 
--
	@Mode		varchar(10)		=	'TEST'	--	'TEST' , 'LIVE'	
--
,   @DatabaseName	 varchar(256)	=	null 
,   @RoleName		 varchar(256)	=	null 
,   @SchemaName		 varchar(256)	=   null 
,   @ObjectName		 varchar(256)	=   null 
,   @ParameterName	 varchar(256)   =   null 
,   @ColumnName		 varchar(256)   =   null 
--
,	@PurposeOrMeaning_Description  varchar(1080)  =  null 
,	@TechnicalNotes				   varchar(1080)  =  null 
--
,	@ReplaceExistingValuesWithNULL   bit  =  0 
--
,	@DEBUG		bit				=	0 
--
AS
/**************************************************************************************

	Updates 2 columns for 1 record in 1 [dbocatalogue]-schema table: 
	  
	  the updated columns are the 2 "operator notes" text-fields 
	( [PurposeOrMeaning_Description] and [TechnicalNotes] ) 
	
	and the table is determined by the 6 "@[...]Name" parameter values: 
	
	  for example, 
	   to update the [TupleStructureColumn] record for a Column in a Table or View, 
	    provide appropriate values for the parameters 
	     @DatabaseName, @SchemaName, @ObjectName, and @ColumnName 
		  and leave @RoleName and @ParameterName NULL;  
		to update the [TupleStructure] record for a Table or View, 
		 provide appropriate values for the parameters 
		  @DatabaseName, @SchemaName, @ObjectName 
		   and leave @RoleName, @ParameterName, and @ColumnName NULL. 


		Example: 
		

			EXEC	dbocatalogue.usp_Enter_OperatorNotes
						@Mode   =  'TEST' 
					--
					,   @DatabaseName	 =   'a_METADATA' 
					,   @RoleName		 =   null 
					,	@SchemaName		 =   'dbocatalogue' 
					,   @ObjectName		 =   null 
					,	@ParameterName	 =   null 
					,	@ColumnName		 =   null 
					--
					,	@PurposeOrMeaning_Description  =  'A schema containing lists of core database elements (tables, views, columns, functions, procedures, etc.) in "scoped"/tracked databases' 
					,	@TechnicalNotes				   =  'Developed during September 2020' 
					--
					,	@ReplaceExistingValuesWithNULL  =  0 
					--
					,	@DEBUG  =   1  
			; 


	Date			Action	
	----------		----------------------------
	2020-09-27		Created initial version. 

**************************************************************************************/
BEGIN
	SET NOCOUNT ON;

	DECLARE	  @ErrorMessage	  varchar(200) 
	,		  @RowCount		  int			 
	--
	--
	,		@NEW_LatestUpdateToObjectRecordDocumentation	datetime	
	--
	--
	,		@ScopedDatabaseID	int	 
	--
	,		@DatabaseRoleID		bigint  
	--
	,		@DatabaseSchemaID	bigint	 
	--
	,		@TupleStructureID		  bigint	 
	,		@ScalarValuedFunctionID	  bigint	 
	,		@TableValuedFunctionID	  bigint	 
	,		@StoredProcedureID		  bigint	 
	,		@SynonymAliasID			  bigint	 
	--
	,		@ScalarValuedFunctionParameterID   bigint	 
	,		@TableValuedFunctionParameterID	   bigint	 
	,		@StoredProcedureParameterID		   bigint	 
	--
	,		@TupleStructureColumnID		   bigint	 
	,		@TableValuedFunctionColumnID   bigint	 
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
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 
	
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check input parameters.' ) END ; 
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Identify database-object-record for text-field-value update.' ) END ; 

		--
		--  attempt to find non-ambiguous database object using 6 "@[...]Name" parameters 
		--

		IF @DatabaseName IS NULL 
		BEGIN 
			SET @ErrorMessage = 'A @DatabaseName parameter-value must be provided (must be NOT NULL).' ; 
			GOTO ERROR ; 
		END 

			SELECT @ScopedDatabaseID = X.ID 
			, @DatabaseName = X.DatabaseName -- standardizing capitalization 
			FROM serverconfig.ScopedDatabase  X  
			WHERE X.DatabaseName = @DatabaseName 
			--
			; 

				IF @ScopedDatabaseID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @DatabaseName parameter-value was not found in the [serverconfig].[ScopedDatabase] table.' ; 
					GOTO ERROR ; 
				END 
				
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' ScopedDatabaseID :: ' + convert(varchar(50),@ScopedDatabaseID) ) END ; 

	--
	--
			
		IF @RoleName IS NOT NULL 
		BEGIN 
			
			IF @SchemaName IS NOT NULL 
			OR @ObjectName IS NOT NULL
			OR @ParameterName IS NOT NULL
			OR @ColumnName IS NOT NULL	
			BEGIN 
				SET @ErrorMessage = 'If @RoleName is NOT NULL, the other 4 parameters @SchemaName, @ObjectName, @ParameterName, and @ColumnName must all be NULL.' 
				GOTO ERROR ; 
			END

			--
			--

			SELECT @DatabaseRoleID = X.ID 
			, @RoleName = X.RoleName 
			FROM dbocatalogue.DatabaseRole  X  
			WHERE X.ScopedDatabaseID = @ScopedDatabaseID 
			AND X.RoleName = @RoleName 
			--
			; 

				IF @DatabaseRoleID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @RoleName parameter-value was not found in the [dbocatalogue].[DatabaseRole] table, associated to the appropriate ScopedDatabaseID value.' ; 
					GOTO ERROR ; 
				END 
				
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' DatabaseRoleID :: ' + convert(varchar(50),@DatabaseRoleID) ) END ; 

		END 
		
	--
	--
		
		IF @SchemaName IS NULL 
		BEGIN 

			IF @ObjectName IS NOT NULL 
			OR @ParameterName IS NOT NULL 
			OR @ColumnName IS NOT NULL 
			BEGIN
				SET @ErrorMessage = 'If @SchemaName is NULL, the other 3 parameters @ObjectName, @ParameterName, and @ColumnName must all be NULL too.' 
				GOTO ERROR ; 
			END

		END 
		ELSE IF @SchemaName IS NOT NULL 
		BEGIN 
			
			IF @ParameterName IS NOT NULL 
			AND @ColumnName IS NOT NULL	
			BEGIN 
				SET @ErrorMessage = 'At least 1 of the 2 parameters @ParameterName and @ColumnName must be NULL (no [dbocatalogue] record represents both a parameter and a column).' 
				GOTO ERROR ; 
			END

			IF @ParameterName IS NOT NULL 
			OR @ColumnName IS NOT NULL 
			BEGIN 
				IF @ObjectName IS NULL 
				BEGIN 
					SET @ErrorMessage = 'If either of @ParameterName or @ColumnName is NOT NULL, a valid parameter-value for @ObjectName must be provided also.' 
					GOTO ERROR ; 
				END 
			END

			--
			--

			SELECT @DatabaseSchemaID = X.ID 
			, @SchemaName = X.SchemaName 
			FROM dbocatalogue.DatabaseSchema  X  
			WHERE X.ScopedDatabaseID = @ScopedDatabaseID 
			AND X.SchemaName = @SchemaName 
			--
			; 

				IF @DatabaseSchemaID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @SchemaName parameter-value was not found in the [dbocatalogue].[DatabaseSchema] table, associated to the appropriate ScopedDatabaseID value.' ; 
					GOTO ERROR ; 
				END 

			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' DatabaseSchemaID :: ' + convert(varchar(50),@DatabaseSchemaID) ) END ; 

		END 
		
	--
	--
			
		IF @ObjectName IS NOT NULL 
		BEGIN 

				--
				--  check all candidate "Object" tables ... then, make sure exactly 1 variable value is "set" to a valid ID value  
				--	
				
			SELECT @TupleStructureID = X.ID 
			, @ObjectName = X.ObjectName 
			FROM dbocatalogue.TupleStructure  X  
			WHERE X.DatabaseSchemaID = @DatabaseSchemaID 
			AND X.ObjectName = @ObjectName 
			--
			; 
			SELECT @ScalarValuedFunctionID = X.ID 
			, @ObjectName = X.ObjectName 
			FROM dbocatalogue.ScalarValuedFunction  X  
			WHERE X.DatabaseSchemaID = @DatabaseSchemaID 
			AND X.ObjectName = @ObjectName 
			--
			; 
			SELECT @TableValuedFunctionID = X.ID 
			, @ObjectName = X.ObjectName 
			FROM dbocatalogue.TableValuedFunction  X  
			WHERE X.DatabaseSchemaID = @DatabaseSchemaID 
			AND X.ObjectName = @ObjectName 
			--
			; 
			SELECT @StoredProcedureID = X.ID 
			, @ObjectName = X.ObjectName 
			FROM dbocatalogue.StoredProcedure  X  
			WHERE X.DatabaseSchemaID = @DatabaseSchemaID 
			AND X.ObjectName = @ObjectName 
			--
			; 
			SELECT @SynonymAliasID = X.ID 
			, @ObjectName = X.ObjectName 
			FROM dbocatalogue.SynonymAlias  X  
			WHERE X.DatabaseSchemaID = @DatabaseSchemaID 
			AND X.ObjectName = @ObjectName 
			--
			; 
			
				IF  @TupleStructureID IS NULL 
				AND @ScalarValuedFunctionID IS NULL 	  
				AND @TableValuedFunctionID IS NULL 	  
				AND @StoredProcedureID IS NULL 		  
				AND @SynonymAliasID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @ObjectName parameter-value was not found in any [dbocatalogue] "Object" tables, associated to the appropriate DatabaseSchemaID value.' 
					GOTO ERROR 
				END 
				
				IF  CASE WHEN @TupleStructureID IS NULL         THEN 0 ELSE 1 END 
				 +  CASE WHEN @ScalarValuedFunctionID IS NULL   THEN 0 ELSE 1 END 
				 +  CASE WHEN @TableValuedFunctionID IS NULL    THEN 0 ELSE 1 END 
				 +  CASE WHEN @StoredProcedureID IS NULL        THEN 0 ELSE 1 END 
				 +  CASE WHEN @SynonymAliasID IS NULL           THEN 0 ELSE 1 END 
				 != 1 
				BEGIN 
					IF @Mode = 'TEST' 
					BEGIN 
						SELECT	'Ambiguously mapped @ObjectName value (multiple matches):'  as  Information 
						--
						,		@DatabaseName		as	DatabaseName 
						,		@SchemaName			as  SchemaName 
						,		@ObjectName			as  ObjectName 
						--
						,		X.VariableName 
						,		X.VariableValue 
						--
						FROM	(
									VALUES	( 1 , '@TupleStructureID' , @TupleStructureID ) 
									,		( 2 , '@ScalarValuedFunctionID' , @ScalarValuedFunctionID ) 
									,		( 3 , '@TableValuedFunctionID' , @TableValuedFunctionID ) 
									,		( 4 , '@StoredProcedureID' , @StoredProcedureID ) 
									,		( 5 , '@SynonymAliasID' , @SynonymAliasID ) 
								)	
									X	( DisplayOrderRank , VariableName , VariableValue ) 
						--
						ORDER BY  X.DisplayOrderRank  ASC  
						-- 
						; 
					END		

					SET @ErrorMessage = 'The provided @ObjectName parameter-value was ambiguously mapped, found in more than one [dbocatalogue] table associated to the appropriate DatabaseSchemaID value.' 
					GOTO ERROR 
				END 
				
			IF @DEBUG = 1 
			BEGIN 
				IF @TupleStructureID IS NOT NULL BEGIN PRINT dbo.fcn_DebugInfo( ' TupleStructureID :: ' + convert(varchar(50),@TupleStructureID) ) END ;
				IF @ScalarValuedFunctionID IS NOT NULL BEGIN PRINT dbo.fcn_DebugInfo( ' ScalarValuedFunctionID :: ' + convert(varchar(50),@ScalarValuedFunctionID) ) END ;
				IF @TableValuedFunctionID IS NOT NULL BEGIN PRINT dbo.fcn_DebugInfo( ' TableValuedFunctionID :: ' + convert(varchar(50),@TableValuedFunctionID) ) END ;
				IF @StoredProcedureID IS NOT NULL BEGIN PRINT dbo.fcn_DebugInfo( ' StoredProcedureID :: ' + convert(varchar(50),@StoredProcedureID) ) END ;
				IF @SynonymAliasID IS NOT NULL BEGIN PRINT dbo.fcn_DebugInfo( ' SynonymAliasID :: ' + convert(varchar(50),@SynonymAliasID) ) END ;
			END 

		END 
		
	--
	--
	
		IF @ParameterName IS NOT NULL 
		BEGIN 
			IF @ScalarValuedFunctionID IS NOT NULL 
			BEGIN 				
				SELECT @ScalarValuedFunctionParameterID = X.ID 
				, @ParameterName = X.ParameterName 
				FROM dbocatalogue.ScalarValuedFunctionParameter  X  
				WHERE X.ScalarValuedFunctionID = @ScalarValuedFunctionID 
				AND X.ParameterName = @ParameterName 
				--
				; 
				
				IF @ScalarValuedFunctionParameterID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @ParameterName parameter-value was not found in the [dbocatalogue].[ScalarValuedFunctionParameter] table, associated to the appropriate ScalarValuedFunctionID value.' 
					GOTO ERROR 
				END 

				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' ScalarValuedFunctionParameterID :: ' + convert(varchar(50),@ScalarValuedFunctionParameterID) ) END ; 

			END 
			ELSE IF @TableValuedFunctionID IS NOT NULL 
			BEGIN 				
				SELECT @TableValuedFunctionParameterID = X.ID 
				, @ParameterName = X.ParameterName 
				FROM dbocatalogue.TableValuedFunctionParameter  X  
				WHERE X.TableValuedFunctionID = @TableValuedFunctionID 
				AND X.ParameterName = @ParameterName 
				--
				; 
				
				IF @TableValuedFunctionParameterID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @ParameterName parameter-value was not found in the [dbocatalogue].[TableValuedFunctionParameter] table, associated to the appropriate TableValuedFunctionID value.' 
					GOTO ERROR 
				END 

				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' TableValuedFunctionParameterID :: ' + convert(varchar(50),@TableValuedFunctionParameterID) ) END ; 

			END 
			ELSE IF @StoredProcedureID IS NOT NULL 
			BEGIN 				
				SELECT @StoredProcedureParameterID = X.ID 
				, @ParameterName = X.ParameterName 
				FROM dbocatalogue.StoredProcedureParameter  X  
				WHERE X.StoredProcedureID = @StoredProcedureID 
				AND X.ParameterName = @ParameterName 
				--
				; 
				
				IF @StoredProcedureParameterID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @ParameterName parameter-value was not found in the [dbocatalogue].[StoredProcedureParameter] table, associated to the appropriate StoredProcedureID value.' 
					GOTO ERROR 
				END 

				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' StoredProcedureParameterID :: ' + convert(varchar(50),@StoredProcedureParameterID) ) END ; 

			END 
			ELSE BEGIN 
				
				SET @ErrorMessage = '@ParameterName is provided (NOT NULL), but the referenced Object''s "type" does not have "parameter" information in [dbocatalogue].' 
				GOTO ERROR 

			END
		END 
		
	--
	--
			
		IF @ColumnName IS NOT NULL 
		BEGIN 
			IF @TupleStructureID IS NOT NULL 
			BEGIN 				
				SELECT @TupleStructureColumnID = X.ID 
				, @ColumnName = X.ColumnName 
				FROM dbocatalogue.TupleStructureColumn  X  
				WHERE X.TupleStructureID = @TupleStructureID 
				AND X.ColumnName = @ColumnName 
				--
				; 
				
				IF @TupleStructureColumnID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @ColumnName parameter-value was not found in the [dbocatalogue].[TupleStructureColumn] table, associated to the appropriate TupleStructureID value.' 
					GOTO ERROR 
				END 

				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' TupleStructureColumnID :: ' + convert(varchar(50),@TupleStructureColumnID) ) END ; 

			END 
			ELSE IF @TableValuedFunctionID IS NOT NULL 
			BEGIN 				
				SELECT @TableValuedFunctionColumnID = X.ID 
				, @ColumnName = X.ColumnName 
				FROM dbocatalogue.TableValuedFunctionColumn  X  
				WHERE X.TableValuedFunctionID = @TableValuedFunctionID 
				AND X.ColumnName = @ColumnName 
				--
				; 
				
				IF @TableValuedFunctionColumnID IS NULL 
				BEGIN 
					SET @ErrorMessage = 'The provided @ColumnName parameter-value was not found in the [dbocatalogue].[TableValuedFunctionColumn] table, associated to the appropriate TableValuedFunctionID value.' 
					GOTO ERROR 
				END 

				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' TableValuedFunctionColumnID :: ' + convert(varchar(50),@TableValuedFunctionColumnID) ) END ; 

			END 
			ELSE BEGIN 
				
				SET @ErrorMessage = '@ColumnName is provided (NOT NULL), but the referenced Object''s "type" does not have "column" information in [dbocatalogue].' 
				GOTO ERROR 

			END
		END 

	--
	--
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Record identified.' ) END ; 
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' @Mode  =  ''' + @Mode + '''' ) END ; 

	--
	--

		IF @Mode = 'TEST' 
		BEGIN 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Display summary of planned table-record update.' ) END ; 

				SELECT		'Proposed Record Update:'  as  Information 
				,			CASE WHEN @TableValuedFunctionColumnID IS NOT NULL THEN 'TableValuedFunctionColumn' 
								 WHEN @TupleStructureColumnID IS NOT NULL THEN 'TupleStructureColumn' 
								 --
								 WHEN @StoredProcedureParameterID IS NOT NULL THEN 'StoredProcedureParameter' 
								 WHEN @TableValuedFunctionParameterID IS NOT NULL THEN 'TableValuedFunctionParameter' 
								 WHEN @ScalarValuedFunctionParameterID IS NOT NULL THEN 'ScalarValuedFunctionParameter'  
								 --
								 WHEN @SynonymAliasID IS NOT NULL THEN 'SynonymAlias' 
								 WHEN @StoredProcedureID IS NOT NULL THEN 'StoredProcedure' 
								 WHEN @TableValuedFunctionID IS NOT NULL THEN 'TableValuedFunction'  
								 WHEN @ScalarValuedFunctionID IS NOT NULL THEN 'ScalarValuedFunction'  
								 WHEN @TupleStructureID IS NOT NULL THEN 'TupleStructure'  
								 --
								 WHEN @DatabaseSchemaID IS NOT NULL THEN 'DatabaseSchema' 
								 --
								 WHEN @DatabaseRoleID IS NOT NULL THEN 'DatabaseRole' 
								 --
								 WHEN @ScopedDatabaseID IS NOT NULL THEN 'ScopedDatabase' 
								 --
							END  as  UPDATE_TableName 
				,			CASE WHEN @TableValuedFunctionColumnID IS NOT NULL THEN @TableValuedFunctionColumnID
								 WHEN @TupleStructureColumnID IS NOT NULL THEN @TupleStructureColumnID
								 --
								 WHEN @StoredProcedureParameterID IS NOT NULL THEN @StoredProcedureParameterID
								 WHEN @TableValuedFunctionParameterID IS NOT NULL THEN @TableValuedFunctionParameterID
								 WHEN @ScalarValuedFunctionParameterID IS NOT NULL THEN @ScalarValuedFunctionParameterID
								 --
								 WHEN @SynonymAliasID IS NOT NULL THEN @SynonymAliasID
								 WHEN @StoredProcedureID IS NOT NULL THEN @StoredProcedureID
								 WHEN @TableValuedFunctionID IS NOT NULL THEN @TableValuedFunctionID 
								 WHEN @ScalarValuedFunctionID IS NOT NULL THEN @ScalarValuedFunctionID
								 WHEN @TupleStructureID IS NOT NULL THEN @TupleStructureID  
								 --
								 WHEN @DatabaseSchemaID IS NOT NULL THEN @DatabaseSchemaID
								 --
								 WHEN @DatabaseRoleID IS NOT NULL THEN @DatabaseRoleID
								 --
								 WHEN @ScopedDatabaseID IS NOT NULL THEN convert(bigint,@ScopedDatabaseID) 
								 --
							END  as  UPDATE_Record_ID  
				--
				,			@DatabaseName		as	DatabaseName	
				,			@RoleName			as	RoleName		
				,			@SchemaName			as	SchemaName		
				,			@ObjectName			as	ObjectName		
				,			@ParameterName		as	ParameterName	
				,			@ColumnName			as	ColumnName		
				--
				,			@PurposeOrMeaning_Description	as	UPDATE_PurposeOrMeaning_Description 
				,			@TechnicalNotes					as	UPDATE_TechnicalNotes 
				--
				;
			
			SET @RowCount = @@ROWCOUNT 
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
		END
			
		ELSE IF @Mode = 'LIVE' 
		BEGIN 
			
				--
				--	TableValuedFunctionColumn 
				--	
			IF @TableValuedFunctionColumnID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[TableValuedFunctionColumn] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.TableValuedFunctionColumn  X  
					WHERE	X.ID = @TableValuedFunctionColumnID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[TableValuedFunctionColumn] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	TupleStructureColumn 
				--	
			ELSE IF @TupleStructureColumnID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[TupleStructureColumn] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.TupleStructureColumn  X  
					WHERE	X.ID = @TupleStructureColumnID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[TupleStructureColumn] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	StoredProcedureParameter 
				--	
			ELSE IF @StoredProcedureParameterID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[StoredProcedureParameter] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.StoredProcedureParameter  X  
					WHERE	X.ID = @StoredProcedureParameterID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[StoredProcedureParameter] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	TableValuedFunctionParameter 
				--	
			ELSE IF @TableValuedFunctionParameterID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[TableValuedFunctionParameter] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.TableValuedFunctionParameter  X  
					WHERE	X.ID = @TableValuedFunctionParameterID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[TableValuedFunctionParameter] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	ScalarValuedFunctionParameter 
				--	
			ELSE IF @ScalarValuedFunctionParameterID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[ScalarValuedFunctionParameter] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.ScalarValuedFunctionParameter  X  
					WHERE	X.ID = @ScalarValuedFunctionParameterID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[ScalarValuedFunctionParameter] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	SynonymAlias 
				--	
			ELSE IF @SynonymAliasID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[SynonymAlias] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.SynonymAlias  X  
					WHERE	X.ID = @SynonymAliasID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[SynonymAlias] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	StoredProcedure 
				--	
			ELSE IF @StoredProcedureID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[StoredProcedure] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.StoredProcedure  X  
					WHERE	X.ID = @StoredProcedureID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[StoredProcedure] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	TableValuedFunction 
				--	
			ELSE IF @TableValuedFunctionID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[TableValuedFunction] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.TableValuedFunction  X  
					WHERE	X.ID = @TableValuedFunctionID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[TableValuedFunction] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	ScalarValuedFunction 
				--	
			ELSE IF @ScalarValuedFunctionID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[ScalarValuedFunction] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.ScalarValuedFunction  X  
					WHERE	X.ID = @ScalarValuedFunctionID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[ScalarValuedFunction] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	TupleStructure 
				--	
			ELSE IF @TupleStructureID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[TupleStructure] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.TupleStructure  X  
					WHERE	X.ID = @TupleStructureID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[TupleStructure] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	DatabaseSchema 
				--	
			ELSE IF @DatabaseSchemaID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[DatabaseSchema] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.DatabaseSchema  X  
					WHERE	X.ID = @DatabaseSchemaID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[DatabaseSchema] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	DatabaseRole 
				--	
			ELSE IF @DatabaseRoleID IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [dbocatalogue].[DatabaseRole] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	dbocatalogue.DatabaseRole  X  
					WHERE	X.ID = @DatabaseRoleID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[DatabaseRole] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 
				--
				--	ScopedDatabase 
				--	
			ELSE IF @ScopedDatabaseID IS NOT NULL -- guaranteed by earlier parameter checks 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [serverconfig].[ScopedDatabase] record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.PurposeOrMeaning_Description = CASE WHEN @PurposeOrMeaning_Description IS NULL 
																  THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
																			THEN NULL 
																			ELSE X.PurposeOrMeaning_Description 
																	   END 
																  ELSE @PurposeOrMeaning_Description 
															 END 
					--
					,		X.TechnicalNotes = CASE WHEN @TechnicalNotes IS NULL 
											  	    THEN CASE WHEN @ReplaceExistingValuesWithNULL = 1 
											  				  THEN NULL 
											  				  ELSE X.TechnicalNotes 
											  		     END 
											  	    ELSE @TechnicalNotes 
											   END 
					--
					FROM	serverconfig.ScopedDatabase  X  
					WHERE	X.ID = @ScopedDatabaseID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [serverconfig].[ScopedDatabase] record.' ; 
					GOTO ERROR ; 
				END CATCH 
			END 

			IF @RowCount IS NULL 
			OR @RowCount != 1 
			BEGIN
				SET @ErrorMessage = 'An unexpected number of records were affected while attempting to set new "operator notes" text-field values.' ; 
				GOTO ERROR ; 
			END

		--
		--
		SET @NEW_LatestUpdateToObjectRecordDocumentation = GETDATE() ; 
		--
		--

			IF @DatabaseSchemaID IS NOT NULL 
			AND @ObjectName IS NOT NULL 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [LatestUpdateToObjectRecordDocumentation] column value for relevant [dbocatalogue].[DatabaseSchema] record.' ) END ; 
				
				BEGIN TRY 

					UPDATE	X 
					SET		X.LatestUpdateToObjectRecordDocumentation = @NEW_LatestUpdateToObjectRecordDocumentation 
					--
					FROM	dbocatalogue.DatabaseSchema  X  
					WHERE	X.ID = @DatabaseSchemaID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [dbocatalogue].[DatabaseSchema] record.' ; 
					GOTO ERROR ; 
				END CATCH 

				IF @RowCount IS NULL 
				OR @RowCount != 1 
				BEGIN
					SET @ErrorMessage = 'An unexpected number of records were affected while attempting to update [LatestUpdateToObjectRecordDocumentation] value in [dbocatalogue].[DatabaseSchema].' ; 
					GOTO ERROR ; 
				END
			END 
			
			--
			--
			
			IF @ScopedDatabaseID IS NOT NULL 
			AND ( @DatabaseRoleID IS NOT NULL OR @DatabaseSchemaID IS NOT NULL ) 
			BEGIN 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Update [LatestUpdateToObjectRecordDocumentation] column value for relevant [serverconfig].[ScopedDatabase] record.' ) END ; 
				
				BEGIN TRY 

					UPDATE	X 
					SET		X.LatestUpdateToObjectRecordDocumentation = @NEW_LatestUpdateToObjectRecordDocumentation 
					--
					FROM	serverconfig.ScopedDatabase  X  
					WHERE	X.ID = @ScopedDatabaseID 

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error occurred while attempting to update [serverconfig].[ScopedDatabase] record.' ; 
					GOTO ERROR ; 
				END CATCH 

				IF @RowCount IS NULL 
				OR @RowCount != 1 
				BEGIN
					SET @ErrorMessage = 'An unexpected number of records were affected while attempting to update [LatestUpdateToObjectRecordDocumentation] value in [serverconfig].[ScopedDatabase].' ; 
					GOTO ERROR ; 
				END
			END 

			--
			--

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
	
	--
	--

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END 

	RETURN -1 ; 

END 
GO
-- 
-- END FILE :: a004_dbocatalogue_usp_Enter_OperatorNotes.sql 
-- 