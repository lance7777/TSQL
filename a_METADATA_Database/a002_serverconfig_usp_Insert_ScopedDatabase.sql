--
-- BEGIN FILE :: a002_serverconfig_usp_Insert_ScopedDatabase.sql 
--
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [serverconfig].[usp_Insert_ScopedDatabase]	
	@DatabaseName	varchar(256)	=	null	
--
,	@KeepingRecordsSynchronized		bit				=	 1	
--
,	@PurposeOrMeaning_Description	varchar(1080)	=	null 
,	@TechnicalNotes					varchar(1080)	=	null 
--
--
,	@OverwriteExistingRecord		bit				=	 0 
--
--
,	@DEBUG  bit  =  0  
--	
AS
/**************************************************************************************

	Adds a record to the serverconfig.ScopedDatabase table. 


	  Alternatively, if a record matching the provided @DatabaseName value 
	   already exists, and @OverwriteExistingRecord is set to 1, 
	    the existing record will be updated, using all of the other parameters 
		 with names corresponding to table column names: 
			-- [KeepingRecordsSynchronized] 
			-- [PurposeOrMeaning_Description] 
			-- [TechnicalNotes] 

		
		Example:	


			EXEC	serverconfig.usp_Insert_ScopedDatabase		
						@DatabaseName	=	'a_METADATA' 
					--
					--, @KeepingRecordsSynchronized		=	1
					--
					,	@PurposeOrMeaning_Description	=	'Eases and enhances data-structure documentation & transparency' 
					,	@TechnicalNotes					=	'It''s OK to be self-referential' 
					--
					,	@OverwriteExistingRecord  =  0  -- if set to 1, existing record will be updated 
					--
					,	@DEBUG  =  1	
					-- 
			;	


	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	
	2020-09-10		Added the @OverwriteExistingRecord parameter. 

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	--
	--

	DECLARE		@ErrorMessage				varchar(500)	
	,			@RowCount					int			
	--	
	--
	,			@ExistingRecordID			int		
	--
	;
	
	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check input parameters.' ) END ; 
	
	--
	--

		IF @KeepingRecordsSynchronized IS NULL 
		BEGIN 
			SET @KeepingRecordsSynchronized = 1 ; 
		END 

	--
	--

		SELECT @ExistingRecordID = X.ID FROM serverconfig.ScopedDatabase X WHERE X.DatabaseName = @DatabaseName  
		--
		;	

		IF @ExistingRecordID IS NOT NULL 
		BEGIN 
			IF @DEBUG = 1 
			BEGIN 
				SELECT  'Existing record:'  as  Information 
				,		X.* 
				--	
				FROM serverconfig.ScopedDatabase X 
				WHERE X.ID = @ExistingRecordID 
				--
				; 
			END 

			IF coalesce(@OverwriteExistingRecord,0) = 0 
			BEGIN 
				SET @ErrorMessage = 'A [serverconfig].[ScopedDatabase] record ALREADY EXISTS with [DatabaseName] column-value matching the provided @DatabaseName parameter-value.'
				GOTO ERROR 
			END 
			ELSE BEGIN -- This section is reached when  ( @OverwriteExistingRecord = 1 )  , regardless of whether all parameters match existing table-column values. 
			
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'A record (ID # ' + convert(varchar(50),@ExistingRecordID) + ') in [serverconfig].[ScopedDatabase] has [DatabaseName] = ''' + @DatabaseName + '''.' ) END ; 
				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( '@OverwriteExistingRecord is set to 1.' ) END ; 

				IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Attempt to update existing record.' ) END ; 

				BEGIN TRY 

					UPDATE	X 
					SET		X.KeepingRecordsSynchronized = @KeepingRecordsSynchronized 
					,		X.PurposeOrMeaning_Description = @PurposeOrMeaning_Description 
					,		X.TechnicalNotes = @TechnicalNotes 
					--
					FROM	serverconfig.ScopedDatabase  X  
					WHERE	X.ID = @ExistingRecordID 
					--
					;

					SET @RowCount = @@ROWCOUNT 
					IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

				END TRY 
				BEGIN CATCH 
					SET @ErrorMessage = 'An error was encountered while attempting to update 1 record (ID # ' + convert(varchar(50),@ExistingRecordID) + ') in [serverconfig].[ScopedDatabase].' 
					GOTO ERROR 
				END CATCH 

			END -- // END of section for  ( @OverwriteExistingRecord = 1 )  

			GOTO FINISH ; 

		END -- // END of section for  ( @ExistingRecordID is not null ) 

	--
	--	

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Attempt to insert new record.' ) END ; 

	BEGIN TRY 

		INSERT INTO serverconfig.ScopedDatabase 
		(
		   DatabaseName 
		,  KeepingRecordsSynchronized 
		,  PurposeOrMeaning_Description 
		,  TechnicalNotes
		) VALUES (  @DatabaseName
				 ,  @KeepingRecordsSynchronized
				 ,  @PurposeOrMeaning_Description
				 ,  @TechnicalNotes )	
		--
		;

		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END TRY 
	BEGIN CATCH 
		SET @ErrorMessage = 'An error was encountered while attempting to add 1 new record to [serverconfig].[ScopedDatabase].' 
		GOTO ERROR 
	END CATCH 

	--
	--

	FINISH:		

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
GO
--
-- END FILE :: a002_serverconfig_usp_Insert_ScopedDatabase.sql 
--