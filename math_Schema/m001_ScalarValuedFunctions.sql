--
-- BEGIN FILE :: m001_ScalarValuedFunctions.sql 
--

--
--
--
--
/***

  CONTENTS: 
  
  - create routines: 
    - fcn_GaussianError 
	- fcn_NormalCumulativeDistribution 
	- fcn_StandardLogisticFunction 
	- fcn_KernelFunction 
	- fcn_Matrix_IntegrityCheck 

***/

--
--

GO 

--
--

CREATE FUNCTION [math].[fcn_GaussianError]
(
	@Input		float
)
RETURNS float  
AS 
/**************************************************************************************

	Returns an approximate value for the Gaussian error function ("erf"), 
	 used in estimating cumulative normal distribution function values. 

		
	 Approximation used has a maximal error of 1.2*10^-7. 
	 

		Example:	

			SELECT	X.Input								InputValue	
			,		math.fcn_GaussianError( X.Input )	ErrorFunctionValue	
			FROM	(
						VALUES	( 0 ) 
						,		( -1 ) 
						,		( 1 ) 
					)
						X	( Input ) 	
			ORDER BY	X.Input		ASC		
			;	 


	Date			Action	
	----------		----------------------------
	2016-07-02		Created initial version.	

**************************************************************************************/	
BEGIN
	
	RETURN  (
				SELECT	CASE WHEN @Input IS NULL 
							 THEN NULL 
							 WHEN @Input = 0.000 
							 THEN 0 
							 WHEN @Input >= 0.000  
							 THEN convert(float,1.000) - Y.Tau 
							 ELSE Y.Tau - convert(float,1.000)	
						END		
					--	erf	
				FROM	
				(
					SELECT	X.T_Value * EXP( - @Input*@Input 
										     - 1.26551223 
										     + 1.00002368 * X.T_Value 
										     + 0.37409196 * X.T_Value * X.T_Value 
										     + 0.09678418 * X.T_Value * X.T_Value * X.T_Value 
										     - 0.18628806 * X.T_Value * X.T_Value * X.T_Value * X.T_Value 
										     + 0.27886807 * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value
										     - 1.13520398 * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value
										     + 1.48851587 * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value
										     - 0.82215223 * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value
										     + 0.17087277 * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value * X.T_Value )	
							as	Tau		
					FROM	(
								VALUES	( convert(float,1.0) 
										/ ( convert(float,1.0) + convert(float,0.5)*ABS(@Input) ) ) 	
							)	
								X	( T_Value )		
			   ) 
					Y	
			)
	; 

END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns approximate values of the Gaussian error function “erf” to a high degree of accuracy' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_GaussianError'
--GO

--
--
--
--

CREATE FUNCTION [math].[fcn_NormalCumulativeDistribution]
(
	@UpperBound				float	
,	@Mean					float	
,	@StandardDeviation		float	
)
RETURNS	float	 
AS 
/**************************************************************************************

	Returns an approximate value for the Gaussian Normal 
	 Cumulative Distribution Function evaluated at an input point, 
	  for a provided mean and standard deviation. 

		
		Example:	

			SELECT	X.Mean 
			,		X.StandardDeviation 
			,		X.UpperBound			
			,		math.fcn_NormalCumulativeDistribution(	X.UpperBound	
														 ,  X.Mean	
														 ,	X.StandardDeviation  )	 NormalCDFValue	
			FROM	(
						VALUES	(  0	,	0	,	1	) 
						,		(  -1	,	0	,	1	)
						,		(  1	,	0	,	1	)	
						--
						,		(  3	,	4	,	5	)	
						,		(  5	,	-1	,	19	)	
					)
						X	( UpperBound , Mean , StandardDeviation ) 	
			ORDER BY	X.Mean				ASC 
			,			X.StandardDeviation ASC		
			,			X.UpperBound		ASC		
			;	 


	Date			Action	
	----------		----------------------------
	2016-07-02		Created initial version.	

**************************************************************************************/	
BEGIN
	
	RETURN  (
				convert(float,0.500) 
			 *  ( 
					convert(float,1.000) 
				+	math.fcn_GaussianError( 
											  ( @UpperBound - @Mean ) 
											/ ( @StandardDeviation * POWER(convert(float,2.000),convert(float,0.500)) ) 	
										  )		
				)	
			)	
	;

END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns approximate values of the Gaussian normal cumulative distribution function for a provided input point (upper bound), mean, and standard deviation' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_NormalCumulativeDistribution'
--GO

--
--
--
--

CREATE FUNCTION [math].[fcn_StandardLogisticFunction]
(
	@Input		float
)
RETURNS float  
AS 
/**************************************************************************************

	Returns the value for the Standard Logistic Function ("sigmoid" function), 
	 at the provided input argument. 


		Example:	

			SELECT	X.Input											InputValue	
			,		math.fcn_StandardLogisticFunction ( X.Input )	LogisticFunctionValue	
			FROM	(
						VALUES	( 0 ) 
						--
						,		( -1 ) , ( -2 ) , ( -3 ) , ( -4 ) , ( -5 ) , ( -6 ) , ( -7 )	
						--
						,		( 1 ) , ( 2 ) , ( 3 ) , ( 4 ) , ( 5 ) , ( 6 ) , ( 7 )	
						--
					)
						X	( Input ) 	
			--
			ORDER BY	X.Input		ASC		
			--	
			;	 


	Date			Action	
	----------		----------------------------
	2019-01-29		Created initial version.	

**************************************************************************************/	
BEGIN
	
	RETURN  (
				SELECT	convert(float,1.00)		
					/ ( convert(float,1.00) 
					  + EXP( - @Input )	)		 
			)
	; 

END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns approximate values of the Standard Logistic Function ("sigmoid" function), for provided input arguments' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_StandardLogisticFunction'
--GO

--
--
--
--

CREATE FUNCTION [math].[fcn_KernelFunction]
(
	@InputValue						float			
,	@KernelFunction_ShortName		varchar(20)		
)
RETURNS float  
AS 
/**************************************************************************************

	Returns an approximate value for a provided Kernel function
		at a provided input point.	


		Example:	

			SELECT		X.ShortName													KernelFunction_ShortName	
			,			I.InputValue												InputValue	
			--	
			,			math.fcn_KernelFunction( I.InputValue ,	X.ShortName )		KernelFunctionValue			
			--	
			FROM		( VALUES ( 0.500 ) )	I	( InputValue )	
			CROSS APPLY math.KernelFunction		X	
			--	
			ORDER BY	X.ID ASC		
			--	
			;	 


	Date			Action	
	----------		----------------------------
	2017-08-28		Created initial version.	
	2018-01-25		Adjusted first two CASE criteria for NULL or zero output. 

**************************************************************************************/	
BEGIN
	
	RETURN	CASE WHEN @InputValue IS NULL 
				 OR	  @KernelFunction_ShortName IS NULL 
				 THEN NULL 
				 --		
				 WHEN (
						  @KernelFunction_ShortName != 'Uniform'
					  AND (
						     @InputValue >= 1.0000 
						  OR @InputValue <= -1.0000
						  ) 
					  )		
				 OR	  (
						  @KernelFunction_ShortName = 'Uniform'
					  AND (
						     @InputValue > 1.0000 
						  OR @InputValue < -1.0000
						  ) 
					  )		 
				 THEN convert(float,0.0)	
				 --
				 ELSE CASE @KernelFunction_ShortName 
						--	
						WHEN 'Uniform' 
						THEN convert(float,0.5000)	
						--	
						--	K(u) = 1/2 
						--	
						WHEN 'Triangular'
						THEN ( convert(float,1.0) - abs(@InputValue) )	
						--	
						--	K(u) = ( 1 - |u| ) 
						--	
						WHEN 'Parabolic' 
						THEN ( convert(float,3.0)/convert(float,4.0) ) 
				      	* ( convert(float,1.0) - @InputValue * @InputValue )	
						--	
						--	K(u) = (3/4)*( 1 - u^2 ) 
						--	
						WHEN 'Quartic' 
						THEN ( convert(float,15.0)/convert(float,16.0) ) 
				      	* ( convert(float,1.0) - @InputValue * @InputValue ) 
				      	* ( convert(float,1.0) - @InputValue * @InputValue )
						--	
						--	K(u) = (15/16)*( ( 1 - u^2 )^2 ) 
						--	
						WHEN 'Triweight'
						THEN ( convert(float,35.0)/convert(float,32.0) ) 
				      	* ( convert(float,1.0) - @InputValue * @InputValue ) 
				      	* ( convert(float,1.0) - @InputValue * @InputValue )
				      	* ( convert(float,1.0) - @InputValue * @InputValue )
						--	
						--	K(u) = (35/32)*( ( 1 - u^2 )^3 ) 
						--	
						WHEN 'Tricube'
						THEN ( convert(float,70.0)/convert(float,81.0) ) 
				      	* ( convert(float,1.0) - abs( @InputValue * @InputValue * @InputValue ) ) 
				      	* ( convert(float,1.0) - abs( @InputValue * @InputValue * @InputValue )	) 
				      	* ( convert(float,1.0) - abs( @InputValue * @InputValue * @InputValue )	) 
						--	
						--	K(u) = (70/81)*( ( 1 - |u|^3 )^3 ) 
						--	
						WHEN 'Cosine' 
						THEN COS( @InputValue * Pi() / convert(float,2.0) ) * ( Pi() / convert(float,4.0) )	
						--	
						--	K(u) = (Pi/4)*cos( u*(Pi/2) )  
						--	
						ELSE NULL	
						-- 
					  END	
			END			
	; 

END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Evaluates a provided kernel function at a provided input point' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_KernelFunction'
--GO

--
--
--
--

CREATE FUNCTION [math].[fcn_Matrix_IntegrityCheck] 	
(	
	@Input_Matrix	math.UTT_MatrixCoordinate	READONLY	
--	
,	@CheckForZeroRows		bit			=	0	
,	@CheckForZeroColumns	bit			=	0	
)	
RETURNS bit	
AS	
/**************************************************************************************

	Checks the integrity of the record configuration in an input table 
		of type math.UTT_MatrixCoordinate. 

		For each input matrix, 
			each row must have the same number of columns, 
			and there must not be any gaps in the RowNumber or ColumnNumber values. 

		Optional parameters also enable checks for 'zero' rows or columns. 

	
	A returned value of 0 means there is a problem with the input records. 
	A returned value of 1 means all integrity checks have passed successfully. 

	
		Example:	

				--
				--

				DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

					INSERT INTO @Test ( RowNumber , ColumnNumber , Value ) 
					VALUES	( 1 , 1 , 9 ) , ( 1 , 2 , 6 ) , ( 1 , 3 , 3 ) 
					,		( 2 , 1	, 8 ) , ( 2 , 2 , 5 ) , ( 2 , 3 , 2 ) 
					,		( 3 , 1 , 7 ) , ( 3 , 2 , 4 ) , ( 3 , 3 , 1 ) 
					; 

				SELECT math.fcn_Matrix_IntegrityCheck ( @Test , 0 , 0 )  as  Check1
				; 

					DELETE X FROM @Test X WHERE X.RowNumber = 1 AND X.ColumnNumber = 2 ; 
					
				SELECT math.fcn_Matrix_IntegrityCheck ( @Test , 0 , 0 )  as  Check2 
				; 

				--
				--

	Date			Action	
	----------		----------------------------
	2015-12-14		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--

	DECLARE @MatrixRowAndColumnCounts TABLE 
	(
		ID					int		not null	identity(1,1)	primary key 
	--
	,	MatrixID			int		null		unique	
	--
	,	NumberOfRows		int		not null	
	,	NumberOfColumns		int		not null	
	,	MinRow				int		not null	
	,	MaxRow				int		not null	
	,	MinColumn			int		not null	
	,	MaxColumn			int		not null	
	)	

	--
	--
		
		--
		--	Gather statistics on input matrix configuration.  
		--

	--
	--

		INSERT INTO @MatrixRowAndColumnCounts 
		(
			MatrixID 
		--
		,	NumberOfRows 
		,	NumberOfColumns 
		,	MinRow 
		,	MaxRow 
		,	MinColumn 
		,	MaxColumn 
		)	

			SELECT		I.MatrixID	 
			--
			,			COUNT(DISTINCT(I.RowNumber))	
			,			COUNT(DISTINCT(I.ColumnNumber))		
			,			MIN(I.RowNumber)	
			,			MAX(I.RowNumber)	
			,			MIN(I.ColumnNumber)		
			,			MAX(I.ColumnNumber)		
			--	
			FROM		@Input_Matrix	I	
			GROUP BY	I.MatrixID	
			--
			;	

	--
	--
	
		--
		--	Check integrity of input table configuration.  
		--

	--
	--

		--
		--	Check for unexpected RowNumber or ColumnNumber values.  
		--

		IF EXISTS ( SELECT		null	
					FROM		@MatrixRowAndColumnCounts	M	
					WHERE		M.MinRow != 1 
					OR			M.MinColumn != 1
					OR			M.MaxRow != M.NumberOfRows
					OR			M.MaxColumn != M.NumberOfColumns )	 
		BEGIN 
			
			RETURN 0 ; 
				
		END		

		--
		--	Check for rows with unexpected column count.  
		--

		IF EXISTS ( SELECT		null	
					FROM		(
									SELECT		M.MatrixID	
									,			M.RowNumber		
									,			COUNT(*)	ColumnCount			
									FROM		@Input_Matrix	M	
									GROUP BY	M.MatrixID	
									,			M.RowNumber		
								)						
									X	
					INNER JOIN	@MatrixRowAndColumnCounts	Y	ON	(
																		X.MatrixID = Y.MatrixID 
																	OR	(
																			X.MatrixID IS NULL 
																		AND Y.MatrixID IS NULL 
																		)	
																	)	
					WHERE		X.ColumnCount != Y.NumberOfColumns )	 
		BEGIN 

			RETURN 0 ; 

		END		

	--
	--

		IF @CheckForZeroRows = 1 
		BEGIN 
			
			--
			--	Check for zero rows.   
			--

			IF EXISTS ( SELECT		null	
						FROM		@Input_Matrix	M	
						GROUP BY	M.MatrixID	
						,			M.RowNumber 
						HAVING		MAX(ABS(M.Value)) = 0 ) 
			BEGIN 
				
				RETURN 0 ; 

			END		

		END		

	--
	--
	
		IF @CheckForZeroColumns = 1 
		BEGIN 
			
			--
			--	Check for zero columns.   
			--

			IF EXISTS ( SELECT		null	
						FROM		@Input_Matrix	M	
						GROUP BY	M.MatrixID	
						,			M.ColumnNumber 
						HAVING		MAX(ABS(M.Value)) = 0 ) 
			BEGIN 
				
				RETURN 0 ; 

			END		

		END		

	--
	--

		--
		--	Integrity checks complete. No issues found.   
		--

	--
	--

		RETURN 1 ; 
	
	--
	--

END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Checks the contents of a provided UTT_MatrixCoordinate table and ensures they adhere to an expected format' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Matrix_IntegrityCheck'
--GO

--
--
--
--

-- 
-- END FILE :: m001_ScalarValuedFunctions.sql 
-- 
