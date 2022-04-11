--
-- BEGIN FILE :: m003_StoredProcedures.sql 
--

--
--
--
--
/***

  CONTENTS: 
  
  - create routines: 
    - usp_LinearOptimization_KarmarkarPowerSeries 
	- usp_LinearOptimization 
	- usp_LogisticRegression 
	- usp_PrincipalComponentAnalysis 

***/

--
--

GO 

--
--

CREATE PROCEDURE [math].[usp_LinearOptimization_KarmarkarPowerSeries] 	
	@CoefficientVector		math.UTT_MatrixCoordinate	READONLY	
,	@ConstraintVector		math.UTT_MatrixCoordinate	READONLY	
,	@ConstraintMatrix		math.UTT_MatrixCoordinate	READONLY	
--
,	@SafetyFactor			float			=	0.70		
,	@TaylorSeriesOrder		int				=	3		
--
,	@MuForBigM				float			=	1000	
,	@FeasibilityTolerance	float			=	0.0001
--
,	@Max_SubAlgorithm_Iterations	int		=	777		
--
,	@Mode					varchar(4)		=	'VIEW'		--	'VIEW' , 'TEMP'		
--
,	@DEBUG					bit				=	0		
--	
AS
/**************************************************************************************

	Solves (approximately) a linear optimization problem posed in a special form: 

				maximize		c^T * x 
				subject to		Ax <= b		

			where	c = coefficient vector ( n-by-1 ) 
					b = constraint vector  ( m-by-1 ) 
					A = constraint matrix  ( m-by-n ) 

					and x is a free variable ( n-by-1 ) and  m >= n. 

					c should be non-zero and the matrix A should have full column rank. 	


		Algorithm taken from paper 
		 "AN IMPLEMENTATION OF KARMARKAR'S ALGORITHM FOR LINEAR PROGRAMMING" (1989)	
		 by		I. Adler, N. Karmarkar, M.G.C. Resende, and G. Veiga. 

		

		Example:	

		--	
		--	
		--		maximize		-2X - Y 					
		--		subject to		-X + Y <= 1 				
		--						-X - Y <= -2 
		--						  -Y <= 0 		
		--						 X - 2Y <= 4	
		--

			DECLARE @ex_CoefficientVector AS math.UTT_MatrixCoordinate ; 
			DECLARE @ex_ConstraintVector  AS math.UTT_MatrixCoordinate ; 
			DECLARE @ex_ConstraintMatrix  AS math.UTT_MatrixCoordinate ; 

				INSERT INTO @ex_CoefficientVector ( RowNumber , ColumnNumber , [Value] ) 
					VALUES ( 1 , 1 , -2 )	
					,	   ( 2 , 1 , -1 ) 

				INSERT INTO @ex_ConstraintVector ( RowNumber , ColumnNumber , [Value] ) 
					VALUES ( 1 , 1 ,  1 )	
					,	   ( 2 , 1 , -2 ) 	
					,	   ( 3 , 1 ,  0 ) 	
					,	   ( 4 , 1 ,  4 )
					
				INSERT INTO @ex_ConstraintMatrix ( RowNumber , ColumnNumber , [Value] ) 
					VALUES ( 1 , 1 , -1 ) , ( 1 , 2 ,  1 ) 
					,	   ( 2 , 1 , -1 ) , ( 2 , 2 , -1 ) 
					,	   ( 3 , 1 ,  0 ) , ( 3 , 2 , -1 ) 
					,	   ( 4 , 1 ,  1 ) , ( 4 , 2 , -2 ) 
					 

			EXEC	math.usp_LinearOptimization_KarmarkarPowerSeries  
						@CoefficientVector		=	@ex_CoefficientVector	
					,	@ConstraintVector		=	@ex_ConstraintVector 
					,	@ConstraintMatrix		=	@ex_ConstraintMatrix 
					--	
					,	@DEBUG					=	1	
					--							
					;							
			

	Date			Action	
	----------		----------------------------
	2018-01-26		Began creating initial version.	
	2018-02-02		Completed initial version. 
	2018-02-04		Added @Mode parameter. Outputting results to table for @Mode = 'TEMP'. 
					Made @MuForBigM, @FeasibilityTolerance, and @Max_SubAlgorithm_Iterations parameters instead of constants. 

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	--
	--

	DECLARE		@ErrorMessage				varchar(500)	
	,			@RowCount					int			
	--
	,			@ProcedureReturnValue		int		
	--
	--	
	,			@PhaseNumber				int				
	--
	--	
	,			@BigM						float	
	--
	--
	,			@NumberOfVariables			int		
	,			@NumberOfConstraints		int		
	--
	--
	,			@ArtificialVariable_Method2Threshold	float	=	0.01	
	--
	--
	,			@SubAlgorithm_ExitMessage				varchar(100)	
	--
	--
	,			@Min_SubAlgorithm_SupremumT_SearchStep	float			=	convert(float,1.0)/convert(float,POWER(2,12)) 	
	--
	--
	;
	
	--
	--

	DECLARE @InputConstraintMatrix_FullRankCheck AS math.UTT_MatrixCoordinate ; 
	
	DECLARE @CoefficientVector_WithArtificialVariable AS math.UTT_MatrixCoordinate ; 
  --DECLARE @ConstraintVector_WithArtificialVariable AS math.UTT_MatrixCoordinate ; 
	DECLARE @ConstraintMatrix_WithArtificialVariable AS math.UTT_MatrixCoordinate ; 
	--	
	DECLARE @InitialPoint_WithArtificialVariable AS math.UTT_MatrixCoordinate ; 
	--	

	DECLARE @temp_WorkingMatrix_1 AS math.UTT_MatrixCoordinate ; 
	DECLARE @temp_WorkingMatrix_2 AS math.UTT_MatrixCoordinate ; 
	DECLARE @temp_WorkingMatrix_3 AS math.UTT_MatrixCoordinate ; 

	--
	--

	--
	DECLARE @SubAlgorithm_Iteration AS int ;
	DECLARE @SubAlgorithm_SubIteration AS int ;   
	--	
	DECLARE @SubAlgorithm_CoefficientVector AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_ConstraintVector AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_ConstraintMatrix AS math.UTT_MatrixCoordinate ; 
	--
	DECLARE @SubAlgorithm_ConstraintMatrix_Transpose AS math.UTT_MatrixCoordinate ; 
	--
	DECLARE @SubAlgorithm_IterativePoint_x AS math.UTT_MatrixCoordinate ; 
	--
	DECLARE @SubAlgorithm_IterativeScalar_CurrentObjectiveValue AS float ; 
	DECLARE @SubAlgorithm_IterativeScalar_PreviousObjectiveValue AS float ; 
	DECLARE @SubAlgorithm_IterativeSlack_v AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeMatrix_Dv AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeMatrix_DvInv AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeMatrix_DvInvSqu AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv_AT_DvInv AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeVector_hx AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeVector_hv AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeScalar_L AS int ;   
	DECLARE @SubAlgorithm_IterativeScalar_Ro AS float ;   
	DECLARE @SubAlgorithm_IterativeVector_zx AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeVector_zv AS math.UTT_MatrixCoordinate ; 
	DECLARE @SubAlgorithm_IterativeVector_F AS math.UTT_MatrixCoordinate ;  
	DECLARE @SubAlgorithm_IterativeScalar_SupremumT AS float ; 
	DECLARE @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep AS float ; 
	DECLARE @SubAlgorithm_IterativeScalar_Alpha AS float ; 
	--
	DECLARE @SubAlgorithm_NextPoint_x AS math.UTT_MatrixCoordinate ; 
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

		IF @Mode IS NULL 
		BEGIN 
			SET @Mode = 'VIEW' ; 
		END		
		IF @Mode NOT IN ( 'VIEW' , 'TEMP' )		
		BEGIN 
			SET @ErrorMessage = 'The provided @Mode value is unexpected. Acceptable values are ''VIEW'' or ''TEMP''.'	 
			GOTO ERROR 
		END		

	--
	--

		IF @Mode = 'TEMP' 
		BEGIN 

			IF OBJECT_ID('tempdb..#result_usp_LinearOptimization_KarmarkarPowerSeries') IS NULL 
			BEGIN 
				SET @ErrorMessage = 'For @Mode = ''TEMP'', a temporary table called #result_usp_LinearOptimization_KarmarkarPowerSeries must exist. Check bottom of procedure definition.' 
				GOTO ERROR 
			END		

			IF EXISTS ( SELECT	null 
						FROM	#result_usp_LinearOptimization_KarmarkarPowerSeries )	
			BEGIN 
				SET @ErrorMessage = 'Input temporary table (#result_usp_LinearOptimization_KarmarkarPowerSeries) must be empty.' 
				GOTO ERROR 
			END		

			BEGIN TRY 

				INSERT INTO #result_usp_LinearOptimization_KarmarkarPowerSeries 
				(
					RowNumber	
				,	[Value]		
				) 
					SELECT	X.RowNumber		
					,		X.[Value]	
					FROM	( 
								VALUES	(   7	,  77.77  )		 
							)	
								X	( RowNumber , [Value] )	
					--
					WHERE	1 = 0 ; 
					--	
					;	

			END TRY 
			BEGIN CATCH 
				SET @ErrorMessage = 'Check format of input temporary table (#result_usp_LinearOptimization_KarmarkarPowerSeries).' 
				GOTO ERROR 
			END CATCH	

		END		

	--
	--

		IF @SafetyFactor < 0.000001 
		BEGIN 
			SET @ErrorMessage = 'The provided @SafetyFactor is too small. The value should be between 0 and 1.' 
			GOTO ERROR 
		END		 
		IF @SafetyFactor > 0.999999 
		BEGIN 
			SET @ErrorMessage = 'The provided @SafetyFactor is too large. The value should be between 0 and 1.' 
			GOTO ERROR 
		END		 

	--
	--

		IF @TaylorSeriesOrder < 1 
		BEGIN 
			SET @ErrorMessage = 'The provided @TaylorSeriesOrder should be at least 1.' 
			GOTO ERROR 
		END		 

	--
	--

		IF @MuForBigM < 0.001 
		OR @MuForBigM IS NULL 
		BEGIN 
			SET @ErrorMessage = '@MuForBigM should be a large, positive number.'
			GOTO ERROR 
		END		
		
		IF @FeasibilityTolerance < 0.00000000000001 
		OR @FeasibilityTolerance > 0.09999999999999
		OR @FeasibilityTolerance IS NULL 
		BEGIN 
			SET @ErrorMessage = '@FeasibilityTolerance should be between 0 and 0.1, and not too close to either.'
			GOTO ERROR 
		END		
		
	--
	--

		IF @Max_SubAlgorithm_Iterations < 20 
		OR @Max_SubAlgorithm_Iterations > 20 * 1000 * 1000 
		OR @Max_SubAlgorithm_Iterations IS NULL 
		BEGIN 
			SET @ErrorMessage = '@Max_SubAlgorithm_Iterations should be between 20 and 20-million.'
			GOTO ERROR 
		END		
		
	--	
	--	
		
		--
		--	check matrices	
		--	

		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @CoefficientVector , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @CoefficientVector.' 
			GOTO ERROR 
		END 

		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @ConstraintVector , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @ConstraintVector.' 
			GOTO ERROR 
		END 
		
		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @ConstraintMatrix , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @ConstraintMatrix.' 
			GOTO ERROR 
		END 

			--
			--	2018-01-26 :: for now, only handle 1 problem at a time.
			--	
		IF EXISTS ( SELECT	null 
					FROM	@CoefficientVector	
					WHERE	MatrixID IS NOT NULL ) 
		OR EXISTS ( SELECT	null 
					FROM	@ConstraintVector
					WHERE	MatrixID IS NOT NULL ) 
		OR EXISTS ( SELECT	null 
					FROM	@ConstraintMatrix
					WHERE	MatrixID IS NOT NULL ) 
		BEGIN	
			SET @ErrorMessage = 'All input matrices should have NULL MatrixID for all records.' 
			GOTO ERROR 
		END 

	--
	--	

		IF EXISTS ( SELECT	null 
					FROM	@CoefficientVector 
					WHERE	ColumnNumber > 1 ) 
		BEGIN	
			SET @ErrorMessage = '@CoefficientVector should have only one column.' 
			GOTO ERROR 
		END		
		
		IF EXISTS ( SELECT	null 
					FROM	@ConstraintVector 
					WHERE	ColumnNumber > 1 ) 
		BEGIN	
			SET @ErrorMessage = '@ConstraintVector should have only one column.' 
			GOTO ERROR 
		END		

		SELECT @NumberOfVariables = COUNT(*) FROM @CoefficientVector ; 
		SELECT @NumberOfConstraints = COUNT(*) FROM @ConstraintVector ; 

		IF @NumberOfVariables != ( SELECT MAX(X.ColumnNumber) FROM @ConstraintMatrix X ) 
		OR @NumberOfConstraints != ( SELECT MAX(X.RowNumber) FROM @ConstraintMatrix X ) 
		BEGIN 
			IF @DEBUG = 1 
			BEGIN 
				SELECT	'The size of @ConstraintMatrix is unexpected:'	Information		
				,		MAX(X.RowNumber)		NumberOfRows 
				,		@NumberOfConstraints	ExpectedRows	
				--
				,		MAX(X.ColumnNumber)		NumberOfColumns		
				,		@NumberOfVariables		ExpectedColumns
				--
				FROM	@ConstraintMatrix	X	
			END		

			SET @ErrorMessage = 'The size of the provided @ConstraintMatrix is unexpected.' 
			GOTO ERROR 
		END		 

	--
	--

		INSERT INTO @InputConstraintMatrix_FullRankCheck 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]			
		) 

		SELECT	X.RowNumber 
		,		X.ColumnNumber 
		,		X.[Value]	
		FROM	math.fcn_Matrix_RowEchelonForm ( @ConstraintMatrix )	X	
		--
		;	

		IF ( SELECT math.fcn_Matrix_IntegrityCheck ( @InputConstraintMatrix_FullRankCheck 
												   , 0 -- Check for Zero Rows 
												   , 1 -- Check for Zero Columns 
												   ) 
		   ) = 0	
		BEGIN	
			SET @ErrorMessage = 'The provided @ConstraintMatrix does not have full column rank.' 
			GOTO ERROR 
		END		

	--
	--

		IF ( SELECT MAX(ABS(X.[Value])) FROM @CoefficientVector X ) < 0.0001 
		BEGIN 
			SET @ErrorMessage = 'The provided @CoefficientVector is too close to zero.' 
			GOTO ERROR 
		END		

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'All checks passed successfully.' ) END ; 
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Number of variables:    n = ' + convert(varchar(50),@NumberOfVariables) ) END ; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Number of constraints:  m = ' + convert(varchar(50),@NumberOfConstraints) ) END ; 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN PHASE I: Find an interior feasible point for provided problem.' ) END ; 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Add artificial variable to input problem.' ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Define initial interior feasible point for problem with artificial variable.' ) END ; 
	
		--
		--	Ac	
		--	
		DELETE FROM @temp_WorkingMatrix_1 ; 
		--	
		INSERT INTO @temp_WorkingMatrix_1 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	Ac.RowNumber 
			,		Ac.ColumnNumber 
			,		Ac.[Value] 
			--	
			FROM	math.fcn_Matrix_Product ( @ConstraintMatrix , @CoefficientVector )	Ac 
			--	
			;	

		--
		--

		INSERT INTO @InitialPoint_WithArtificialVariable 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT	c.RowNumber 
			,		c.ColumnNumber 
			,		c.[Value] * b_2Norm.[Value] / Ac_2Norm.[Value] 
			--		
			FROM	( 
						SELECT	SQRT( SUM( X.[Value] * X.[Value] ) )	[Value]		 
						FROM	@ConstraintVector	X	
					)	
						b_2Norm		
			CROSS JOIN	( 
							SELECT	SQRT( SUM( X.[Value] * X.[Value] ) )	[Value]		 
							FROM	@temp_WorkingMatrix_1	X	
						)	
							Ac_2Norm 
			--
			CROSS JOIN	@CoefficientVector	c	
			--
			;	
		
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
			
		IF @RowCount = 0 
		BEGIN 
			SET @ErrorMessage = 'Failed to define initial point for problem with artificial variable.' 
			GOTO ERROR 
		END 

	--
	--

		--
		--	Ax_0 	
		--	
		DELETE FROM @temp_WorkingMatrix_1 ; 
		--	
		INSERT INTO @temp_WorkingMatrix_1  
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	Ac.RowNumber 
			,		Ac.ColumnNumber 
			,		Ac.[Value] 
			--	
			FROM	math.fcn_Matrix_Product ( @ConstraintMatrix , @InitialPoint_WithArtificialVariable )	Ac 
			--	
			;	
			
		--
		--	b - Ax_0 	
		--	
		DELETE FROM @temp_WorkingMatrix_2 ; 
		--	
		INSERT INTO @temp_WorkingMatrix_2   
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	b.RowNumber 
			,		b.ColumnNumber 
			,		b.[Value] - Ax_0.[Value]	
			--	
			FROM		@temp_WorkingMatrix_1	Ax_0 
			INNER JOIN	@ConstraintVector		b		ON	Ax_0.RowNumber = b.RowNumber 
														AND Ax_0.ColumnNumber = b.ColumnNumber  
			--	
			;	


		INSERT INTO @InitialPoint_WithArtificialVariable 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT	@NumberOfVariables + 1 
			,		1 
			,		CASE WHEN ABS(art1.[Value]) < @ArtificialVariable_Method2Threshold 
						 THEN art2.[Value] 
						 ELSE art1.[Value] 
					END		
			--		
			FROM	( 
						SELECT	-2.000 * MIN( bminusA_x0.[Value] )	as	[Value]		
						FROM	@temp_WorkingMatrix_2	bminusA_x0 
					)	
						art1 
			CROSS JOIN	( 
							SELECT	2.000 * SQRT( SUM( X.[Value] * X.[Value] ) )	[Value]		 
							FROM	@temp_WorkingMatrix_2	X	
						)	
							art2	 
			--
			;	
		
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
			
		IF @RowCount != 1  
		BEGIN 
			SET @ErrorMessage = 'Failed to define artificial variable value.' 
			GOTO ERROR 
		END 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Calculate ''Big M''.' ) END ; 
	
		--
		--	M = mu * c^T x_0 / initial.art.var. 
		--

		SELECT		@BigM = @MuForBigM * SUM(x_0.[Value] * c.[Value]) 
							/ ( SELECT  artvar.[Value] 
								FROM	@InitialPoint_WithArtificialVariable	artvar 
								WHERE	artvar.RowNumber = @NumberOfVariables + 1 ) 
		--	
		FROM		@InitialPoint_WithArtificialVariable	x_0			
		INNER JOIN	@CoefficientVector						c		ON	x_0.RowNumber = c.RowNumber 
																	AND x_0.ColumnNumber = c.ColumnNumber 
		--
		;	

		IF @BigM IS NULL 
		BEGIN 
			SET @ErrorMessage = 'Failed to calculate ''Big M''.' 
			GOTO ERROR 
		END		

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Define coefficient vector for problem with artificial variable.' ) END ; 
	
		INSERT INTO @CoefficientVector_WithArtificialVariable 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT	c.RowNumber 
			,		c.ColumnNumber 
			,		c.[Value]	
			--		
			FROM	@CoefficientVector	c	
			--
		
		UNION ALL	

			SELECT	@NumberOfVariables + 1 
			,		1 
			,		- @BigM 
			--
			
		--
		--
		;	
		
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
			
		IF @RowCount = 0 
		BEGIN 
			SET @ErrorMessage = 'Failed to define coefficient vector for problem with artificial variable.' 
			GOTO ERROR 
		END 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Define constraint matrix for problem with artificial variable.' ) END ; 
	
		INSERT INTO @ConstraintMatrix_WithArtificialVariable 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT	c.RowNumber 
			,		c.ColumnNumber 
			,		c.[Value]	
			--		
			FROM	@ConstraintMatrix	c	
			--
		
		UNION ALL	

			SELECT	b.RowNumber 
			,		@NumberOfVariables + 1 
			,		- 1.000	
			--
			FROM	@ConstraintVector	b	
			--	
			
		--
		--
		;	
		
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
			
		IF @RowCount = 0 
		BEGIN 
			SET @ErrorMessage = 'Failed to define constraint matrix for problem with artificial variable.' 
			GOTO ERROR 
		END		

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Apply sub-algorithm to solve problem with artificial variable.' ) END ; 

	SET @PhaseNumber = 1 ; 
	--	

	INSERT INTO @SubAlgorithm_CoefficientVector 
				( RowNumber ,   ColumnNumber ,   [Value] ) 
		SELECT	X.RowNumber , X.ColumnNumber , X.[Value]	
		FROM	@CoefficientVector_WithArtificialVariable X 
		--
		;	
	INSERT INTO @SubAlgorithm_ConstraintVector 
				( RowNumber ,   ColumnNumber ,   [Value] ) 
		SELECT	X.RowNumber , X.ColumnNumber , X.[Value]	
		FROM	@ConstraintVector X 
		--
		;	
	INSERT INTO @SubAlgorithm_ConstraintMatrix 
				( RowNumber ,   ColumnNumber ,   [Value] ) 
		SELECT	X.RowNumber , X.ColumnNumber , X.[Value]	
		FROM	@ConstraintMatrix_WithArtificialVariable X 
		--
		;	
	--
	INSERT INTO @SubAlgorithm_IterativePoint_x 
				( RowNumber ,   ColumnNumber ,   [Value] ) 
		SELECT	X.RowNumber , X.ColumnNumber , X.[Value]	
		FROM	@InitialPoint_WithArtificialVariable X 
		--
		;	
	--	

	--	
	GOTO SECTION_SUB_ALGORITHM ; 

	SECTION_PHASE_1_COMPLETE: 
	
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'PHASE I complete. Iterations: ' + convert(varchar(10),@SubAlgorithm_Iteration) ) END ; 

	--
	--
	--
	--
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN PHASE II: Attempt to find an approximately optimal feasible solution.' ) END ; 

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Apply sub-algorithm to original problem.' ) END ; 

	SET @PhaseNumber = 2 ; 
	--	

	DELETE 
	FROM	@SubAlgorithm_CoefficientVector 
	WHERE	RowNumber = @NumberOfVariables + 1 
	--
	;	
	
	DELETE  
	FROM	@SubAlgorithm_ConstraintMatrix 
	WHERE	ColumnNumber = @NumberOfVariables + 1 
	--
	;	

	DELETE  
	FROM	@SubAlgorithm_IterativePoint_x 
	WHERE	RowNumber = @NumberOfVariables + 1 
	--
	;	
	--	
	
	--	
	GOTO SECTION_SUB_ALGORITHM ; 

	SECTION_PHASE_2_COMPLETE: 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'PHASE II complete. Iterations: ' + convert(varchar(10),@SubAlgorithm_Iteration) ) END ; 

	--
	--
	--
	--
	--
	--

	SET @PhaseNumber = NULL ; 

	SECTION_SUB_ALGORITHM: 

	IF @PhaseNumber IN ( 1 , 2 ) 
	BEGIN 
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Initializing sub-algorithm: Phase ' + CASE @PhaseNumber WHEN 1 THEN 'I' WHEN 2 THEN 'II' END + '.' ) END ; 

		SET @SubAlgorithm_Iteration = 0 ; 
		SET @SubAlgorithm_ExitMessage = null ; 

		--
		--	cache transpose of constraint matrix to use in matrix product function calls later 
		--	
		IF EXISTS ( SELECT null FROM @SubAlgorithm_ConstraintMatrix_Transpose ) 
		BEGIN 
			DELETE FROM @SubAlgorithm_ConstraintMatrix_Transpose 
			--
			;	 
		END		

		INSERT INTO @SubAlgorithm_ConstraintMatrix_Transpose 
		( RowNumber , ColumnNumber , [Value] ) 
			
		SELECT	X.RowNumber , X.ColumnNumber , X.[Value]
		FROM	math.fcn_Matrix_Transpose ( @SubAlgorithm_ConstraintMatrix ) X 
		-- 
		;  

		--
		--

		WHILE @SubAlgorithm_Iteration < @Max_SubAlgorithm_Iterations
		BEGIN	
			
			--
			--	clear all iterative tables and variable values 
			--	
			DELETE FROM @SubAlgorithm_IterativeSlack_v ; 
			DELETE FROM @SubAlgorithm_IterativeMatrix_Dv ; 
			DELETE FROM @SubAlgorithm_IterativeMatrix_DvInv	;	
			DELETE FROM @SubAlgorithm_IterativeMatrix_DvInvSqu ; 
			DELETE FROM @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv ;
			DELETE FROM @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv_AT_DvInv ; 
			DELETE FROM @SubAlgorithm_IterativeVector_hx ;
			DELETE FROM @SubAlgorithm_IterativeVector_hv ;
			SET @SubAlgorithm_IterativeScalar_L = null ; 
			SET @SubAlgorithm_IterativeScalar_Ro = null ; 
			DELETE FROM @SubAlgorithm_IterativeVector_zx ; 
			DELETE FROM @SubAlgorithm_IterativeVector_zv ; 
			DELETE FROM @SubAlgorithm_IterativeVector_F ;
			SET @SubAlgorithm_IterativeScalar_SupremumT = null ; 
			SET @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep = null ; 
			SET @SubAlgorithm_IterativeScalar_Alpha = null ; 
			--
			--	
			;	

		--
		--	initial point previously populated in @SubAlgorithm_IterativePoint_x
		--	

			IF @PhaseNumber = 1 
			BEGIN 
				IF ( SELECT X.[Value] FROM @SubAlgorithm_IterativePoint_x X WHERE X.RowNumber = @NumberOfVariables + 1 ) < 0.000 
				BEGIN 
					SET @SubAlgorithm_ExitMessage = 'current iteration vector is feasible for original problem.'
					GOTO SECTION_SUB_ALGORITHM_EXIT ;  
				END 
			END		
			
			IF @SubAlgorithm_Iteration > 0 
			BEGIN 
				SET @SubAlgorithm_IterativeScalar_PreviousObjectiveValue = @SubAlgorithm_IterativeScalar_CurrentObjectiveValue 
				--
				;	
			END		

			SELECT		@SubAlgorithm_IterativeScalar_CurrentObjectiveValue = SUM(c.[Value]*x.[Value])	
			--	 
			FROM		@SubAlgorithm_CoefficientVector		c
			INNER JOIN	@SubAlgorithm_IterativePoint_x		x	ON	c.RowNumber = x.RowNumber 
			--
			;	

			IF ( SELECT		ABS( @SubAlgorithm_IterativeScalar_CurrentObjectiveValue - @SubAlgorithm_IterativeScalar_PreviousObjectiveValue ) 
						  / CASE WHEN ABS( @SubAlgorithm_IterativeScalar_PreviousObjectiveValue ) < 1.000 
								 THEN 1.000 
								 ELSE ABS( @SubAlgorithm_IterativeScalar_PreviousObjectiveValue ) 
							END 
			   ) < @FeasibilityTolerance 
			BEGIN 
				IF @PhaseNumber = 1 
				BEGIN 
					IF ( SELECT X.[Value] FROM @SubAlgorithm_IterativePoint_x X WHERE X.RowNumber = @NumberOfVariables + 1 ) > @FeasibilityTolerance 
					BEGIN	
						SET @SubAlgorithm_ExitMessage = 'P is "declared infeasible".'
						GOTO SECTION_SUB_ALGORITHM_EXIT ;  
					END 
					ELSE BEGIN 
						SET @SubAlgorithm_ExitMessage = 'either "unboundedness is detected" or an optimal solution is found.'
						GOTO SECTION_SUB_ALGORITHM_EXIT ;  
					END		
				END		
				ELSE IF @PhaseNumber = 2 
				BEGIN 
					SET @SubAlgorithm_ExitMessage = 'labwork stopping criterion satisfied: check feasibility & optimality of computed point.'
					GOTO SECTION_SUB_ALGORITHM_EXIT ;  
				END		
			END		
			--
			;	

		--
		--	Ax 	
		--	
		DELETE FROM @temp_WorkingMatrix_1 ; 
		--	
		INSERT INTO @temp_WorkingMatrix_1  
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	Ax.RowNumber 
			,		Ax.ColumnNumber 
			,		Ax.[Value] 
			--	
			FROM	math.fcn_Matrix_Product ( @SubAlgorithm_ConstraintMatrix , @SubAlgorithm_IterativePoint_x )	Ax 
			--	
			;	

		--
		--
		
		--
		--	v 	
		--	
		INSERT INTO @SubAlgorithm_IterativeSlack_v 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT		b.RowNumber 
			,			b.ColumnNumber 
			,			b.[Value] - Ax.[Value] 
			FROM		@SubAlgorithm_ConstraintVector		b
			INNER JOIN	@temp_WorkingMatrix_1				Ax	ON	b.RowNumber = Ax.RowNumber 
																AND b.ColumnNumber = Ax.ColumnNumber 
			--
			;	

		--
		--
		
		--
		--	Dv 	
		--	
		INSERT INTO @SubAlgorithm_IterativeMatrix_Dv 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT		V.RowNumber 
			,			W.RowNumber 
			,			CASE WHEN V.RowNumber = W.RowNumber 
							 THEN V.[Value] 
							 ELSE 0.000		 
						END		
			FROM		@SubAlgorithm_IterativeSlack_v	V
			CROSS JOIN	@SubAlgorithm_IterativeSlack_v	W	
			--
			;	

		--
		--
		
		--
		--	Dv^-1 	
		--	
		INSERT INTO @SubAlgorithm_IterativeMatrix_DvInv 
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT	X.RowNumber 
			,		X.ColumnNumber 
			,		CASE WHEN X.RowNumber = X.ColumnNumber 
						 AND  X.[Value] != 0.000 
						 THEN convert(float,1.000)/X.[Value]
						 ELSE 0.000 
					END		
			FROM	@SubAlgorithm_IterativeMatrix_Dv  X	
			--
			;	
			
		--
		--	Dv^-2 	
		--	
		INSERT INTO @SubAlgorithm_IterativeMatrix_DvInvSqu  
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value]		
		) 

			SELECT	X.RowNumber 
			,		X.ColumnNumber 
			,		CASE WHEN X.RowNumber = X.ColumnNumber 
						 THEN X.[Value] * X.[Value] 
						 ELSE 0.000 
					END		
			FROM	@SubAlgorithm_IterativeMatrix_DvInv	 X	
			--
			;	

		--
		--
		
		--
		--	Dv^-2 A 	
		--	
		DELETE FROM @temp_WorkingMatrix_1 ; 
		--	
		INSERT INTO @temp_WorkingMatrix_1  
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	P.RowNumber 
			,		P.ColumnNumber 
			,		P.[Value] 
			--	
			FROM	math.fcn_Matrix_Product ( @SubAlgorithm_IterativeMatrix_DvInvSqu , @SubAlgorithm_ConstraintMatrix )	 P  
			--	
			;	
			
		--
		--	A^T Dv^-2 A 	
		--	
		DELETE FROM @temp_WorkingMatrix_2 ; 
		--	
		INSERT INTO @temp_WorkingMatrix_2  
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	P.RowNumber 
			,		P.ColumnNumber 
			,		P.[Value] 
			--	
			FROM	math.fcn_Matrix_Product ( @SubAlgorithm_ConstraintMatrix_Transpose , @temp_WorkingMatrix_1 )  P  
			--	
			;	
			
		--
		--	( A^T Dv^-2 A )^-1 
		--	
		INSERT INTO @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv   
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	I.RowNumber 
			,		I.ColumnNumber 
			,		I.[Value] 
			--	
			FROM	math.fcn_Matrix_Inverse ( @temp_WorkingMatrix_2 )  I 
			--	
			;	
			
		--
		--	h_x
		--	
		INSERT INTO @SubAlgorithm_IterativeVector_hx   
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	null	
			,		P.RowNumber 
			,		P.ColumnNumber 
			,		P.[Value] 
			--	
			FROM	math.fcn_Matrix_Product ( @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv , @SubAlgorithm_CoefficientVector )	 P 
			--	
			;	
			
		--
		--	h_v 
		--	
		INSERT INTO @SubAlgorithm_IterativeVector_hv    
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	null 	
			,		P.RowNumber 
			,		P.ColumnNumber 
			,	  -	P.[Value] 
			--	
			FROM	math.fcn_Matrix_Product ( @SubAlgorithm_ConstraintMatrix , @SubAlgorithm_IterativeVector_hx )  P
			--	
			;	

		--
		--

		UPDATE @SubAlgorithm_IterativeVector_hx SET MatrixID = 1 ; 
		UPDATE @SubAlgorithm_IterativeVector_hv SET MatrixID = 1 ; 

		--
		--

		IF ( SELECT COUNT(*) FROM @SubAlgorithm_IterativeVector_hv X WHERE X.[Value] < 0 ) = 0 
		BEGIN	
			SET @SubAlgorithm_ExitMessage = 'unboundedness detected ? (h_v_1 >= 0)'
			GOTO SECTION_SUB_ALGORITHM_EXIT ;		
		END		

		--
		--

		SELECT	@SubAlgorithm_IterativeScalar_L  = L.RowNumber 
		--
		,		@SubAlgorithm_IterativeScalar_Ro = L.v_hv_ratio 
		--
		FROM	(
					SELECT		V.RowNumber 
					,			X.v_hv_ratio 
					,			RANK() OVER ( ORDER BY X.v_hv_ratio ASC 
											  ,		   V.RowNumber	ASC )	as	AscRatioRank
					FROM		@SubAlgorithm_IterativeSlack_v		V	
					INNER JOIN	@SubAlgorithm_IterativeVector_hv	H	ON	V.RowNumber = H.RowNumber 
																		AND V.ColumnNumber = H.ColumnNumber 
																		--
																		AND H.[Value] < 0.000 
																		--
					--
					OUTER APPLY	( 
									SELECT	CASE WHEN H.[Value] < 0.000 
												 THEN -V.[Value] / H.[Value] 
												 ELSE null 
											END		v_hv_ratio
								)	
									X	
				)
					L		
		--	
		WHERE	L.AscRatioRank = 1 
		--	
		;	

		--
		--
		
		--
		--	z_x
		--	
		INSERT INTO @SubAlgorithm_IterativeVector_zx 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	hx.MatrixID			--	1 
			,		hx.RowNumber 
			,		hx.ColumnNumber 
			,		hx.[Value] * @SubAlgorithm_IterativeScalar_Ro 
			--	
			FROM	@SubAlgorithm_IterativeVector_hx	hx	
			--	
			;	

		--
		--	z_v
		--	
		INSERT INTO @SubAlgorithm_IterativeVector_zv 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	hv.MatrixID			--	1 
			,		hv.RowNumber 
			,		hv.ColumnNumber 
			,		hv.[Value] * @SubAlgorithm_IterativeScalar_Ro 
			--	
			FROM	@SubAlgorithm_IterativeVector_hv 	hv 	
			--	
			;	

		--
		--
		
		--
		--	z_v_1 
		--	
		DELETE FROM @temp_WorkingMatrix_1 ; 
		--	
		INSERT INTO @temp_WorkingMatrix_1   
		(
			RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	zv1.RowNumber 
			,		zv1.ColumnNumber 
			,		zv1.[Value] 
			--	
			FROM	@SubAlgorithm_IterativeVector_zv  zv1 
			WHERE	zv1.MatrixID = 1 
			--	
			;	

		--
		--	F 
		--	
		INSERT INTO @SubAlgorithm_IterativeVector_F 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		) 
		
			SELECT	1 
			,		P.RowNumber 
			,		P.ColumnNumber 
			,		P.[Value]	
			--	
			FROM	math.fcn_Matrix_Product ( @SubAlgorithm_IterativeMatrix_DvInvSqu , @temp_WorkingMatrix_1 )  P
			--	
			;		

		--
		--
		
			--
			--	A^T Dv^-1 
			--	
			DELETE FROM @temp_WorkingMatrix_1 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_1   
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	P.RowNumber 
				,		P.ColumnNumber 
				,		P.[Value] 
				--	
				FROM	math.fcn_Matrix_Product ( @SubAlgorithm_ConstraintMatrix_Transpose , @SubAlgorithm_IterativeMatrix_DvInv )  P  
				--	
				;	
				 
			--
			--	( A^T Dv^-2 A )^-1 A^T Dv^-1 
			--	
			INSERT INTO @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv_AT_DvInv     
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	P.RowNumber 
				,		P.ColumnNumber 
				,		P.[Value] 
				--	
				FROM	math.fcn_Matrix_Product ( @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv , @temp_WorkingMatrix_1 )  P  
				--	
				;	

		--
		--

		SET @SubAlgorithm_SubIteration = 2 ; 

		WHILE @SubAlgorithm_SubIteration <= @TaylorSeriesOrder 
		BEGIN 
			
			--
			--	F_(i-j) 
			--	
			DELETE FROM @temp_WorkingMatrix_1 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_1   
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	@SubAlgorithm_SubIteration - F.MatrixID 
				,		F.RowNumber 
				,		F.ColumnNumber 
				,		F.[Value] 
				--	
				FROM	@SubAlgorithm_IterativeVector_F		F	
				--	
				;	
				
				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 1' 
					GOTO ERROR 
				END		

			--
			--	sum of previously defined F_(i-j) z_v_j 
			--	
			DELETE FROM @temp_WorkingMatrix_2 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_2    
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	F.RowNumber 
				,		F.ColumnNumber 
				,		SUM( F.[Value] * zv.[Value] )	
				--	
				FROM		@temp_WorkingMatrix_1			   F	
				INNER JOIN	@SubAlgorithm_IterativeVector_zv   zv	ON	F.MatrixID = zv.MatrixID 
																	AND F.RowNumber = zv.RowNumber 
																	AND F.ColumnNumber = zv.ColumnNumber 
				--	
				GROUP BY	F.RowNumber 
				,			F.ColumnNumber 
				--	
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 2' 
					GOTO ERROR 
				END		

			--
			--

			--
			--	h_x
			--	
			INSERT INTO @SubAlgorithm_IterativeVector_hx   
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	@SubAlgorithm_SubIteration 	
				,		P.RowNumber 
				,		P.ColumnNumber 
				,		P.[Value] 
				--	
				FROM	math.fcn_Matrix_Product ( @SubAlgorithm_IterativeMatrix_AT_DvInvSqu_A_Inv_AT_DvInv , @temp_WorkingMatrix_2 )  P 
				--	
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 3' 
					GOTO ERROR 
				END		

			--
			--	h_x_i 
			--	
			DELETE FROM @temp_WorkingMatrix_1 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_1   
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	hx.RowNumber 
				,		hx.ColumnNumber 
				,		hx.[Value] 
				--	
				FROM	@SubAlgorithm_IterativeVector_hx	hx	
				--	
				WHERE	hx.MatrixID = @SubAlgorithm_SubIteration 
				--	
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 4' 
					GOTO ERROR 
				END		
				
			--
			--	h_v  
			--	
			INSERT INTO @SubAlgorithm_IterativeVector_hv    
			(
				MatrixID
			,	RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	@SubAlgorithm_SubIteration	
				,		P.RowNumber 
				,		P.ColumnNumber 
				,	  - P.[Value] 
				--	
				FROM	math.fcn_Matrix_Product ( @SubAlgorithm_ConstraintMatrix , @temp_WorkingMatrix_1 )  P 
				--	
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 5' 
					GOTO ERROR 
				END		

			--
			--

			BEGIN TRY 

				SELECT		@SubAlgorithm_IterativeScalar_Ro	=	- hv_num.[Value] / hv_denom.[Value] 
				--	
				FROM		@SubAlgorithm_IterativeVector_hv	hv_num 
				INNER JOIN	@SubAlgorithm_IterativeVector_hv	hv_denom	ON	hv_num.MatrixID = @SubAlgorithm_SubIteration 
																			AND hv_num.RowNumber = @SubAlgorithm_IterativeScalar_L 
																			--
																			AND hv_denom.MatrixID = 1 
																			AND hv_denom.RowNumber = @SubAlgorithm_IterativeScalar_L 
																			--
				--
				;	

			END TRY 
			BEGIN CATCH 

				SET @ErrorMessage = 'Failed to set Ro value in subloop of subalgorithm: subiteration ' + convert(varchar(10),@SubAlgorithm_SubIteration) + ' of iteration ' +  convert(varchar(10),@SubAlgorithm_Iteration) + '.' 
				GOTO ERROR	

			END CATCH 

			--
			--	

			--
			--	z_x	
			--	
			INSERT INTO @SubAlgorithm_IterativeVector_zx 
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 

				SELECT		hx_i.MatrixID 
				,			hx_i.RowNumber 
				,			1 
				,			@SubAlgorithm_IterativeScalar_Ro * hx_1.[Value] + hx_i.[Value] 
				--	
				FROM		@SubAlgorithm_IterativeVector_hx	hx_1 
				INNER JOIN	@SubAlgorithm_IterativeVector_hx	hx_i	ON	hx_1.MatrixID = 1 
																		AND hx_i.MatrixID = @SubAlgorithm_SubIteration 
																		AND hx_1.RowNumber = hx_i.RowNumber 
				--
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 6' 
					GOTO ERROR 
				END		

			--
			--	z_x_i 
			--	
			DELETE FROM @temp_WorkingMatrix_1 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_1   
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	zx.RowNumber 
				,		zx.ColumnNumber 
				,		zx.[Value] 
				--	
				FROM	@SubAlgorithm_IterativeVector_zx	zx	
				--	
				WHERE	zx.MatrixID = @SubAlgorithm_SubIteration 
				--	
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 7' 
					GOTO ERROR 
				END		

			--
			--	z_v  
			--	
			INSERT INTO @SubAlgorithm_IterativeVector_zv    
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	@SubAlgorithm_SubIteration 
				,		P.RowNumber 
				,		P.ColumnNumber 
				,	  - P.[Value] 
				--	
				FROM	math.fcn_Matrix_Product ( @SubAlgorithm_ConstraintMatrix , @temp_WorkingMatrix_1 )  P 
				--	
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 8' 
					GOTO ERROR 
				END		

			--
			--

			--
			--	z_v_i 
			--	
			DELETE FROM @temp_WorkingMatrix_1 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_1   
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	zv.RowNumber 
				,		zv.ColumnNumber 
				,		zv.[Value] 
				--	
				FROM	@SubAlgorithm_IterativeVector_zv	zv	
				--	
				WHERE	zv.MatrixID = @SubAlgorithm_SubIteration 
				--	
				;	

				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 9' 
					GOTO ERROR 
				END		
			
			--
			--	NOTE: @temp_WorkingMatrix_2 is still defined from previous step 
			--	

			--
			--	Dv^-1 * sum of F_(i-j) z_v_j 
			--	
			DELETE FROM @temp_WorkingMatrix_3 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_3   
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	P.RowNumber 
				,		P.ColumnNumber 
				,		P.[Value] 
				--	
				FROM	math.fcn_Matrix_Product ( @SubAlgorithm_IterativeMatrix_DvInv , @temp_WorkingMatrix_2 )  P 
			
				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 10' 
					GOTO ERROR 
				END		

			--
			--
			
			--
			--	Dv^-2 * z_v_i 
			--	
			DELETE FROM @temp_WorkingMatrix_2 ; 
			--	
			INSERT INTO @temp_WorkingMatrix_2   
			(
				RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 
		
				SELECT	P.RowNumber 
				,		P.ColumnNumber 
				,	    P.[Value] 
				--	
				FROM	math.fcn_Matrix_Product ( @SubAlgorithm_IterativeMatrix_DvInvSqu , @temp_WorkingMatrix_1 )  P 
			
				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 11' 
					GOTO ERROR 
				END		

			--
			--

			--
			--	F	
			--	
			INSERT INTO @SubAlgorithm_IterativeVector_F 
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber 
			,	[Value] 
			) 

				SELECT		@SubAlgorithm_SubIteration 
				,			U.RowNumber 
				,			1	
				,			U.[Value] - O.[Value] 
				--	
				FROM		@temp_WorkingMatrix_2	U
				INNER JOIN	@temp_WorkingMatrix_3	O	ON	U.RowNumber = O.RowNumber	
				
				IF @@ROWCOUNT = 0 
				BEGIN 
					SET @ErrorMessage = '0 rows SubAlgorithm SubLoop 12' 
					GOTO ERROR 
				END		

			--
			--

			SET @SubAlgorithm_SubIteration += 1 ; 

			--
			--

		END	-- WHILE 2 

		--
		--

		SET @SubAlgorithm_IterativeScalar_SupremumT = 1.00 ; 
		SET @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep = -0.50 ; 
		
		IF ( SELECT		MIN(X.[Value] + Y.[Value]) 
			 FROM		@SubAlgorithm_IterativeSlack_v	X	
			 INNER JOIN	(
							SELECT		Yz.RowNumber	
							,			Yz.ColumnNumber		
							,			SUM( POWER(@SubAlgorithm_IterativeScalar_SupremumT,convert(float,Yz.MatrixID)) 
											 * Yz.[Value] )		[Value]		
							FROM		@SubAlgorithm_IterativeVector_zv  Yz 
							GROUP BY	Yz.RowNumber	
							,			Yz.ColumnNumber		
						)		 
							Y	ON	X.RowNumber = Y.RowNumber	
								AND X.ColumnNumber = Y.ColumnNumber	
		   ) < 0.00 
		BEGIN	
		
			WHILE ABS( @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep ) > @Min_SubAlgorithm_SupremumT_SearchStep 
			--
			AND	  @SubAlgorithm_IterativeScalar_SupremumT >= -0.000000001	-- added 2018-02-26 to prevent infinite loop 
			--
			BEGIN	

				SET @SubAlgorithm_IterativeScalar_SupremumT += @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep ; 

				IF ( SELECT		MIN(X.[Value] + Y.[Value]) 
					 FROM		@SubAlgorithm_IterativeSlack_v	X	
					 INNER JOIN	(
									SELECT		Yz.RowNumber	
									,			Yz.ColumnNumber		
									,			SUM( POWER(@SubAlgorithm_IterativeScalar_SupremumT,convert(float,Yz.MatrixID)) 
													 * Yz.[Value] )		[Value]		
									FROM		@SubAlgorithm_IterativeVector_zv  Yz 
									GROUP BY	Yz.RowNumber	
									,			Yz.ColumnNumber		
								)		 
									Y	ON	X.RowNumber = Y.RowNumber	
										AND X.ColumnNumber = Y.ColumnNumber	
				   ) >= 0.000000 
				BEGIN 
					
					SET @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep = ABS(@SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep) / convert(float,2.0) ; 

				END		
				ELSE BEGIN 
					
					IF @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep > 0.000000 
					BEGIN 
						SET @SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep = -ABS(@SubAlgorithm_IterativeScalar_SupremumTCurrentSearchStep) / convert(float,2.0) ; 
					END		

				END		
					
			END		

			IF @SubAlgorithm_IterativeScalar_SupremumT < 0.000000 
			BEGIN 
				SET @SubAlgorithm_IterativeScalar_SupremumT = 0.000000 
			END		
					
		END			

		--
		--

			--
			--	Alpha	
			--	

			SET @SubAlgorithm_IterativeScalar_Alpha = @SafetyFactor * @SubAlgorithm_IterativeScalar_SupremumT ; 
			--
			;	
			
		--
		--	

			--
			--	Next iteration x vector		
			--	

			INSERT INTO @SubAlgorithm_NextPoint_x 
			(
				RowNumber 
			,	ColumnNumber	
			,	[Value]		
			)	
				
				SELECT		X.RowNumber		
				,			X.ColumnNumber	
				,			X.[Value] + Y.[Value]	
				--	
				FROM		@SubAlgorithm_IterativePoint_x	X	
				INNER JOIN	(
								SELECT		Yz.RowNumber	
								,			Yz.ColumnNumber		
								,			SUM( POWER(@SubAlgorithm_IterativeScalar_Alpha,convert(float,Yz.MatrixID)) 
													* Yz.[Value] )		[Value]		
								FROM		@SubAlgorithm_IterativeVector_zx  Yz 
								GROUP BY	Yz.RowNumber	
								,			Yz.ColumnNumber		
							)	
								Y	ON	X.RowNumber = Y.RowNumber	
									AND X.ColumnNumber = Y.ColumnNumber		
				--	
				;	
				
		--
		--

			DELETE FROM @SubAlgorithm_IterativePoint_x 
			--
			;	 
				
			INSERT INTO @SubAlgorithm_IterativePoint_x 
				 ( RowNumber , ColumnNumber , [Value] )	
			--	
			SELECT RowNumber , ColumnNumber , [Value] 
			FROM   @SubAlgorithm_NextPoint_x 
			--	
			;	

			DELETE FROM @SubAlgorithm_NextPoint_x 
			--
			;	 

		--
		--

		SET @SubAlgorithm_Iteration += 1 ;	

		--
		--	

		END -- WHILE 1 

		--
		--

		SECTION_SUB_ALGORITHM_EXIT: 
		
		IF @SubAlgorithm_ExitMessage IS NULL 
		BEGIN 
			SET @SubAlgorithm_ExitMessage = 'reached maximum number of iterations.'
		END 
		IF @SubAlgorithm_ExitMessage IS NOT NULL 
		BEGIN	
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm stopped: ' + @SubAlgorithm_ExitMessage ) END ; 
		END		

		--
		--	

		IF @PhaseNumber = 1 
		BEGIN 
			GOTO SECTION_PHASE_1_COMPLETE ; 
		END 
		ELSE IF @PhaseNumber = 2 
		BEGIN 
			GOTO SECTION_PHASE_2_COMPLETE
		END		

	END		

	--
	--
	--
	--
	--
	--

	IF @Mode = 'VIEW' 
	BEGIN 
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Display results.' ) END ; 

			SELECT		'Proposed solution vector:'	 Information		
			,			X.RowNumber 
			,			X.[Value]	
			--	
			FROM		@SubAlgorithm_IterativePoint_x	X	
			ORDER BY	X.RowNumber		ASC		
			--
			;		

			SELECT		'Objective value:'	Information			
			,			@SubAlgorithm_IterativeScalar_CurrentObjectiveValue		[Value]		
			--
			;	

	END		
	ELSE IF @Mode = 'TEMP' 
	BEGIN	
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Store results to input temporary table.' ) END ; 

		BEGIN TRY	

			INSERT INTO #result_usp_LinearOptimization_KarmarkarPowerSeries		
			(
				RowNumber 
			,	[Value]		
			)	

				SELECT		X.RowNumber 
				,			X.[Value]	
				--	
				FROM		@SubAlgorithm_IterativePoint_x	X	
				ORDER BY	X.RowNumber		ASC		
				--
				;	
			
			INSERT INTO #result_usp_LinearOptimization_KarmarkarPowerSeries		
			(
				RowNumber 
			,	[Value]		
			)	

				SELECT		NULL													RowNumber	
				,			@SubAlgorithm_IterativeScalar_CurrentObjectiveValue		[Value]		
				--
				;	

		END TRY 
		BEGIN CATCH		
			SET @ErrorMessage = 'An error was encountered while attempting to populate results in provided temporary table.' 
			GOTO ERROR 
		END CATCH	

	END		

	--
	--
	--
	--
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

/****************************************************************
--	
-- Required input temporary table for @Mode = 'TEMP' :	
--	
	IF OBJECT_ID('tempdb..#result_usp_LinearOptimization_KarmarkarPowerSeries') IS NOT NULL DROP TABLE #result_usp_LinearOptimization_KarmarkarPowerSeries
	CREATE TABLE #result_usp_LinearOptimization_KarmarkarPowerSeries 
	(
		ID				int		not null	identity(1,1)	primary key		
	--
	,	RowNumber		int		null		unique	
	--
	,	[Value]			float	not null	
	--
	) 
	--
	;	
--
--
--	
****************************************************************/	

END 
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Solves (approximately) a linear optimization problem in a particular form using an algorithm from Karmarkar et. al in 1989' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'PROCEDURE',@level1name=N'usp_LinearOptimization_KarmarkarPowerSeries'
--GO

--
--

CREATE PROCEDURE [math].[usp_LinearOptimization] 	
--	
	@MaximizeOrMinimize				varchar(10)						
--
,	@CoefficientVector				math.UTT_MatrixCoordinate	READONLY	
,	@ConstraintVector				math.UTT_MatrixCoordinate	READONLY	
,	@ConstraintMatrix				math.UTT_MatrixCoordinate	READONLY	
,	@ConstraintComparisonSymbols	math.UTT_MatrixCoordinate	READONLY	
--
,	@Mode					varchar(4)		=	'VIEW'		--	'VIEW' , 'TEMP'		
--
,	@DEBUG					bit				=	0		
--	
AS
/**************************************************************************************

	Attempts to (approximately) solve an input linear optimization problem, 
	 using a variation of Karmarkar's algorithm.  


		Example:	

		--	
		--	
		--		maximize		-2X - Y 					
		--		subject to		-X + Y <= 1 				
		--						 X - 2Y <= 4	
		--						 X + Y = 2 
		--						   Y >= 0 		
		--

			DECLARE @ex_MaximizeOrMinimize varchar(10) = 'Maximize' ; 
			--	
			DECLARE @ex_CoefficientVector AS math.UTT_MatrixCoordinate ; 
			DECLARE @ex_ConstraintVector  AS math.UTT_MatrixCoordinate ; 
			DECLARE @ex_ConstraintMatrix  AS math.UTT_MatrixCoordinate ; 
			DECLARE @ex_ConstraintComparisonSymbols AS math.UTT_MatrixCoordinate ; 

				INSERT INTO @ex_CoefficientVector ( RowNumber , ColumnNumber , [Value] ) 
					VALUES ( 1 , 1 , -2 )	
					,	   ( 2 , 1 , -1 ) 

				INSERT INTO @ex_ConstraintVector ( RowNumber , ColumnNumber , [Value] ) 
					VALUES ( 1 , 1 ,  1 )	
					,	   ( 2 , 1 ,  4 ) 	
					,	   ( 3 , 1 ,  2 ) 	
					,	   ( 4 , 1 ,  0 )
					
				INSERT INTO @ex_ConstraintMatrix ( RowNumber , ColumnNumber , [Value] ) 
					VALUES ( 1 , 1 , -1 ) , ( 1 , 2 ,  1 ) 
					,	   ( 2 , 1 ,  1 ) , ( 2 , 2 , -2 ) 
					,	   ( 3 , 1 ,  1 ) , ( 3 , 2 ,  1 ) 
					,	   ( 4 , 1 ,  0 ) , ( 4 , 2 ,  1 ) 
					 
					 --
					 --	 ( -1 for <= )  ;  ( 0 for == )  ;  ( +1 for >= ) 
					 --	 
				INSERT INTO @ex_ConstraintComparisonSymbols ( RowNumber , ColumnNumber , [Value] ) 
					VALUES ( 1 , 1 ,  -1 )	
					,	   ( 2 , 1 ,  -1 ) 	
					,	   ( 3 , 1 ,   0 ) 	
					,	   ( 4 , 1 ,   1 )
					

			EXEC	math.usp_LinearOptimization		
					--	
						@MaximizeOrMinimize				=	@ex_MaximizeOrMinimize	
					--
					,	@CoefficientVector				=	@ex_CoefficientVector	
					,	@ConstraintVector				=	@ex_ConstraintVector 
					,	@ConstraintMatrix				=	@ex_ConstraintMatrix 
					,	@ConstraintComparisonSymbols	=	@ex_ConstraintComparisonSymbols 
					--	
					,	@DEBUG							=	1	
					--							
					;							
			

	Date			Action	
	----------		----------------------------
	2018-02-04		Created initial version.	 

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	--
	--

	DECLARE		@ErrorMessage								varchar(500)	
	,			@RowCount									int			
	--
	,			@ProcedureReturnValue						int		
	--
	--	
	,			@NumberOfVariables							int		
	,			@NumberOfConstraints						int		
	--
	--	
	,			@Karmarkar_SafetyFactor						float 
	,			@Karmarkar_TaylorSeriesOrder				int 
	-- 
	,			@Karmarkar_MuForBigM						float	
	,			@Karmarkar_FeasibilityTolerance				float	
	--
	,			@Karmarkar_Max_SubAlgorithm_Iterations		int		
	--
	--
	;
	
	--
	--

	--	
	DECLARE @Karmarkar_CoefficientVector AS math.UTT_MatrixCoordinate ; 
	DECLARE @Karmarkar_ConstraintVector AS math.UTT_MatrixCoordinate ; 
	DECLARE @Karmarkar_ConstraintMatrix AS math.UTT_MatrixCoordinate ; 
	--	

	CREATE TABLE #result_usp_LinearOptimization_KarmarkarPowerSeries 
	(
		ID				int		not null	identity(1,1)	primary key		
	--
	,	RowNumber		int		null		unique	
	--
	,	[Value]			float	not null	
	--
	) 
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

		IF @Mode IS NULL 
		BEGIN 
			SET @Mode = 'VIEW' ; 
		END		
		IF @Mode NOT IN ( 'VIEW' , 'TEMP' )		
		BEGIN 
			SET @ErrorMessage = 'The provided @Mode value is unexpected. Acceptable values are ''VIEW'' or ''TEMP''.'	 
			GOTO ERROR 
		END		

	--
	--

		IF @Mode = 'TEMP' 
		BEGIN 

			IF OBJECT_ID('tempdb..#result_usp_LinearOptimization') IS NULL 
			BEGIN 
				SET @ErrorMessage = 'For @Mode = ''TEMP'', a temporary table called #result_usp_LinearOptimization must exist. Check bottom of procedure definition.' 
				GOTO ERROR 
			END		

			IF EXISTS ( SELECT	null 
						FROM	#result_usp_LinearOptimization )	
			BEGIN 
				SET @ErrorMessage = 'Input temporary table (#result_usp_LinearOptimization) must be empty.' 
				GOTO ERROR 
			END		

			BEGIN TRY 

				INSERT INTO #result_usp_LinearOptimization 
				(
					RowNumber	
				,	[Value]		
				) 
					SELECT	X.RowNumber		
					,		X.[Value]	
					FROM	( 
								VALUES	(   7	,  77.77  )		 
							)	
								X	( RowNumber , [Value] )	
					--
					WHERE	1 = 0 ; 
					--	
					;	

			END TRY 
			BEGIN CATCH 
				SET @ErrorMessage = 'Check format of input temporary table (#result_usp_LinearOptimization).' 
				GOTO ERROR 
			END CATCH	

		END		

	--
	--

		IF @MaximizeOrMinimize IS NULL 
		OR @MaximizeOrMinimize NOT IN ( 'Maximize' , 'Minimize' )	
		BEGIN	
			SET @ErrorMessage = '@MaximizeOrMinimize must be either ''Maximize'' or ''Minimize''.' 
			GOTO ERROR 
		END		
		
	--
	--	

		--
		--	check matrices	
		--	

		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @CoefficientVector , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @CoefficientVector.' 
			GOTO ERROR 
		END 

		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @ConstraintVector , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @ConstraintVector.' 
			GOTO ERROR 
		END 
		
		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @ConstraintMatrix , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @ConstraintMatrix.' 
			GOTO ERROR 
		END 

		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @ConstraintComparisonSymbols , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @ConstraintComparisonSymbols.' 
			GOTO ERROR 
		END 

			--
			--	2018-01-26 :: for now, only handle 1 problem at a time.
			--	
		IF EXISTS ( SELECT	null 
					FROM	@CoefficientVector	
					WHERE	MatrixID IS NOT NULL ) 
		OR EXISTS ( SELECT	null 
					FROM	@ConstraintVector
					WHERE	MatrixID IS NOT NULL ) 
		OR EXISTS ( SELECT	null 
					FROM	@ConstraintMatrix
					WHERE	MatrixID IS NOT NULL ) 
		OR EXISTS ( SELECT	null 
					FROM	@ConstraintComparisonSymbols
					WHERE	MatrixID IS NOT NULL ) 
		BEGIN	
			SET @ErrorMessage = 'All input matrices should have NULL MatrixID for all records.' 
			GOTO ERROR 
		END 

	--
	--	

		IF EXISTS ( SELECT	null 
					FROM	@CoefficientVector 
					WHERE	ColumnNumber > 1 ) 
		BEGIN	
			SET @ErrorMessage = '@CoefficientVector should have only one column.' 
			GOTO ERROR 
		END		
		
		IF EXISTS ( SELECT	null 
					FROM	@ConstraintVector 
					WHERE	ColumnNumber > 1 ) 
		BEGIN	
			SET @ErrorMessage = '@ConstraintVector should have only one column.' 
			GOTO ERROR 
		END		
		
		IF EXISTS ( SELECT	null 
					FROM	@ConstraintComparisonSymbols 
					WHERE	ColumnNumber > 1 ) 
		BEGIN	
			SET @ErrorMessage = '@ConstraintComparisonSymbols should have only one column.' 
			GOTO ERROR 
		END		

		SELECT @NumberOfVariables = COUNT(*) FROM @CoefficientVector ; 
		SELECT @NumberOfConstraints = COUNT(*) FROM @ConstraintVector ; 

		IF @NumberOfVariables != ( SELECT MAX(X.ColumnNumber) FROM @ConstraintMatrix X ) 
		OR @NumberOfConstraints != ( SELECT MAX(X.RowNumber) FROM @ConstraintMatrix X ) 
		BEGIN 
			IF @DEBUG = 1 
			BEGIN 
				SELECT	'The size of @ConstraintMatrix is unexpected:'	Information		
				,		MAX(X.RowNumber)		NumberOfRows 
				,		@NumberOfConstraints	ExpectedRows	
				--
				,		MAX(X.ColumnNumber)		NumberOfColumns		
				,		@NumberOfVariables		ExpectedColumns
				--
				FROM	@ConstraintMatrix	X	
			END		

			SET @ErrorMessage = 'The size of the provided @ConstraintMatrix is unexpected.' 
			GOTO ERROR 
		END		 
		
		IF @NumberOfConstraints != ( SELECT MAX(X.RowNumber) FROM @ConstraintComparisonSymbols X ) 
		BEGIN 
			SET @ErrorMessage = 'The number of rows in @ConstraintComparisonSymbols does not match the number of constraints.' 
			GOTO ERROR 
		END		 

		IF EXISTS ( SELECT	null 
					FROM	@ConstraintComparisonSymbols	X	
					WHERE	ROUND(X.[Value],12) NOT IN ( -1 , 0 , 1 ) ) 
		BEGIN 
			SET @ErrorMessage = 'All values in @ConstraintComparisonSymbols must be -1, 0, or 1.' 
			GOTO ERROR 
		END		

	--
	--

		IF ( SELECT MAX(ABS(X.[Value])) FROM @CoefficientVector X ) < 0.0001 
		BEGIN 
			SET @ErrorMessage = 'The provided @CoefficientVector is too close to zero.' 
			GOTO ERROR 
		END		

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'All checks passed successfully.' ) END ; 
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Number of variables:    n = ' + convert(varchar(50),@NumberOfVariables) ) END ; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Number of constraints:  m = ' + convert(varchar(50),@NumberOfConstraints) ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Translate provided problem into form accepted by Karmarkar Power Series algorithm sub-routine.' ) END ; 
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Define coefficient vector:' ) END ; 

		INSERT INTO @Karmarkar_CoefficientVector 
		(
			RowNumber	
		,	ColumnNumber	
		--
		,	[Value]		
		--	
		)	

			SELECT	X.RowNumber 
			,		X.ColumnNumber	
			--
			,		CASE WHEN @MaximizeOrMinimize = 'Maximize'	
						 THEN convert(float,1.000)	
						 ELSE convert(float,-1.000)		 
					END * X.[Value] 
			--	
			FROM	@CoefficientVector	X	
			--
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

		--
		--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Define constraint vector:' ) END ; 

		INSERT INTO @Karmarkar_ConstraintVector 
		(
			RowNumber 
		,	ColumnNumber	
		,	[Value]		
		)	

			SELECT		RANK() OVER ( ORDER BY X.ConstraintType_RankNumber	ASC		
									  ,		   X.RowNumber					ASC 
									  ,		   X.CopyNumber					ASC )	
			,			1	
			,			X.[Value] 
			--
			FROM		(
								--
								--	<= constraints	
								--	
							SELECT		1		ConstraintType_RankNumber	
							,			'<='	ConstraintType	
							--
							,			1		CopyNumber		
							,			V.RowNumber 
							,			V.[Value]	
							--
							FROM		@ConstraintVector				V	
							INNER JOIN	@ConstraintComparisonSymbols	S	ON	V.RowNumber = S.RowNumber	
							WHERE		ROUND(S.[Value],12) = -1	
						
							UNION ALL 
							
								--
								--	== constraints	
								--	
							SELECT		2		ConstraintType_RankNumber	
							,			'=='	ConstraintType	
							--
							,			Z.CopyNumber		
							,			V.RowNumber 
							,			V.[Value] * Z.Multiplier	as	[Value]		
							--
							FROM		@ConstraintVector				V	
							INNER JOIN	@ConstraintComparisonSymbols	S	ON	V.RowNumber = S.RowNumber	
																			AND ROUND(S.[Value],12) = 0	
							CROSS JOIN	(
											VALUES	( 1 ,  1.0000 )	
											,		( 2 , -1.0000 ) 
										)	
											Z	( CopyNumber , Multiplier )  
						
							UNION ALL 

								--
								--	<= constraints	
								--	
							SELECT		3		ConstraintType_RankNumber	
							,			'>='	ConstraintType	
							--
							,			1		CopyNumber		
							,			V.RowNumber 
							,			- V.[Value]		as	[Value]		
							--
							FROM		@ConstraintVector				V	
							INNER JOIN	@ConstraintComparisonSymbols	S	ON	V.RowNumber = S.RowNumber	
							WHERE		ROUND(S.[Value],12) = 1	
							
						)	
							X	
			--
			--
			;
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

		--
		--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' Define constraint matrix:' ) END ; 

		INSERT INTO @Karmarkar_ConstraintMatrix		 
		(
			RowNumber 
		,	ColumnNumber	
		,	[Value]		
		)	

			SELECT		RANK() OVER ( PARTITION BY	X.ColumnNumber	
									  ORDER BY		X.ConstraintType_RankNumber	 ASC		
									  ,				X.RowNumber					 ASC 
									  ,				X.CopyNumber				 ASC )	
			,			X.ColumnNumber 	
			,			X.[Value] 
			--
			FROM		(
								--
								--	<= constraints	
								--	
							SELECT		1		ConstraintType_RankNumber	
							,			'<='	ConstraintType	
							--
							,			1		CopyNumber		
							,			V.RowNumber 
							,			V.ColumnNumber 
							,			V.[Value]	
							--
							FROM		@ConstraintMatrix				V	
							INNER JOIN	@ConstraintComparisonSymbols	S	ON	V.RowNumber = S.RowNumber	
							WHERE		ROUND(S.[Value],12) = -1	
						
							UNION ALL 
							
								--
								--	== constraints	
								--	
							SELECT		2		ConstraintType_RankNumber	
							,			'=='	ConstraintType	
							--
							,			Z.CopyNumber		
							,			V.RowNumber 
							,			V.ColumnNumber
							,			V.[Value] * Z.Multiplier	as	[Value]		
							--
							FROM		@ConstraintMatrix				V	
							INNER JOIN	@ConstraintComparisonSymbols	S	ON	V.RowNumber = S.RowNumber	
																			AND ROUND(S.[Value],12) = 0	
							CROSS JOIN	(
											VALUES	( 1 ,  1.0000 )	
											,		( 2 , -1.0000 ) 
										)	
											Z	( CopyNumber , Multiplier )  
						
							UNION ALL 

								--
								--	<= constraints	
								--	
							SELECT		3		ConstraintType_RankNumber	
							,			'>='	ConstraintType	
							--
							,			1		CopyNumber		
							,			V.RowNumber 
							,			V.ColumnNumber
							,			- V.[Value]		as	[Value]		
							--
							FROM		@ConstraintMatrix				V	
							INNER JOIN	@ConstraintComparisonSymbols	S	ON	V.RowNumber = S.RowNumber	
							WHERE		ROUND(S.[Value],12) = 1	
							
						)	
							X	
			--
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
	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Run Karmarkar Power Series algorithm sub-routine.' ) END ; 

	EXEC	@ProcedureReturnValue = math.usp_LinearOptimization_KarmarkarPowerSeries 
				@CoefficientVector				=	@Karmarkar_CoefficientVector				
			,	@ConstraintVector				=	@Karmarkar_ConstraintVector				
			,	@ConstraintMatrix				=	@Karmarkar_ConstraintMatrix				
			--
			--,	@SafetyFactor					=	@Karmarkar_SafetyFactor						--	
			--,	@TaylorSeriesOrder				=	@Karmarkar_TaylorSeriesOrder				--	2018-02-05 :: for now, use sub-procedure 
			----																				--					default values		
			--,	@MuForBigM						=	@Karmarkar_MuForBigM						--	
			--,	@FeasibilityTolerance			=	@Karmarkar_FeasibilityTolerance				--	
			----																				--	
			--,	@Max_SubAlgorithm_Iterations	=	@Karmarkar_Max_SubAlgorithm_Iterations		--	
			--
			,	@Mode							=	'TEMP'			
			--
			,	@DEBUG							=	@DEBUG 
			--	
	;		

		IF @ProcedureReturnValue = -1 
		BEGIN 
			SET @ErrorMessage = 'An error was encountered during sub-procedure.' 
			GOTO ERROR 
		END 

	--
	--
	--
	--
	--
	--

	IF @Mode = 'VIEW' 
	BEGIN 
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Display results.' ) END ; 

			SELECT		CASE WHEN X.RowNumber IS NULL 
							 THEN 'Objective value:'
							 ELSE 'Proposed solution vector:'	 
						END		Information		
			,			X.RowNumber 
			,			CASE WHEN X.RowNumber IS NULL 
							 AND  @MaximizeOrMinimize = 'Minimize' 
							 THEN - X.[Value]	
							 ELSE X.[Value] 
						END		as	[Value]		
			--	
			FROM		#result_usp_LinearOptimization_KarmarkarPowerSeries	X	
			ORDER BY	X.RowNumber		ASC		
			--
			;		

	END		
	ELSE IF @Mode = 'TEMP' 
	BEGIN	
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Store results to input temporary table.' ) END ; 

		BEGIN TRY	

			INSERT INTO #result_LinearOptimization 
			(
				RowNumber 
			,	[Value]		
			)	

				SELECT		X.RowNumber 
				,			CASE WHEN X.RowNumber IS NULL 
								 AND  @MaximizeOrMinimize = 'Minimize' 
								 THEN - X.[Value]	
								 ELSE X.[Value] 
							END		as	[Value]		
				--	
				FROM		#result_usp_LinearOptimization_KarmarkarPowerSeries	X	
				ORDER BY	X.RowNumber		ASC		
				--
				;		

		END TRY 
		BEGIN CATCH		
			SET @ErrorMessage = 'An error was encountered while attempting to populate results in provided temporary table.' 
			GOTO ERROR 
		END CATCH	

	END		

	--
	--
	--
	--
	--
	--

	--
	--IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Linear optimization attempt complete.' ) END ; 
	--IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Review sub-procedure messages.' ) END ; 
	--	

	FINISH:		

	--
	DROP TABLE #result_usp_LinearOptimization_KarmarkarPowerSeries 
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	RETURN 1 ; 

	--
	--
	
	--
	IF OBJECT_ID('tempdb..#result_usp_LinearOptimization_KarmarkarPowerSeries') IS NOT NULL DROP TABLE #result_usp_LinearOptimization_KarmarkarPowerSeries 
	--
	
	ERROR:	

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END		

	RETURN -1 ; 

/****************************************************************
--	
-- Required input temporary table for @Mode = 'TEMP' :	
--	
	IF OBJECT_ID('tempdb..#result_usp_LinearOptimization') IS NOT NULL DROP TABLE #result_usp_LinearOptimization
	CREATE TABLE #result_usp_LinearOptimization
	(
		ID				int		not null	identity(1,1)	primary key		
	--
	,	RowNumber		int		null		unique	
	--
	,	[Value]			float	not null	
	--
	) 
	--
	;	
--
--
--	
****************************************************************/	

END 
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Solves (approximately) a linear optimization problem in any form' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'PROCEDURE',@level1name=N'usp_LinearOptimization'
--GO

--
--

CREATE PROCEDURE [math].[usp_LogisticRegression]  	
--	
	@Input_Matrix_Explanatory	math.UTT_MatrixCoordinate	READONLY	
,	@Input_Matrix_Dependent		math.UTT_MatrixCoordinate	READONLY	
--
,	@Normalize		bit				=	0			
--
,	@Mode			varchar(4)		=	'VIEW'		--	'VIEW' , 'TEMP'		
--
,	@AllowNonEmptyInputTable	bit		=	0	
--
,	@DEBUG						bit		=	0		
--	
AS	
/**************************************************************************************

	Performs a Logistic Regression for a provided pair of explanatory and dependent
	 variable matrices:
		- returns coefficients defining a linear combination of dependent variables 
		  which best predicts the corresponding explanatory variable values, 
		   after being passed through the standard logistic function. 


		The "dependent" variable values must all be between 0 and 1 (inclusive). 

		The "explanatory" variables can be normalized depending on the @Normalize parameter. 



		Example:	

			--
			--
			
			DECLARE	@Test_Explanatory AS math.UTT_MatrixCoordinate ; 
			DECLARE	@Test_Dependent AS math.UTT_MatrixCoordinate ; 

			INSERT INTO @Test_Explanatory 
			(	
				RowNumber
			,	ColumnNumber 
			,	Value 
			)	

				VALUES	( 1  , 1  , 0.8	 )	,	( 1  , 2 , 0.83	)	,	( 1  , 3 , 0.66	 )	,	( 1  , 4 , 1.9 )  ,   ( 1  , 5 , 1.1	)  ,  ( 1  , 6 , 1	  )  ,  ( 1  , 7 , 1 )	
				,		( 2  , 1  , 0.9	 )	,	( 2  , 2 , 0.36	)	,	( 2  , 3 , 0.32	 )	,	( 2  , 4 , 1.4 )  ,   ( 2  , 5 , 0.74	)  ,  ( 2  , 6 , 0.99 )  ,  ( 2  , 7 , 1 )	
				,		( 3  , 1  , 0.8	 )	,	( 3  , 2 , 0.88	)	,	( 3  , 3 , 0.7	 )	,	( 3  , 4 , 0.8 )  ,   ( 3  , 5 , 0.18	)  ,  ( 3  , 6 , 0.98 )  ,  ( 3  , 7 , 1 )	
				,		( 4  , 1  , 1	 )	,	( 4  , 2 , 0.87	)	,	( 4  , 3 , 0.87	 )	,	( 4  , 4 , 0.7 )  ,   ( 4  , 5 , 1.05	)  ,  ( 4  , 6 , 0.99 )  ,  ( 4  , 7 , 1 )	
				,		( 5  , 1  , 0.9	 )	,	( 5  , 2 , 0.75	)	,	( 5  , 3 , 0.68	 )	,	( 5  , 4 , 1.3 )  ,   ( 5  , 5 , 0.52	)  ,  ( 5  , 6 , 0.98 )  ,  ( 5  , 7 , 1 )	
				,		( 6  , 1  , 1	 )	,	( 6  , 2 , 0.65	)	,	( 6  , 3 , 0.65	 )	,	( 6  , 4 , 0.6 )  ,   ( 6  , 5 , 0.52	)  ,  ( 6  , 6 , 0.98 )  ,  ( 6  , 7 , 1 )	
				,		( 7  , 1  , 0.95 )	,	( 7  , 2 , 0.97	)	,	( 7  , 3 , 0.92	 )	,	( 7  , 4 , 1   )  ,   ( 7  , 5 , 1.23	)  ,  ( 7  , 6 , 0.99 )  ,  ( 7  , 7 , 1 )	
				,		( 8  , 1  , 0.95 )	,	( 8  , 2 , 0.87	)	,	( 8  , 3 , 0.83	 )	,	( 8  , 4 , 1.9 )  ,   ( 8  , 5 , 1.35	)  ,  ( 8  , 6 , 1.02 )  ,  ( 8  , 7 , 1 )	
				,		( 9  , 1  , 1	 )	,	( 9  , 2 , 0.45	)	,	( 9  , 3 , 0.45	 )	,	( 9  , 4 , 0.8 )  ,   ( 9  , 5 , 0.32	)  ,  ( 9  , 6 , 1	  )  ,  ( 9  , 7 , 1 )	
				,		( 10 , 1  , 0.95 )	,	( 10 , 2 , 0.36	)	,	( 10 , 3 , 0.34	 )	,	( 10 , 4 , 0.5 )  ,   ( 10 , 5 , 0		)  ,  ( 10 , 6 , 1.04 )  ,  ( 10 , 7 , 1 )	
				,		( 11 , 1  , 0.85 )	,	( 11 , 2 , 0.39	)	,	( 11 , 3 , 0.33	 )	,	( 11 , 4 , 0.7 )  ,   ( 11 , 5 , 0.28	)  ,  ( 11 , 6 , 0.99 )  ,  ( 11 , 7 , 1 )	
				,		( 12 , 1  , 0.7	 )	,	( 12 , 2 , 0.76	)	,	( 12 , 3 , 0.53	 )	,	( 12 , 4 , 1.2 )  ,   ( 12 , 5 , 0.15	)  ,  ( 12 , 6 , 0.98 )  ,  ( 12 , 7 , 1 )	
				,		( 13 , 1  , 0.8	 )	,	( 13 , 2 , 0.46	)	,	( 13 , 3 , 0.37	 )	,	( 13 , 4 , 0.4 )  ,   ( 13 , 5 , 0.38	)  ,  ( 13 , 6 , 1.01 )  ,  ( 13 , 7 , 1 )	
				,		( 14 , 1  , 0.2	 )	,	( 14 , 2 , 0.39	)	,	( 14 , 3 , 0.08	 )	,	( 14 , 4 , 0.8 )  ,   ( 14 , 5 , 0.11	)  ,  ( 14 , 6 , 0.99 )  ,  ( 14 , 7 , 1 )	
				,		( 15 , 1  , 1	 )	,	( 15 , 2 , 0.9	)	,	( 15 , 3 , 0.9	 )	,	( 15 , 4 , 1.1 )  ,   ( 15 , 5 , 1.04	)  ,  ( 15 , 6 , 0.99 )  ,  ( 15 , 7 , 1 )	
				,		( 16 , 1  , 1	 )	,	( 16 , 2 , 0.84	)	,	( 16 , 3 , 0.84	 )	,	( 16 , 4 , 1.9 )  ,   ( 16 , 5 , 2.06	)  ,  ( 16 , 6 , 1.02 )  ,  ( 16 , 7 , 1 )	
				,		( 17 , 1  , 0.65 )	,	( 17 , 2 , 0.42	)	,	( 17 , 3 , 0.27	 )	,	( 17 , 4 , 0.5 )  ,   ( 17 , 5 , 0.11	)  ,  ( 17 , 6 , 1.01 )  ,  ( 17 , 7 , 1 )	
				,		( 18 , 1  , 1	 )	,	( 18 , 2 , 0.75	)	,	( 18 , 3 , 0.75	 )	,	( 18 , 4 , 1   )  ,   ( 18 , 5 , 1.32	)  ,  ( 18 , 6 , 1	  )  ,  ( 18 , 7 , 1 )	
				,		( 19 , 1  , 0.5	 )	,	( 19 , 2 , 0.44	)	,	( 19 , 3 , 0.22	 )	,	( 19 , 4 , 0.6 )  ,   ( 19 , 5 , 0.11	)  ,  ( 19 , 6 , 0.99 )  ,  ( 19 , 7 , 1 )	
				,		( 20 , 1  , 1	 )	,	( 20 , 2 , 0.63	)	,	( 20 , 3 , 0.63	 )	,	( 20 , 4 , 1.1 )  ,   ( 20 , 5 , 1.07	)  ,  ( 20 , 6 , 0.99 )  ,  ( 20 , 7 , 1 )	
				,		( 21 , 1  , 1	 )	,	( 21 , 2 , 0.33	)	,	( 21 , 3 , 0.33	 )	,	( 21 , 4 , 0.4 )  ,   ( 21 , 5 , 0.18	)  ,  ( 21 , 6 , 1.01 )  ,  ( 21 , 7 , 1 )	
				,		( 22 , 1  , 0.9	 )	,	( 22 , 2 , 0.93	)	,	( 22 , 3 , 0.84	 )	,	( 22 , 4 , 0.6 )  ,   ( 22 , 5 , 1.59	)  ,  ( 22 , 6 , 1.02 )  ,  ( 22 , 7 , 1 )	
				,		( 23 , 1  , 1	 )	,	( 23 , 2 , 0.58	)	,	( 23 , 3 , 0.58	 )	,	( 23 , 4 , 1   )  ,   ( 23 , 5 , 0.53	)  ,  ( 23 , 6 , 1	  )  ,  ( 23 , 7 , 1 )	
				,		( 24 , 1  , 0.95 )	,	( 24 , 2 , 0.32	)	,	( 24 , 3 , 0.3	 )	,	( 24 , 4 , 1.6 )  ,   ( 24 , 5 , 0.89	)  ,  ( 24 , 6 , 0.99 )  ,  ( 24 , 7 , 1 )	
				,		( 25 , 1  , 1	 )	,	( 25 , 2 , 0.6	)	,	( 25 , 3 , 0.6	 )	,	( 25 , 4 , 1.7 )  ,   ( 25 , 5 , 0.96	)  ,  ( 25 , 6 , 0.99 )  ,  ( 25 , 7 , 1 )	
				,		( 26 , 1  , 1	 )	,	( 26 , 2 , 0.69	)	,	( 26 , 3 , 0.69	 )	,	( 26 , 4 , 0.9 )  ,   ( 26 , 5 , 0.4	)  ,  ( 26 , 6 , 0.99 )  ,  ( 26 , 7 , 1 )	
				,		( 27 , 1  , 1	 )	,	( 27 , 2 , 0.73	)	,	( 27 , 3 , 0.73	 )	,	( 27 , 4 , 0.7 )  ,   ( 27 , 5 , 0.4	)  ,  ( 27 , 6 , 0.99 )  ,  ( 27 , 7 , 1 )	
				--
				;	
				
			INSERT INTO @Test_Dependent		
			(	
				RowNumber
			,	ColumnNumber 
			,	Value 
			)	

				VALUES		(  1  , 1 , 1  )	
				,			(  2  , 1 , 1  )	
				,			(  3  , 1 , 0  )	
				,			(  4  , 1 , 0  )	
				,			(  5  , 1 , 1  )	
				,			(  6  , 1 , 0  )	
				,			(  7  , 1 , 1  )	
				,			(  8  , 1 , 0  )	
				,			(  9  , 1 , 0  )
				,			(  10 , 1 , 0  )
				,			(  11 , 1 , 0  )
				,			(  12 , 1 , 0  )
				,			(  13 , 1 , 0  )
				,			(  14 , 1 , 0  )
				,			(  15 , 1 , 0  )
				,			(  16 , 1 , 1  )
				,			(  17 , 1 , 0  )
				,			(  18 , 1 , 0  )
				,			(  19 , 1 , 0  )
				,			(  20 , 1 , 1  )
				,			(  21 , 1 , 0  )
				,			(  22 , 1 , 0  )
				,			(  23 , 1 , 1  )
				,			(  24 , 1 , 0  )
				,			(  25 , 1 , 1  )
				,			(  26 , 1 , 1  )
				,			(  27 , 1 , 0  )	
				--	
				;	

			--
			--
			
				EXEC	math.usp_LogisticRegression		
							@Input_Matrix_Explanatory	=	@Test_Explanatory	
						,	@Input_Matrix_Dependent		=	@Test_Dependent		
						--
						,	@Normalize	 =	0	
						--
						,	@Mode		 =  'VIEW'	
						--
						,	@DEBUG		 =	1		
						-- 
				--	
				;			

			--
			--

	Date			Action	
	----------		----------------------------
	2019-01-31		Created initial version. 
	2019-05-27		Enabled @Mode = 'TEMP'.	 
	2019-07-16		Added @AllowNonEmptyInputTable parameter. 
	2019-07-23		Replacing usage of [math].[fcn_StandardLogisticFunction] with explicit expression.
					Also eliminated duplicate calculations and broke up calculations into multiple steps. 
					Hopefully this will improve the speed of the procedure, especially for larger input sets.  

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	--
	--

	DECLARE		@ErrorMessage				varchar(500)	
	,			@RowCount					int			
	-- 
	,			@CurrentIteration			int		=	1 
	,			@MaximumNumberOfIterations	int		=	100		
	--
	,			@InitialGuess_Coefficient	float	=	0.05	 	
	--
	,			@StoppingCriteria_Threshold_LogLikelihoodImprovement	float	=	0.000001	
	,			@StoppingCriteria_Threshold_DistanceBetweenGuesses		float	=	0.00001	
	--
	;
	
	--
	--

	DECLARE @t_Scaler TABLE 
	(
		ID						int		not null	identity(1,1)	primary key		 
	--
	,	MatrixID				int		null		
	,	ColumnNumber			int		not null		
	--
	,	Mean					float	not null 
	,	StandardDeviation		float	not null	
	--	
	,	UNIQUE	(
					MatrixID	
				,	ColumnNumber	
				)	
	--	
	)	
	--
	;	

	--
	--
	
		DECLARE @t_RowVectors_Explanatory AS math.UTT_MatrixCoordinate ; 
		DECLARE @t_RowVectors_Dependent AS math.UTT_MatrixCoordinate ; 
		
		--
		--
				
		DECLARE @t_NewtonMethod_ColumnVector_PreviousGuess AS math.UTT_MatrixCoordinate ; 

		DECLARE @t_NewtonMethod_LogLikelihood_Gradient AS math.UTT_MatrixCoordinate ; 
		DECLARE @t_NewtonMethod_LogLikelihood_Hessian AS math.UTT_MatrixCoordinate ; 

		DECLARE @t_NewtonMethod_LogLikelihood_HessianInverse AS math.UTT_MatrixCoordinate ; 

		DECLARE @t_NewtonMethod_ColumnVector_NextStep AS math.UTT_MatrixCoordinate ;  
		
		DECLARE @t_NewtonMethod_ColumnVector_NextGuess AS math.UTT_MatrixCoordinate ; 
		
	--
	--

		--
		--	2019-07-23	
		--	
		DECLARE @t_IntermediaryCalculation_PreviousGuessStandardLogisticFunction TABLE 
		(
			ID					int		not null	identity(1,1)	primary key		
		--
		,	MatrixID			int		null		
		,	RowNumber			int		not null	
		--
		,	SigmaThetaX			float	null	
		--
		,	UNIQUE	(
						MatrixID	
					,	RowNumber	
					)	
		--
		) 
		--
		;	 
		DECLARE @t_IntermediaryCalculation_NextGuessStandardLogisticFunction TABLE 
		(
			ID					int		not null	identity(1,1)	primary key		
		--
		,	MatrixID			int		null		
		,	RowNumber			int		not null	
		--
		,	SigmaThetaX			float	null	
		--
		,	UNIQUE	(
						MatrixID	
					,	RowNumber	
					)	
		--
		) 
		--
		;	
		--
		--  // 2019-07-23 
		-- 

	--
	--

		DECLARE @t_StoppingCriteria	TABLE 
		(
			ID							int		not null	identity(1,1)	primary key			
		--
		,	MatrixID					int		null		
		--
		,	IterationNumber				int		not null	
		--
		,	LogLikelihood_Previous		float	null	
		,	LogLikelihood_Current		float	null		
		--
		,	LogLikelihoodImprovement	float	null		
		,	DistanceBetweenGuesses		float	null		
		,	FailedToSetNextGuess		bit		null	
		--
		,	IsStopped					bit		not null	
		--
		)	
		--
		;	

			INSERT INTO @t_StoppingCriteria		
			(
				MatrixID	
			,	IterationNumber		
			--
			,	IsStopped 
			--
			)	

				SELECT	distinct  X.MatrixID		--	MatrixID	
				,				  0					--	IterationNumber		
				--
				,				  0					--	IsStopped	
				--
				FROM	@Input_Matrix_Dependent	 X		
				--
				;	
				
	--
	--

		DECLARE @Output_Staging TABLE 
		(
			ID				int				not null	identity(1,1)	primary key		
		--
		,	MatrixID		int				null	
		--	
		,	Result			varchar(30)		not null	
		--	
		,	RowNumber		int				null	
		,	ColumnNumber	int				null	
		,	[Value]			float			not null	
		--	
		,	UNIQUE  (
						MatrixID
					--		
					,	Result	
					--	
					,	RowNumber	
					,	ColumnNumber	
					--		
					)
		)	
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

		IF @Mode IS NULL 
		BEGIN 
			SET @Mode = 'VIEW' ; 
		END		
		IF @Mode NOT IN ( 'VIEW' , 'TEMP' )		
		BEGIN 
			SET @ErrorMessage = 'The provided @Mode value is unexpected. Acceptable values are ''VIEW'' or ''TEMP''.'	 
			GOTO ERROR 
		END		

	--
	--

		IF @Normalize IS NULL 
		BEGIN 
			SET @Normalize = 0 ; 
		END		

	--
	--

		IF @Mode = 'TEMP' 
		BEGIN 

			IF OBJECT_ID('tempdb..#result_usp_LogisticRegression') IS NULL 
			BEGIN 
				SET @ErrorMessage = 'For @Mode = ''TEMP'', a temporary table called #result_usp_LogisticRegression must exist. Check bottom of procedure definition.' 
				GOTO ERROR 
			END		

			IF EXISTS ( SELECT	null 
						FROM	#result_usp_LogisticRegression )	
			--
			AND coalesce(@AllowNonEmptyInputTable,0) = 0 
			--
			BEGIN 
				SET @ErrorMessage = 'Input temporary table (#result_usp_LogisticRegression) must be empty.' 
				GOTO ERROR 
			END		

			BEGIN TRY 

				INSERT INTO #result_usp_LogisticRegression
				(
					MatrixID		
				--					
				,	Result			
				--					
				,	RowNumber		
				,	ColumnNumber	
				,	[Value]			
				--
				) 
					SELECT	X.MatrixID		
					--					
					,		X.Result			
					--					
					,		X.RowNumber		
					,		X.ColumnNumber	
					,		X.[Value]			
					--
					FROM	( 
								VALUES	(   777		
										--					
										,	'Loading Vector' 			
										--			
										,	777		
										,	777	
										,	7.77	 
										--	
										)		 
							)	
								X	(   MatrixID		
									--					
									,	Result			
									--			
									,	RowNumber		
									,	ColumnNumber	
									,	[Value]	 
									--	
									)	
					--
					WHERE	1 = 0 ; 
					--	
					;	

			END TRY 
			BEGIN CATCH 
				SET @ErrorMessage = 'Check format of input temporary table (#result_usp_LogisticRegression).' 
				GOTO ERROR 
			END CATCH	

		END		

	--
	--	
	
		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix_Explanatory , 0 , 0 ) = 0 
		BEGIN 
		
			SET @ErrorMessage = 'Matrix integrity check failed for input @Input_Matrix_Explanatory.' 
			GOTO ERROR 

		END		
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix_Dependent , 0 , 0 ) = 0 
		BEGIN 
		
			SET @ErrorMessage = 'Matrix integrity check failed for input @Input_Matrix_Dependent.' 
			GOTO ERROR 

		END		

		--
		--	Check that the dependent matrix is a column vector with the same number 
		--	 of rows as the explanatory matrix 
		-- 

		IF EXISTS ( SELECT	null 
					FROM	@Input_Matrix_Dependent		X	
					WHERE	X.ColumnNumber > 1 ) 
		OR EXISTS ( SELECT	null 
					FROM	(
								SELECT		Xa.MatrixID 
								,			MAX( Xa.RowNumber )	MaxRowNumber	
								FROM		@Input_Matrix_Explanatory	Xa	
								GROUP BY	Xa.MatrixID 
							)
									A	
					FULL JOIN	(
									SELECT		Xb.MatrixID 
									,			MAX( Xb.RowNumber )	MaxRowNumber	
									FROM		@Input_Matrix_Dependent	Xb	
									GROUP BY	Xb.MatrixID 
								)	 
									B	ON	(
												A.MatrixID = B.MatrixID 
											OR	(
													A.MatrixID IS NULL 
												AND B.MatrixID IS NULL 
												)		
											)	
										AND A.MaxRowNumber = B.MaxRowNumber 
					--	
					WHERE	A.MaxRowNumber IS NULL 
					OR		B.MaxRowNumber IS NULL	)	
		BEGIN 
		
			SET @ErrorMessage = 'Number of dependent variable values does not match number of explanatory variable rows for at least one input matrix.' 
			GOTO ERROR 

		END		

	--
	--	
	
		--
		--	Check that the response variable values are all between 0 and 1
		-- 

		IF EXISTS ( SELECT	null 
					FROM	@Input_Matrix_Dependent		X	
					WHERE	X.[Value] < 0.00 
					OR		X.[Value] > 1.00 ) 
		BEGIN 
		
			SET @ErrorMessage = 'At least one dependent variable value is outside the [0,1] interval.' 
			GOTO ERROR 

		END		 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'All checks passed successfully.' ) END ; 
	
	--
	--
	
	IF @Normalize = 1 
	BEGIN	

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Scale explanatory row vectors.' ) END ; 
	
			INSERT INTO @t_Scaler	
			(
				MatrixID 
			,	ColumnNumber 
			--
			,	Mean 
			,	StandardDeviation 
			--	
			)	

				SELECT		X.MatrixID 
				,			X.ColumnNumber 
				--
				,			0.00			--  2019-01-31 -- DON'T SHIFT	 -- AVG( X.[Value] )	 --	Mean				
				,			MAX(X.[Value])	--  2019-01-31 -- use max val. ? --	STDEVP( X.[Value] )	 --	StandardDeviation	
				--	
				FROM		@Input_Matrix_Explanatory	  X  
				--	
				GROUP BY	X.MatrixID 
				,			X.ColumnNumber 
				--
				;	
		
	END		
	ELSE BEGIN 
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Cache explanatory row vectors.' ) END ; 

	END		

	--
	--

	INSERT INTO @t_RowVectors_Explanatory	 
	(
		MatrixID	
	,	RowNumber 
	,	ColumnNumber 
	,	[Value] 
	)	

		SELECT	 X.MatrixID	
		,		 X.RowNumber 
		,		 X.ColumnNumber 
		--
		,		 ( X.[Value] - coalesce(S.Mean,convert(float,0.00)) ) 
				 / CASE WHEN S.StandardDeviation <= convert(float,0.00)			
						OR	 S.StandardDeviation IS NULL 
						THEN convert(float,1.00) 
						ELSE coalesce(S.StandardDeviation,convert(float,1.00))	
				   END 
				 -- Value 
		--			
		FROM		@Input_Matrix_Explanatory	X		
		LEFT  JOIN	@t_Scaler					S	
						--	
						ON	(
								X.MatrixID = S.MatrixID 
							OR	(
									X.MatrixID IS NULL	
								AND S.MatrixID IS NULL	
								)	
							)
						--
						AND	X.ColumnNumber = S.ColumnNumber 
						--
		--
		;	
		
	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Cache dependent variable values.' ) END ; 

		INSERT INTO @t_RowVectors_Dependent	 
		(
			MatrixID	
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		)	

		SELECT	 X.MatrixID	
		,		 X.RowNumber 
		,		 X.ColumnNumber 
		,		 X.[Value]	
		--
		FROM	@Input_Matrix_Dependent  X	
		--	
		;	

	SET @RowCount = @@ROWCOUNT 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Set initial coefficient vector for Newton''s Method.' ) END ; 
	 
		INSERT INTO @t_NewtonMethod_ColumnVector_PreviousGuess 
		(
			MatrixID 
		,	RowNumber
		,	ColumnNumber
		,	[Value]		
		)	

			SELECT	E.MatrixID					-- MatrixID	
			,		E.ColumnNumber				-- RowNumber	
			,		1							-- ColumnNumber 
			,		@InitialGuess_Coefficient 	-- [Value]		
			--	
			FROM	@Input_Matrix_Explanatory	E	
			WHERE	E.RowNumber = 1			
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

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Perform Newton''s Method to determine optimal coefficient vector.' ) END ; 
		
	--
	--

	WHILE	@CurrentIteration <= @MaximumNumberOfIterations 
	AND		EXISTS ( SELECT	null 
					 FROM	@t_StoppingCriteria		C	
					 WHERE	C.IsStopped = 0 )	
/**/BEGIN	

	--
	--	

		--
		--	Compute gradient vector for log-likelihood function 
		--	


			--
			--	2019-07-23 :: first cache Standard Logistic Function values for Prev. Guess on each Matrix & Row pair 
			--	

			INSERT INTO @t_IntermediaryCalculation_PreviousGuessStandardLogisticFunction  
			(
				MatrixID		
			,	RowNumber		
			--
			,	SigmaThetaX		
			--
			)	

				SELECT		E.MatrixID	
				,			E.RowNumber		
				--
				--,			math.fcn_StandardLogisticFunction 
				--			( 
				--				SUM( E.[Value] * P.[Value] )	
				--			)	
				--  2019-07-23 :: replace fcn_ with explicit expression, hopefully for speed gain 
				,			convert(float,1.000) 
						/ ( convert(float,1.000) + EXP( -SUM( E.[Value] * P.[Value] ) ) ) 
								as	SigmaThetaX		
				--
				FROM		@t_NewtonMethod_ColumnVector_PreviousGuess	P	
				INNER JOIN	@t_RowVectors_Explanatory					E 
								--	
								ON	(
										P.MatrixID = E.MatrixID		
									OR	(
											P.MatrixID IS NULL 
										AND E.MatrixID IS NULL	
										)	
									)	
								--
								AND P.RowNumber = E.ColumnNumber 
								--	
				--
				GROUP BY	E.MatrixID	
				,			E.RowNumber		
				--
				;	
				
			--
			--	// 2019-07-23	
			--	

		INSERT INTO @t_NewtonMethod_LogLikelihood_Gradient 
		(
			MatrixID	
		--
		,	RowNumber	
		,	ColumnNumber	
		,	[Value]		
		--	
		)	

			SELECT	A.MatrixID											-- MatrixID	
			--															
			,		C.ColumnNumber 										-- RowNumber	
			,		1 													-- ColumnNumber	
			,		SUM(  ( B.[Value] - A.SigmaThetaX ) * C.[Value]  )	-- [Value]	
			--
			FROM	@t_IntermediaryCalculation_PreviousGuessStandardLogisticFunction
													A	
			--	
			INNER JOIN	@t_RowVectors_Dependent		B	ON	(
																A.MatrixID = B.MatrixID		
															OR	(
																	A.MatrixID IS NULL 
																AND B.MatrixID IS NULL	
																)	
															)	
														--
														AND A.RowNumber = B.RowNumber	
														--	
			--
			INNER JOIN	@t_RowVectors_Explanatory	C	ON	(
																A.MatrixID = C.MatrixID		
															OR	(
																	A.MatrixID IS NULL 
																AND C.MatrixID IS NULL	
																)	
															)	
														--
														AND A.RowNumber = C.RowNumber	
														--	
			--
			GROUP BY	A.MatrixID	
			--	
			,			C.ColumnNumber	
			--	
			;	

	--
	--

		--
		--	Compute Hessian matrix for log-likelihood function 
		--	
		
		INSERT INTO @t_NewtonMethod_LogLikelihood_Hessian 
		(
			MatrixID	
		--
		,	RowNumber	
		,	ColumnNumber	
		,	[Value]		
		--	
		)	
		 
			SELECT	A.MatrixID											-- MatrixID	
			--															
			,		C.ColumnNumber 										-- RowNumber	
			,		D.ColumnNumber										-- ColumnNumber	
			,		SUM( - C.[Value] 
						 * D.[Value] 
				         * A.SigmaThetaX 
						 * ( convert(float,1.00) - A.SigmaThetaX ) 
					   )												-- [Value]	
			--
			FROM	@t_IntermediaryCalculation_PreviousGuessStandardLogisticFunction
													A		
			--
			INNER JOIN	@t_RowVectors_Dependent		B	ON	(
																A.MatrixID = B.MatrixID		
															OR	(
																	A.MatrixID IS NULL 
																AND B.MatrixID IS NULL	
																)	
															)	
														--
														AND A.RowNumber = B.RowNumber	
														--	
			--
			INNER JOIN	@t_RowVectors_Explanatory	C	ON	(
																A.MatrixID = C.MatrixID		
															OR	(
																	A.MatrixID IS NULL 
																AND C.MatrixID IS NULL	
																)	
															)	
														--
														AND A.RowNumber = C.RowNumber	
														--	
			INNER JOIN	@t_RowVectors_Explanatory	D	ON	(
																A.MatrixID = D.MatrixID		
															OR	(
																	A.MatrixID IS NULL 
																AND D.MatrixID IS NULL	
																)	
															)	
														--
														AND A.RowNumber = D.RowNumber	
														--	
			--
			GROUP BY	A.MatrixID 
			--	
			,			C.ColumnNumber	
			,			D.ColumnNumber 
			--	
			;	
			
	--
	--
		
		--
		--	Find inverse of Hessian matrix 
		--	
		
			INSERT INTO @t_NewtonMethod_LogLikelihood_HessianInverse	
			(
				MatrixID	
			--
			,	RowNumber	
			,	ColumnNumber	
			,	[Value]		
			--	
			)	

				SELECT	X.MatrixID	
				--
				,		X.RowNumber	
				,		X.ColumnNumber	
				,		X.[Value]		
				--	 
				FROM	math.fcn_Matrix_Inverse ( @t_NewtonMethod_LogLikelihood_Hessian )  X	
				--
				;	

	--
	--	
		
		--
		--	Determine "next step" direction and magnitude for iterative optimization process		
		--	

			INSERT INTO @t_NewtonMethod_ColumnVector_NextStep 	
			(
				MatrixID	
			--
			,	RowNumber	
			,	ColumnNumber	
			,	[Value]		
			--	
			)	

				SELECT	X.MatrixID	
				--
				,		X.RowNumber	
				,		X.ColumnNumber	
				,	  - X.[Value]		
				--	 
				FROM	math.fcn_Matrix_Product ( @t_NewtonMethod_LogLikelihood_HessianInverse
												, @t_NewtonMethod_LogLikelihood_Gradient )  X	
				--
				;	

	--
	--

			INSERT INTO @t_NewtonMethod_ColumnVector_NextGuess 
			(
				MatrixID	
			--
			,	RowNumber 
			,	ColumnNumber	
			,	[Value]		
			--	
			)	

				SELECT		P.MatrixID	
				--
				,			P.RowNumber		
				,			P.ColumnNumber	
				,			P.[Value] + S.[Value]
				--	
				FROM		@t_NewtonMethod_ColumnVector_PreviousGuess	P	
				INNER JOIN	@t_NewtonMethod_ColumnVector_NextStep		S	
								--
								ON	(
										P.MatrixID = S.MatrixID		
									OR	(
											P.MatrixID IS NULL 
										AND S.MatrixID IS NULL	
										)	
									)	
								--
								AND P.RowNumber = S.RowNumber	
								--	
				--
				;	

	--
	--	

		--
		--	Evaluate stopping criteria	
		--	

		UPDATE	@t_StoppingCriteria  
		SET		IterationNumber += 1 
		,		IsStopped = CASE WHEN @CurrentIteration = @MaximumNumberOfIterations  
								 THEN 1 
								 ELSE 0 
							END		
		--	
		WHERE	IsStopped = 0 
		--
		;	

	--
	--	

		UPDATE		SC
		--	
		SET			SC.FailedToSetNextGuess = 1 
		,			SC.IsStopped = 1 
		--	
		FROM		@t_StoppingCriteria						SC		
		LEFT  JOIN	@t_NewtonMethod_ColumnVector_NextGuess	NG	ON	SC.MatrixID = NG.MatrixID	
																OR	(
																		SC.MatrixID	IS NULL 
																	AND NG.MatrixID IS NULL		
																	)	
		--
		WHERE		SC.IsStopped = 0 
		AND			NG.ID IS NULL	
		--
		;	

	--
	--	
	
			--
			--	2019-07-23 :: cache Standard Logistic Function values for Next Guess on each Matrix & Row pair 
			--	

			INSERT INTO @t_IntermediaryCalculation_NextGuessStandardLogisticFunction  
			(
				MatrixID		
			,	RowNumber		
			--
			,	SigmaThetaX		
			--
			)	

				SELECT		E.MatrixID	
				,			E.RowNumber		
				--
				--,			math.fcn_StandardLogisticFunction 
				--			( 
				--				SUM( E.[Value] * P.[Value] )	
				--			)	
				--  2019-07-23 :: replace fcn_ with explicit expression, hopefully for speed gain 
				,			convert(float,1.000) 
						/ ( convert(float,1.000) + EXP( -SUM( E.[Value] * P.[Value] ) ) ) 
								as	SigmaThetaX		
				--
				FROM		@t_NewtonMethod_ColumnVector_NextGuess	P	
				INNER JOIN	@t_RowVectors_Explanatory				E 
								--	
								ON	(
										P.MatrixID = E.MatrixID		
									OR	(
											P.MatrixID IS NULL 
										AND E.MatrixID IS NULL	
										)	
									)	
								--
								AND P.RowNumber = E.ColumnNumber 
								--	
				--
				GROUP BY	E.MatrixID	
				,			E.RowNumber		
				--
				;	
				
			--
			--	// 2019-07-23	
			--	

	--
	--
	
		UPDATE		SC
		--	
		SET			SC.LogLikelihood_Previous   =   X.Previous_LogLikelihood 
		--	
		FROM		@t_StoppingCriteria		SC		
		INNER JOIN	(
						SELECT	A.MatrixID	
						--	
						,		SUM( B.[Value] * LOG( A.SigmaThetaX ) 
								   + ( convert(float,1.00) - B.[Value] ) * LOG( convert(float,1.00) - A.SigmaThetaX ) )
							as	Previous_LogLikelihood	
						--	
						FROM	@t_IntermediaryCalculation_PreviousGuessStandardLogisticFunction  
																A	
						--
						INNER JOIN	@t_RowVectors_Dependent		B	ON	(
																			A.MatrixID = B.MatrixID		
																		OR	(
																				A.MatrixID IS NULL 
																			AND B.MatrixID IS NULL	
																			)	
																		)	
																	--
																	AND A.RowNumber = B.RowNumber	
																	--	
						--
						INNER JOIN	@t_RowVectors_Explanatory	C	ON	(
																			A.MatrixID = C.MatrixID		
																		OR	(
																				A.MatrixID IS NULL 
																			AND C.MatrixID IS NULL	
																			)	
																		)	
																	--
																	AND A.RowNumber = C.RowNumber	
																	--	
						--
						GROUP BY	A.MatrixID	
						--	
						,			C.ColumnNumber	
						--	
					)	
						X	ON	SC.MatrixID = X.MatrixID 
							OR	(
									SC.MatrixID IS NULL 
								AND X.MatrixID IS NULL	
								)	
		--
		WHERE		SC.IsStopped = 0 
		--
		;
		
		UPDATE		SC
		--	
		SET			SC.LogLikelihood_Current   =   X.Current_LogLikelihood 
		--	
		FROM		@t_StoppingCriteria		SC		
		INNER JOIN	(
						SELECT	A.MatrixID	
						--	
						,		SUM( B.[Value] * LOG( A.SigmaThetaX ) 
								   + ( convert(float,1.00) - B.[Value] ) * LOG( convert(float,1.00) - A.SigmaThetaX )  )
							as	Current_LogLikelihood	
						--	
						FROM	@t_IntermediaryCalculation_NextGuessStandardLogisticFunction  
																A	
						--
						INNER JOIN	@t_RowVectors_Dependent		B	ON	(
																			A.MatrixID = B.MatrixID		
																		OR	(
																				A.MatrixID IS NULL 
																			AND B.MatrixID IS NULL	
																			)	
																		)	
																	--
																	AND A.RowNumber = B.RowNumber	
																	--	
						--
						INNER JOIN	@t_RowVectors_Explanatory	C	ON	(
																			A.MatrixID = C.MatrixID		
																		OR	(
																				A.MatrixID IS NULL 
																			AND C.MatrixID IS NULL	
																			)	
																		)	
																	--
																	AND A.RowNumber = C.RowNumber	
																	--	
						--
						GROUP BY	A.MatrixID	
						--	
						,			C.ColumnNumber	
						--	
					)	
						X	ON	SC.MatrixID = X.MatrixID 
							OR	(
									SC.MatrixID IS NULL 
								AND X.MatrixID IS NULL	
								)	
		--
		WHERE		SC.IsStopped = 0 
		--
		;
		
		UPDATE		SC
		--	
		SET			SC.LogLikelihoodImprovement	 =  SC.LogLikelihood_Current - SC.LogLikelihood_Previous  
		--	
		FROM		@t_StoppingCriteria		SC		
		--
		WHERE		SC.IsStopped = 0 
		--
		;

	/*	--
		--	2019-07-23 :: old code replaced by 3 separate UPDATE steps above 
		--	

		UPDATE		SC
		--	
		SET			SC.LogLikelihood_Previous		=	X.Previous_LogLikelihood 
		,			SC.LogLikelihood_Current		=	X.Current_LogLikelihood 
		--
		,			SC.LogLikelihoodImprovement		=	X.Current_LogLikelihood - X.Previous_LogLikelihood 
		--	
		FROM		@t_StoppingCriteria						SC		
		INNER JOIN	(
						SELECT	A.MatrixID	
						--	
						,		SUM( CASE WHEN A.PreviousOrCurrent = 'Previous'		
										  THEN B.[Value] * LOG( A.SigmaThetaX ) 
											+ ( convert(float,1.00) - B.[Value] ) * LOG( convert(float,1.00) - A.SigmaThetaX ) 
										  ELSE  0.00 
									 END )					as	Previous_LogLikelihood	
						,		SUM( CASE WHEN A.PreviousOrCurrent = 'Current'		
										  THEN B.[Value] * LOG( A.SigmaThetaX ) 
											+ ( convert(float,1.00) - B.[Value] ) * LOG( convert(float,1.00) - A.SigmaThetaX ) 
										  ELSE  0.00 
									 END )					as	Current_LogLikelihood	
						--	
						FROM	(
									SELECT	'Previous' as PreviousOrCurrent		
									--
									,		P.MatrixID 
									,		P.RowNumber		
									--
									,		P.SigmaThetaX 
									--
									FROM	@t_IntermediaryCalculation_PreviousGuessStandardLogisticFunction  P 

									UNION ALL	

									SELECT	'Current' as PreviousOrCurrent		
									--
									,		N.MatrixID 
									,		N.RowNumber		
									--
									,		N.SigmaThetaX 
									--
									FROM	@t_IntermediaryCalculation_NextGuessStandardLogisticFunction  N 

								/*	--
									--	2019-07-23 :: old code replaced by above intermediary tables	
									-- 
									SELECT		P.PreviousOrCurrent 
									--	
									,			E.MatrixID	
									,			E.RowNumber		
									--
									--,			math.fcn_StandardLogisticFunction 
									--			( 
									--				SUM( E.[Value] * P.[Value] )	
									--			)	
									--  2019-07-23 :: replace fcn_ with explicit expression, hopefully for speed gain 
									,			convert(float,1.000) 
											/ ( convert(float,1.000) + EXP( -SUM( E.[Value] * P.[Value] ) ) ) 
													as	SigmaThetaX		
									--
									FROM		(
													SELECT	'Previous'	as  PreviousOrCurrent		
													--	
													,		Px.*		
													--	
													FROM	@t_NewtonMethod_ColumnVector_PreviousGuess	Px	

													UNION ALL	

													SELECT	'Current'	as  VersionType		
													--	
													,		Py.*		
													--	
													FROM	@t_NewtonMethod_ColumnVector_NextGuess	Py	
												)	
																			P	
									INNER JOIN	@t_RowVectors_Explanatory	E 
													--	
													ON	(
															P.MatrixID = E.MatrixID		
														OR	(
																P.MatrixID IS NULL 
															AND E.MatrixID IS NULL	
															)	
														)	
													--
													AND P.RowNumber = E.ColumnNumber 
													--	
									--
									GROUP BY	P.PreviousOrCurrent		
									--	
									,			E.MatrixID	
									,			E.RowNumber		
									--
								*/	
								)	
									A	
						--
						INNER JOIN	@t_RowVectors_Dependent		B	ON	(
																			A.MatrixID = B.MatrixID		
																		OR	(
																				A.MatrixID IS NULL 
																			AND B.MatrixID IS NULL	
																			)	
																		)	
																	--
																	AND A.RowNumber = B.RowNumber	
																	--	
						--
						INNER JOIN	@t_RowVectors_Explanatory	C	ON	(
																			A.MatrixID = C.MatrixID		
																		OR	(
																				A.MatrixID IS NULL 
																			AND C.MatrixID IS NULL	
																			)	
																		)	
																	--
																	AND A.RowNumber = C.RowNumber	
																	--	
						--
						GROUP BY	A.MatrixID	
						--	
						,			C.ColumnNumber	
						--	
					)	
						X	ON	SC.MatrixID = X.MatrixID 
							OR	(
									SC.MatrixID IS NULL 
								AND X.MatrixID IS NULL	
								)	
		--
		WHERE		SC.IsStopped = 0 
		--
		;	

	*/	

	--
	--
	
		UPDATE		SC
		--	
		SET			SC.DistanceBetweenGuesses =	X.DistanceBetweenGuesses 
		--	
		FROM		@t_StoppingCriteria		SC		
		INNER JOIN	(	
						SELECT		P.MatrixID	
						--
						,			SQRT( SUM(   ( P.[Value] - N.[Value] ) 
											   * ( P.[Value] - N.[Value] ) 
											 ) 
										)			as	DistanceBetweenGuesses	
						--	
						FROM		@t_NewtonMethod_ColumnVector_PreviousGuess	P	
						INNER JOIN	@t_NewtonMethod_ColumnVector_NextGuess		N	
										--
										ON	(
												P.MatrixID = N.MatrixID		
											OR	(
													P.MatrixID IS NULL 
												AND N.MatrixID IS NULL	
												)	
											)	
										--
										AND P.RowNumber = N.RowNumber	
										--	
						GROUP BY	P.MatrixID	
					)	
						X	ON	SC.MatrixID = X.MatrixID	
							OR	(
									SC.MatrixID IS NULL 
								AND X.MatrixID IS NULL	
								)	
		--
		WHERE		SC.IsStopped = 0 
		--
		;	

	--
	--

		UPDATE	SC	
		--	
		SET		SC.IsStopped = 1 
		--	
		FROM	@t_StoppingCriteria		SC	
		--	
		WHERE	SC.IsStopped = 0	
		--	
		AND		SC.LogLikelihoodImprovement >= 0.00 
		AND		SC.LogLikelihoodImprovement < @StoppingCriteria_Threshold_LogLikelihoodImprovement	
		--
		AND		SC.DistanceBetweenGuesses < @StoppingCriteria_Threshold_DistanceBetweenGuesses	
		--	
		;		

	--
	--

		--
		--	 Prepare for next iteration	
		--

		IF EXISTS ( SELECT	null	
					FROM	@t_StoppingCriteria		SC	
					WHERE	SC.IsStopped = 1 
					AND		SC.IterationNumber = @CurrentIteration )	
		BEGIN	

			DELETE		E	
			FROM		@t_RowVectors_Explanatory	E	
			--
			INNER JOIN	(
							SELECT	SC.MatrixID 	
							FROM	@t_StoppingCriteria		SC	
							WHERE	SC.IsStopped = 1 
							AND		SC.IterationNumber = @CurrentIteration 
						)	
							X	ON	E.MatrixID = X.MatrixID		
								OR	(
										E.MatrixID IS NULL	
									OR	X.MatrixID IS NULL	
									)	
			--	
			;		

			DELETE		D	
			FROM		@t_RowVectors_Dependent		D	
			--
			INNER JOIN	(
							SELECT	SC.MatrixID 	
							FROM	@t_StoppingCriteria		SC	
							WHERE	SC.IsStopped = 1 
							AND		SC.IterationNumber = @CurrentIteration 
						)	
							X	ON	D.MatrixID = X.MatrixID		
								OR	(
										D.MatrixID IS NULL	
									OR	X.MatrixID IS NULL	
									)	
			--	
			;		

			--
			--

			INSERT INTO @Output_Staging  
			(
				MatrixID		
			--					
			,	Result			
			--					
			,	RowNumber		
			,	ColumnNumber	
			,	[Value]			
			)	

				SELECT	G.MatrixID	
				--		
				,		'Coefficient Vector'	
				--
				,		G.RowNumber		
				,		G.ColumnNumber	
				,		G.[Value]	
				--	
				FROM	@t_NewtonMethod_ColumnVector_NextGuess	G	
				--
				INNER JOIN	(
								SELECT	SC.MatrixID 	
								FROM	@t_StoppingCriteria		SC	
								WHERE	SC.IsStopped = 1 
								AND		SC.IterationNumber = @CurrentIteration 
							)	
								X	ON	G.MatrixID = X.MatrixID		
									OR	(
											G.MatrixID IS NULL	
										OR	X.MatrixID IS NULL	
										)	
				--		
				;		

		END		

	--
	--

		DELETE FROM @t_NewtonMethod_LogLikelihood_Gradient ; 
		DELETE FROM @t_NewtonMethod_LogLikelihood_Hessian ; 

		DELETE FROM @t_NewtonMethod_LogLikelihood_HessianInverse ; 

		DELETE FROM @t_NewtonMethod_ColumnVector_NextStep ;		

		DELETE FROM @t_NewtonMethod_ColumnVector_PreviousGuess ; 

			INSERT INTO @t_NewtonMethod_ColumnVector_PreviousGuess	
			( MatrixID , RowNumber , ColumnNumber ,	[Value]	)	
			SELECT N.MatrixID , N.RowNumber , N.ColumnNumber , N.[Value]	
			FROM @t_NewtonMethod_ColumnVector_NextGuess N	
			--
			INNER JOIN	@t_StoppingCriteria	 SC  ON  N.MatrixID = SC.MatrixID	
												 OR	 ( 
														 N.MatrixID IS NULL 
													 AND SC.MatrixID IS NULL	
													 )	
			--
			WHERE	SC.IsStopped = 0	
			--
			;	

		DELETE FROM @t_NewtonMethod_ColumnVector_NextGuess ; 
		
		
			--
			--	2019-07-23 
			--	
			DELETE FROM @t_IntermediaryCalculation_PreviousGuessStandardLogisticFunction   
			DELETE FROM	@t_IntermediaryCalculation_NextGuessStandardLogisticFunction   
			--
			--  // 2019-07-23	
			--


		--
		--	

		SET @CurrentIteration += 1 ;	

		--
		--

/**/END		--	END of Newton's Method "WHILE" loop			

	--
	--
	--
	--
	--
	--

	IF @Normalize = 1 
	BEGIN	

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Apply reverse normalization scaling on result vectors.' ) END ; 
	
			UPDATE		X	
			--	
			SET			X.[Value] = X.[Value] / S.StandardDeviation + S.Mean 
			--	
			FROM		@Output_Staging		X	
			INNER JOIN	@t_Scaler			S	ON	(
														X.MatrixID = S.MatrixID 
													OR	(
															X.MatrixID IS NULL 
														AND S.MatrixID IS NULL	
														)	
													)	
												--	
												AND X.RowNumber = S.ColumnNumber	
												--	
			--
			WHERE	X.Result = 'Coefficient Vector'	
			--
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END		

	--
	--
	--
	--
	--
	-- 

		--IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Summarize results for output.' ) END ; 
		
			
		--SET @RowCount = @@ROWCOUNT 
		--IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--

	IF @Mode = 'VIEW' 
	BEGIN 
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Display results.' ) END ; 
			
			SELECT		C.*
			FROM		@t_StoppingCriteria		C	
			--
			ORDER BY	C.MatrixID		ASC	
			--
			;

		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 
			
			SELECT		O.*
			FROM		@Output_Staging		O		
			--
			ORDER BY	O.MatrixID		ASC	
			,			O.RowNumber		ASC		
			--
			;

		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END		
	ELSE IF @Mode = 'TEMP' 
	BEGIN	

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Store results to input temporary table.' ) END ; 

		BEGIN TRY	

			INSERT INTO #result_usp_LogisticRegression 
			(
				MatrixID		 
			--				    
			,	Result			 
			--				    
			,	RowNumber		 
			,	ColumnNumber	 
			,	[Value]		
			--	
			)	

				SELECT	X.MatrixID		 
				--				    
				,		X.Result			 
				--					    
				,		X.RowNumber		 
				,		X.ColumnNumber	 
				,		X.[Value]			
				--	
				FROM		@Output_Staging	 X	
				--	
				ORDER BY	X.MatrixID 
				,			X.Result 
				,			X.RowNumber 
				,			X.ColumnNumber 
				--
				;		

		END TRY 
		BEGIN CATCH		
			SET @ErrorMessage = 'An error was encountered while attempting to populate results in provided temporary table.' 
			GOTO ERROR 
		END CATCH	

	END		

	--
	--
	--
	--
	--
	--

	--
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Logistic Regression complete.' ) END ; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Review sub-procedure messages.' ) END ; 
	--	

	FINISH:		

	--
	--DROP TABLE #rr 
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	RETURN 1 ; 

	--
	--
	
	--
	--IF OBJECT_ID('tempdb..#rr') IS NOT NULL DROP TABLE #rr 
	--
	
	ERROR:	

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END		

	RETURN -1 ; 

/****************************************************************
--	
-- Required input temporary table for @Mode = 'TEMP' :	
--	
	IF OBJECT_ID('tempdb..#result_usp_LogisticRegression') IS NOT NULL DROP TABLE #result_usp_LogisticRegression
	CREATE TABLE #result_usp_LogisticRegression
	(
		ID				int				not null	identity(1,1)	primary key		
	--
	,	MatrixID		int				null	
	--	
	,	Result			varchar(30)		not null	
	--	
	,	RowNumber		int				null	
	,	ColumnNumber	int				null	
	,	[Value]			float			not null	
	--	
	,	UNIQUE  (
					MatrixID
				--		
				,	Result	
				--	
				,	RowNumber	
				,	ColumnNumber	
				--		
				)
	) 
	--
	;	

	--
	--

			DECLARE	@Test_Explanatory AS math.UTT_MatrixCoordinate ; 
			DECLARE	@Test_Dependent AS math.UTT_MatrixCoordinate ; 

				--
				--	populate input matrices	, then execute procedure w/ @Mode = 'TEMP'	
				--	
			
				EXEC	math.usp_LogisticRegression		
							@Input_Matrix_Explanatory	=	@Test_Explanatory	
						,	@Input_Matrix_Dependent		=	@Test_Dependent		
						--
						,	@Normalize	 =	0	
						--
						,	@Mode		 =  'TEMP'	
						--
						,	@DEBUG		 =	1		
						-- 
				--	
				;			
				
		--
		--
			
		SELECT		X.*		
		--	
		FROM		#result_usp_LogisticRegression	X	
		--	
		ORDER BY	X.ID	ASC		
		--
		;	

--
--
--	
****************************************************************/	

END 
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Performs logistic regression on an input data-set' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'PROCEDURE',@level1name=N'usp_LogisticRegression'
--GO

--
--

CREATE PROCEDURE [math].[usp_PrincipalComponentAnalysis]  	
--	
	@RowVectors		math.UTT_MatrixCoordinate		READONLY	
--
,	@Normalize		bit				=	1		
--
,	@Mode			varchar(4)		=	'VIEW'		--	'VIEW' , 'TEMP'		
--
,	@DEBUG			bit				=	0		
--	
AS
/**************************************************************************************

	Performs a Principal Component Analysis for a provided set of row vectors:
		- computes the covariance matrix
		- finds an orthonormal basis of eigenvectors for the covariance matrix
		- returns eigenvectors with associated eigenvalues in descending order


		Example:	

			--
			--
			
			DECLARE	@Test_RowVectors AS math.UTT_MatrixCoordinate ; 

			INSERT INTO @Test_RowVectors 
			(	
				RowNumber
			,	ColumnNumber 
			,	Value 
			)	

				VALUES		( 1 , 1 , 1.00 )	,	( 1 , 2 , 1.00 )	,	( 1 , 3 , 1.08 )	
				,			( 2 , 1 , 1.01 )	,	( 2 , 2 , 1.02 )	,	( 2 , 3 , 1.07 )	
				,			( 3 , 1 , 1.02 )	,	( 3 , 2 , 0.80 )	,	( 3 , 3 , 1.06 )	
				,			( 4 , 1 , 2.05 )	,	( 4 , 2 , 1.50 )	,	( 4 , 3 , 1.05 )
				,			( 5 , 1 , 2.06 )	,	( 5 , 2 , 1.40 )	,	( 5 , 3 , 1.04 )
				,			( 6 , 1 , 2.07 )	,	( 6 , 2 , 1.70 )	,	( 6 , 3 , 1.03 )
				,			( 7 , 1 , 3.00 )	,	( 7 , 2 , 2.10 )	,	( 7 , 3 , 1.02 )
				,			( 8 , 1 , 3.01 )	,	( 8 , 2 , 2.05 )	,	( 8 , 3 , 1.01 )	
				--	
				;	

			--
			--
			
				EXEC	math.usp_PrincipalComponentAnalysis
							@RowVectors  =	@Test_RowVectors 
						--
						,	@Normalize	 =	0	
						--
						,	@Mode		 =  'VIEW'	
						--
						,	@DEBUG		 =	1		
						-- 
				--	
				;			

			--
			--

	Date			Action	
	----------		----------------------------
	2018-11-10		Created initial version.	
	2018-11-19		Finished @Mode = 'TEMP' and adjusted output result format. 
	2019-04-05		Scale covariance matrix by average coordinate value (or one tenth of maximum if average is zero). 

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	--
	--

	DECLARE		@ErrorMessage				varchar(500)	
	,			@RowCount					int			
	-- 
	;
	
	--
	--

	DECLARE @t_Scaler TABLE 
	(
		ID						int		not null	identity(1,1)	primary key		 
	--
	,	MatrixID				int		null		
	,	ColumnNumber			int		not null		
	--
	,	Mean					float	not null 
	,	StandardDeviation		float	not null	
	--	
	,	UNIQUE	(
					MatrixID	
				,	ColumnNumber	
				)	
	--	
	)	
	--
	;	

	--
	--
	
		DECLARE @t_RowVectors_Scaled AS math.UTT_MatrixCoordinate ; 

		DECLARE @t_CovarianceMatrix AS math.UTT_MatrixCoordinate ; 

		DECLARE @Result_Eigendecomposition TABLE 
		(
			ID				int				not null	identity(1,1)	primary key		
		--
		,	MatrixID		int				null	
		--	
		,	Result			varchar(12)		not null	
		--	
		,	RowNumber		int				null	
		,	ColumnNumber	int				null	
		,	[Value]			float			not null	
		--	
		,	UNIQUE  (
						MatrixID
					--		
					,	Result	
					--	
					,	RowNumber	
					,	ColumnNumber	
					--		
					)
		)
		--
		;

	--
	--

		DECLARE @Output_Staging TABLE 
		(
			ID				int				not null	identity(1,1)	primary key		
		--
		,	MatrixID		int				null	
		--	
		,	Result			varchar(30)		not null	
		--	
		,	RowNumber		int				null	
		,	ColumnNumber	int				null	
		,	[Value]			float			not null	
		--	
		,	UNIQUE  (
						MatrixID
					--		
					,	Result	
					--	
					,	RowNumber	
					,	ColumnNumber	
					--		
					)
		)	
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

		IF @Mode IS NULL 
		BEGIN 
			SET @Mode = 'VIEW' ; 
		END		
		IF @Mode NOT IN ( 'VIEW' , 'TEMP' )		
		BEGIN 
			SET @ErrorMessage = 'The provided @Mode value is unexpected. Acceptable values are ''VIEW'' or ''TEMP''.'	 
			GOTO ERROR 
		END		

	--
	--

		IF @Normalize IS NULL 
		BEGIN 
			SET @Normalize = 1 ; 
		END 

	--
	--

		IF @Mode = 'TEMP' 
		BEGIN 

			IF OBJECT_ID('tempdb..#result_usp_PrincipalComponentAnalysis') IS NULL 
			BEGIN 
				SET @ErrorMessage = 'For @Mode = ''TEMP'', a temporary table called #result_usp_PrincipalComponentAnalysis must exist. Check bottom of procedure definition.' 
				GOTO ERROR 
			END		

			IF EXISTS ( SELECT	null 
						FROM	#result_usp_PrincipalComponentAnalysis )	
			BEGIN 
				SET @ErrorMessage = 'Input temporary table (#result_usp_PrincipalComponentAnalysis) must be empty.' 
				GOTO ERROR 
			END		

			BEGIN TRY 

				INSERT INTO #result_usp_PrincipalComponentAnalysis
				(
					MatrixID		
				--					
				,	Result			
				--					
				,	RowNumber		
				,	ColumnNumber	
				,	[Value]			
				--
				) 
					SELECT	X.MatrixID		
					--					
					,		X.Result			
					--					
					,		X.RowNumber		
					,		X.ColumnNumber	
					,		X.[Value]			
					--
					FROM	( 
								VALUES	(   777		
										--					
										,	'Loading Vector' 			
										--			
										,	777		
										,	777	
										,	7.77	 
										--	
										)		 
							)	
								X	(   MatrixID		
									--					
									,	Result			
									--			
									,	RowNumber		
									,	ColumnNumber	
									,	[Value]	 
									--	
									)	
					--
					WHERE	1 = 0 ; 
					--	
					;	

			END TRY 
			BEGIN CATCH 
				SET @ErrorMessage = 'Check format of input temporary table (#result_usp_PrincipalComponentAnalysis).' 
				GOTO ERROR 
			END CATCH	

		END		

	--
	--

		--
		--	check matrices	
		--	

		IF ( SELECT coalesce( math.fcn_Matrix_IntegrityCheck ( @RowVectors , 0 , 0 ) , 0 ) ) = 0  
		BEGIN 
			SET @ErrorMessage = 'Matrix integrity check failed for input @RowVectors.' 
			GOTO ERROR 
		END 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'All checks passed successfully.' ) END ; 
	
	--
	--
	
	IF @Normalize = 1 
	BEGIN	

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Scale row vectors.' ) END ; 
	
			INSERT INTO @t_Scaler	
			(
				MatrixID 
			,	ColumnNumber 
			--
			,	Mean 
			,	StandardDeviation 
			--	
			)	

				SELECT		X.MatrixID 
				,			X.ColumnNumber 
				--
				,			AVG( X.[Value] )		--	Mean				
				,			STDEVP( X.[Value] )		--	StandardDeviation	
				--	
				FROM		@RowVectors	  X  
				--	
				GROUP BY	X.MatrixID 
				,			X.ColumnNumber 
				--
				;	
		
	END		

	--
	--

	INSERT INTO @t_RowVectors_Scaled 
	(
		MatrixID	
	,	RowNumber 
	,	ColumnNumber 
	,	[Value] 
	)	

		SELECT	 X.MatrixID	
		,		 X.RowNumber 
		,		 X.ColumnNumber 
		--
		,		 ( X.[Value] - coalesce(S.Mean,convert(float,0.00)) ) 
				 / CASE WHEN S.StandardDeviation <= convert(float,0.00)			
						OR	 S.StandardDeviation IS NULL 
						THEN convert(float,1.00) 
						ELSE coalesce(S.StandardDeviation,convert(float,1.00))	
				   END 
				 -- Value 
		--			
		FROM		@RowVectors		X		
		LEFT  JOIN	@t_Scaler		S	ON	(
												X.MatrixID = S.MatrixID 
											OR	(
													X.MatrixID IS NULL	
												AND S.MatrixID IS NULL	
												)	
											)
										--
										AND	X.ColumnNumber = S.ColumnNumber 
										--
		--
		;	

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Compute covariance matrix for each set of row vectors.' ) END ; 
	
		INSERT INTO @t_CovarianceMatrix			 
		(
			MatrixID 
		--
		,	RowNumber	
		,	ColumnNumber	
		--
		,	[Value]		
		--	
		)	

			SELECT	X.MatrixID 
			--	
			,		X.RowNumber 
			,		X.ColumnNumber	
			--
			,		X.[Value]		
			--	
			FROM	math.fcn_CovarianceMatrix ( @t_RowVectors_Scaled )	X	 	
			--
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

		--
		-- 

		--
		--	2019-04-05	
		--	
	
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Scale covariance matrix to try to improve numerical stability and avoid extreme small/large values.' ) END ; 
	
			UPDATE		M	
			SET			M.[Value] = M.[Value] / convert(float,S.ScalingValue)	
			FROM		@t_CovarianceMatrix			M	
			INNER JOIN	(
							SELECT		Ms.MatrixID		
							--
							,	CASE WHEN AVG(ABS(Ms.[Value])) > 0.001	
									 THEN AVG(ABS(Ms.[Value])) 
									 ELSE MAX(ABS(Ms.[Value]))/convert(float,10.00) 
								END		
									as	ScalingValue		
							--
							FROM		@t_CovarianceMatrix	 Ms		
							GROUP BY	Ms.MatrixID		
							--	
							HAVING		AVG(ABS(Ms.[Value])) > 0.001
							OR			MAX(ABS(Ms.[Value]))/convert(float,10.00) > 0.001	
							--	
						)	
							 S	ON	M.MatrixID = S.MatrixID		
								OR  (
										M.MatrixID IS NULL 
									AND S.MatrixID IS NULL	
									)	
			--
			WHERE	convert(float,S.ScalingValue) > 0.001	
			--
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

		--
		--	// 2019-04-05	
		--	

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Perform eigendecomposition on each covariance matrix.' ) END ; 
	
		INSERT INTO @Result_Eigendecomposition 			 
		(
			MatrixID			
		--						
		,	Result				
		--						
		,	RowNumber			
		,	ColumnNumber		
		,	[Value]				
		--						
		)	

			SELECT	X.MatrixID			
			--						
			,		X.Result				
			--						
			,		X.RowNumber			
			,		X.ColumnNumber		
			,		X.[Value]				
			--	
			FROM	math.fcn_Matrix_Eigendecomposition ( @t_CovarianceMatrix ) X	 	
			--
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--

	IF @Normalize = 1 
	BEGIN	

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Apply reverse normalization scaling on result vectors.' ) END ; 
	
			UPDATE		X	
			--	
			SET			X.[Value] = X.[Value] * S.StandardDeviation + S.Mean 
			--	
			FROM		@Result_Eigendecomposition	X	
			INNER JOIN	@t_Scaler					S	ON	(
																X.MatrixID = S.MatrixID 
															OR	(
																	X.MatrixID IS NULL 
																AND S.MatrixID IS NULL	
																)	
															)	
														AND X.RowNumber = S.ColumnNumber
			--
			WHERE		X.Result = 'Q Matrix'	
			--
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END		

	--
	--
	--
	--
	--
	-- 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Summarize results for output.' ) END ; 
	
			INSERT INTO @Output_Staging  
			(				    
				MatrixID		 
			--				    
			,	Result			 
			--				    
			,	RowNumber		 
			,	ColumnNumber	 
			,	[Value]				
			--	
			)	

				SELECT		E.MatrixID
				,			'Incremental Variance'		as	Result  
				,			E.RowNumber		
				,			null						as	ColumnNumber	
				,		 CASE WHEN SUM( E.[Value] ) OVER ( PARTITION BY E.MatrixID ) > 0.00 
							  THEN 
						 -- 
							E.[Value] 
						 /  SUM( E.[Value] ) OVER ( PARTITION BY E.MatrixID )	
						 -- 
							  ELSE null 
						 END		
									as	[Value]		 
				--	
				FROM		@Result_Eigendecomposition	E	
				--		
				WHERE		E.Result = 'Eigenvalue'		
				--
			
			-- 
			UNION ALL	
			--	

				SELECT		E.MatrixID
				,			'Loading Vector'		as	Result  
				,			E.ColumnNumber			as	RowNumber	
				,			E.RowNumber				as	ColumnNumber	
				,			E.[Value]				as	[Value]
				--	
				FROM		@Result_Eigendecomposition	E	
				--		
				WHERE		E.Result = 'Q Matrix'		
				--

			--
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--

	IF @Mode = 'VIEW' 
	BEGIN 
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Display results.' ) END ; 

			SELECT		X.MatrixID
			,			X.Result  
			,			X.RowNumber		
			,			X.ColumnNumber  
			,			X.[Value]	
			--	
			FROM		@Output_Staging		X	
			--	
			ORDER BY	X.MatrixID 
			,			X.Result 
			,			X.RowNumber 
			,			X.ColumnNumber 
			--	
			;	
			
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END		
	ELSE IF @Mode = 'TEMP' 
	BEGIN	

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Algorithm complete. Store results to input temporary table.' ) END ; 

		BEGIN TRY	

			INSERT INTO #result_usp_PrincipalComponentAnalysis 
			(
				MatrixID		 
			--				    
			,	Result			 
			--				    
			,	RowNumber		 
			,	ColumnNumber	 
			,	[Value]		
			--	
			)	

				SELECT	X.MatrixID		 
				--				    
				,		X.Result			 
				--					    
				,		X.RowNumber		 
				,		X.ColumnNumber	 
				,		X.[Value]			
				--	
				FROM		@Output_Staging	 X	
				--	
				ORDER BY	X.MatrixID 
				,			X.Result 
				,			X.RowNumber 
				,			X.ColumnNumber 
				--
				;		

		END TRY 
		BEGIN CATCH		
			SET @ErrorMessage = 'An error was encountered while attempting to populate results in provided temporary table.' 
			GOTO ERROR 
		END CATCH	

	END		

	--
	--
	--
	--
	--
	--

	--
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Principal Component Analysis complete.' ) END ; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Review sub-procedure messages.' ) END ; 
	--	

	FINISH:		

	--
	--DROP TABLE #rr 
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	RETURN 1 ; 

	--
	--
	
	--
	--IF OBJECT_ID('tempdb..#rr') IS NOT NULL DROP TABLE #rr 
	--
	
	ERROR:	

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END		

	RETURN -1 ; 

/****************************************************************
--	
-- Required input temporary table for @Mode = 'TEMP' :	
--	
	IF OBJECT_ID('tempdb..#result_usp_PrincipalComponentAnalysis') IS NOT NULL DROP TABLE #result_usp_PrincipalComponentAnalysis
	CREATE TABLE #result_usp_PrincipalComponentAnalysis
	(
		ID				int				not null	identity(1,1)	primary key		
	--
	,	MatrixID		int				null	
	--	
	,	Result			varchar(30)		not null	
	--	
	,	RowNumber		int				null	
	,	ColumnNumber	int				null	
	,	[Value]			float			not null	
	--	
	,	UNIQUE  (
					MatrixID
				--		
				,	Result	
				--	
				,	RowNumber	
				,	ColumnNumber	
				--		
				)
	) 
	--
	;	

	--
	--

			DECLARE	@Test_RowVectors AS math.UTT_MatrixCoordinate ; 

			INSERT INTO @Test_RowVectors 
			(	
				RowNumber
			,	ColumnNumber 
			,	Value 
			)	

				VALUES		( 1 , 1 , 1.00 )	,	( 1 , 2 , 1.00 )	,	( 1 , 3 , 1.08 )	
				,			( 2 , 1 , 1.01 )	,	( 2 , 2 , 1.02 )	,	( 2 , 3 , 1.07 )	
				,			( 3 , 1 , 1.02 )	,	( 3 , 2 , 0.80 )	,	( 3 , 3 , 1.06 )	
				,			( 4 , 1 , 2.05 )	,	( 4 , 2 , 1.50 )	,	( 4 , 3 , 1.05 )
				,			( 5 , 1 , 2.06 )	,	( 5 , 2 , 1.40 )	,	( 5 , 3 , 1.04 )
				,			( 6 , 1 , 2.07 )	,	( 6 , 2 , 1.70 )	,	( 6 , 3 , 1.03 )
				,			( 7 , 1 , 3.00 )	,	( 7 , 2 , 2.10 )	,	( 7 , 3 , 1.02 )
				,			( 8 , 1 , 3.01 )	,	( 8 , 2 , 2.05 )	,	( 8 , 3 , 1.01 )	
				--	
				;	

			--
			--
			
				EXEC	math.usp_PrincipalComponentAnalysis
							@RowVectors  =	@Test_RowVectors 
						--
						,	@Normalize	 =	1	
						--
						,	@Mode		 =  'TEMP'	
						--
						,	@DEBUG		 =	1		
						-- 
				--	
				;
				
			--
			--
			
		SELECT		X.*		
		--	
		FROM		#result_usp_PrincipalComponentAnalysis	X	
		--	
		ORDER BY	X.ID	ASC		
		--
		;	

--
--
--	
****************************************************************/	

END 
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Performs principal component analysis on an input data-set' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'PROCEDURE',@level1name=N'usp_PrincipalComponentAnalysis'
--GO

--
--

--
--
--
--

-- 
-- END FILE :: m003_StoredProcedures.sql 
-- 
