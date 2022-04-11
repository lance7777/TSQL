--
-- BEGIN FILE :: m002_TableValuedFunctions.sql 
--

--
--
--
--
/***

  CONTENTS: 
  
  - create routines: 
	- fcn_Matrix_Product   
	- fcn_Matrix_Transpose    
	- fcn_Matrix_QRFactorization   
	- fcn_Matrix_Determinant  
	- fcn_Matrix_Adjugate  
	- fcn_Matrix_Inverse   
	- fcn_Matrix_RowEchelonForm   
	- fcn_Matrix_Eigendecomposition   
    - fcn_CorrelationMatrix 
	- fcn_CovarianceMatrix 
	- fcn_LinearSystemSolution  
	- fcn_SimpleLinearRegression    
	- fcn_MultipleLinearRegression    
	- fcn_Interpolation_CubicSpline  
	- fcn_Interpolation_PiecewiseLinear  
	- fcn_InterpolationEvaluation  
	- fcn_InterpolationEvaluation_FastNaturalCubicSpline  
	- fcn_LocalPolynomialRegression  
	- fcn_PolynomialDerivative    
	- fcn_PolynomialEvaluation    
	- fcn_MinkowskiDistance    
 
***/

--
--

GO 

--
--


CREATE FUNCTION [math].[fcn_Matrix_Product]
(
	@Input_Matrix_LEFT   math.UTT_MatrixCoordinate  READONLY
,   @Input_Matrix_RIGHT  math.UTT_MatrixCoordinate  READONLY
) 
RETURNS 
@Output TABLE 
(
	MatrixID		int		 null	
--	
,	RowNumber		int		 not null	
,	ColumnNumber	int		 not null	
,	[Value]			float	 not null	
--	
UNIQUE  (
			MatrixID 
		--	
		,	RowNumber
		,	ColumnNumber	
		)
)	
AS 
/**************************************************************************************

	Returns the product(s) of pair(s) of input left and right matrices 
	 with matching MatrixID values. 
	 
		
		Example:	
		
			--
			--
			
		DECLARE	@Test_L AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test_L ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

			VALUES	( 2 , 1 , 1 , 5.4 )		,	( 2 , 1 , 2 , 7.2 )		
			,		( 2 , 2 , 1 , 3.1 )		,	( 2 , 2 , 2 , 6.9 )		
			--
			;	

		DECLARE @Test_R AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test_R ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

		SELECT	X.MatrixID , X.RowNumber , X.ColumnNumber , X.[Value] 
		FROM	math.fcn_Matrix_Adjugate ( @Test_L )	X	
		;	

		
			SELECT		X.MatrixID	
			,			X.RowNumber 
			,			X.ColumnNumber
			,			X.[Value] / CASE WHEN D.Determinant = 0 THEN convert(float,1.0) ELSE D.Determinant END 
			FROM		math.fcn_Matrix_Product ( @Test_L , @Test_R )	X	
			INNER JOIN	math.fcn_Matrix_Determinant ( @Test_L )			D	ON	X.MatrixID = D.MatrixID 
			ORDER BY	X.MatrixID	ASC		
			,			X.RowNumber ASC 
			,			X.ColumnNumber ASC 
			;	
			
			--
			--

	Date			Action	
	----------		----------------------------
	2016-05-15		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix_LEFT , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix_RIGHT , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

		--
		--	Check sizes of matrices are suited for multiplication 
		--	
	
		IF EXISTS ( SELECT		null 
					FROM		(
									SELECT		Ls.MatrixID 
									,			MAX(Ls.ColumnNumber)		MaxColumnNumber	 
									FROM		@Input_Matrix_LEFT	Ls	
									GROUP BY	Ls.MatrixID 
								)	
									L	
					INNER JOIN	(
									SELECT		Rs.MatrixID 
									,			MAX(Rs.RowNumber)		MaxRowNumber 
									FROM		@Input_Matrix_RIGHT	Rs	
									GROUP BY	Rs.MatrixID 
								)	
									R	ON	L.MatrixID = R.MatrixID 
										OR	(
												L.MatrixID IS NULL 
											AND R.MatrixID IS NULL 
											)	
					WHERE		L.MaxColumnNumber != R.MaxRowNumber ) 
		BEGIN 
			
			RETURN ; 

		END		

	--
	--	

		--
		--	Output product matrix 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		--
		,	[Value] 	
		)	

			SELECT		I.MatrixID 
			--
			,			I.RowNumber
			,			R.ColumnNumber  
			--
			,			SUM( I.[Value] * R.[Value] )
			--	
			FROM		@Input_Matrix_LEFT	 I	
			INNER JOIN	@Input_Matrix_RIGHT	 R	ON  (
														I.MatrixID = R.MatrixID 
													OR  (
															I.MatrixID IS NULL 
														AND R.MatrixID IS NULL 
														)		
													) 
												AND I.ColumnNumber = R.RowNumber 
			GROUP BY	I.MatrixID 
			--
			,			I.RowNumber 
			,			R.ColumnNumber 
			--	
			;	
	
	--
	--

	RETURN 
END
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the product of two input matrices' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Matrix_Product'
--GO

--
--

CREATE FUNCTION [math].[fcn_Matrix_Transpose]
(
	@Input_Matrix  math.UTT_MatrixCoordinate  READONLY
)	
RETURNS 
@Output TABLE 
(
	MatrixID		int		null	
--	
,	RowNumber		int		not null	
,	ColumnNumber	int		not null	
,	[Value]			float	not null	
--	
,	UNIQUE  (
			 	MatrixID		
		    --	
		    ,	RowNumber		
		    ,	ColumnNumber	
		    )
)	
AS 
/**************************************************************************************

	Returns the transpose of a provided matrix, 
	 or the transposes of a provided set of matrices. 
	 

		Example:	

			--
			--		
		
		DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

			VALUES	( 1 , 1 , 1 , 5.4 ) 
			--
			,		( 2 , 1 , 1 , 5.4 )		,	( 2 , 1 , 2 , 7.2 )		
			,		( 2 , 2 , 1 , 3.1 )		,	( 2 , 2 , 2 , 6.9 )		
			--	
			,		( 3 , 1 , 1 , 5.4 )		,	( 3 , 1 , 2 , 7.2 )		,	( 3 , 1 , 3 , 7.2 )	
			,		( 3 , 2 , 1 , 3.1 )		,	( 3 , 2 , 2 , 6.9 )		,	( 3 , 2 , 3 , 6.9 )
			,		( 3 , 3 , 1 , 4.8 )		,	( 3 , 3 , 2 , 2.7 )		,	( 3 , 3 , 3 , 1.8 )
			-- 
			;	

			SELECT		X.MatrixID	
			,			X.RowNumber 
			,			X.ColumnNumber
			,			X.[Value] 
			FROM		math.fcn_Matrix_Transpose ( @Test )	X	
			ORDER BY	X.MatrixID	ASC		
			,			X.RowNumber ASC 
			,			X.ColumnNumber ASC 
			;	
			
			--
			--

	Date			Action	
	----------		----------------------------
	2016-05-15		Created initial version.	
	
**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

	--
	--	

		--
		--	Output transpose matrix 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		--
		,	[Value] 	
		)	

			SELECT		I.MatrixID 
			--
			,			I.ColumnNumber
			,			I.RowNumber 
			--
			,			I.[Value] 
			--	
			FROM		@Input_Matrix		I		
			;	
	
	--
	--

	RETURN 
END
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the transpose of a provided matrix' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Matrix_Transpose'
--GO

--
--

CREATE FUNCTION [math].[fcn_Matrix_QRFactorization]
(
	@Input_Matrix  math.UTT_MatrixCoordinate  READONLY
)
RETURNS 
@Output TABLE 
(
	MatrixID		int				null	
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
AS 
/**************************************************************************************

	For an input square matrix A, returns square matrices Q and R of the same size 
	 such that:		A = QR 
			,		Q is orthogonal
			,  and  R is upper triangular	. 


		Uses Householder Reflectors to "upper-triangularize" each column 
		 of the input matrix from the left to the right. 

	
		
		Example:	

			--
			--	

		DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test ( RowNumber , ColumnNumber , Value ) 

			VALUES	( 1 , 1 , 1 )	,	( 1 , 2 , 1 )	,	( 1 , 3 ,  1 )	,	( 1 , 4 ,   1 )	,	( 1 , 5 ,   1 )	
			,		( 2 , 1 , 1 )	,	( 2 , 2 , 2 )	,	( 2 , 3 ,  4 )	,	( 2 , 4 ,   8 )	,	( 2 , 5 ,  16 )	
			,		( 3 , 1 , 1 )	,	( 3 , 2 , 3 )	,	( 3 , 3 ,  9 )	,	( 3 , 4 ,  27 )	,	( 3 , 5 ,  81 )	
			,		( 4 , 1 , 1 )	,	( 4 , 2 , 4 )	,	( 4 , 3 , 16 )	,	( 4 , 4 ,  64 )	,	( 4 , 5 , 256 )	
			,		( 5 , 1 , 1 )	,	( 5 , 2 , 5 )	,	( 5 , 3 , 25 )	,	( 5 , 4 , 125 )	,	( 5 , 5 , 625 )	
			-- 
			;	

			SELECT		X.Result					
			--								
			,			X.RowNumber			
			,			X.ColumnNumber		
			,			X.[Value]			
			--
			FROM		math.fcn_Matrix_QRFactorization	( @Test )	X	
			--
			ORDER BY	X.Result			ASC		
			,			X.ColumnNumber		ASC		
			,			X.RowNumber			ASC		
			--
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2018-06-18		Created initial version.	
	2019-01-28		Replaced POWER function usages with CASE statements and % (modulus operator). 
					Added threshold for computations which are unstable when some measure is near zero. 
	2019-01-29		Prevent incorrect determinants by keeping track of degenerate Householder reflections. 
	
**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

		--
		--	Check for any input matrices which are not 'square' 
		--	

		IF EXISTS ( SELECT		null 
					FROM		@Input_Matrix	X	
					GROUP BY	X.MatrixID 
					HAVING		MAX(X.RowNumber) != MAX(X.ColumnNumber) ) 
		BEGIN 

			RETURN ; 

		END 

	--
	--

		DECLARE		@ColumnIterator			int		=	 1	
		,			@NumberOfIterations		int		=	( SELECT MAX(RowNumber) FROM @Input_Matrix ) - 1 
		--
		,			@ValidationThreshold	float	=	0.000001	
		--
		,			@Trace_ZeroThreshold			float	=	0.0000000001	
		,			@SquaredNorm_ZeroThreshold		float	=	0.0000000001	
		--
		;	

	--
	--
	--	
	-- 
	
	DECLARE	@working_Z AS math.UTT_MatrixCoordinate ; 
	DECLARE	@working_V AS math.UTT_MatrixCoordinate ; 
	DECLARE	@working_H AS math.UTT_MatrixCoordinate ; 
	--	
	DECLARE @running_Q AS math.UTT_MatrixCoordinate ; 
	DECLARE	@running_R AS math.UTT_MatrixCoordinate ; 
	--	
	;	

	DECLARE @transpose_Q AS math.UTT_MatrixCoordinate ; 
	--
	;	
	
	DECLARE @t_Reflections TABLE 
	(
		ID						int		not null	identity(1,1)	primary key		
	--
	,	MatrixID				int		null		unique	
	--
	,	NumberOfReflections		int		not null	
	--
	)	

	DECLARE @t_Validation TABLE 
	(
		ID					int		not null	identity(1,1)	primary key		
	--
	,	MatrixID			int		null		unique	
	--
	,	Q_IsOrthogonal		bit		not null	
	,	QR_EqualsInput		bit		null		
	--
	,	Q_Determinant		float	null	
	--	
	) 
	--
	;	
		
	--
	--

	INSERT INTO @running_R 
	(
		MatrixID	
	,	RowNumber	
	,	ColumnNumber 
	,	[Value]		
	)	
		
		SELECT	A.MatrixID	
		,		A.RowNumber	
		,		A.ColumnNumber 
		,		A.[Value]		
		--	
		FROM	@Input_Matrix	A	
		--
		;	

	INSERT INTO @running_Q 
	(
		MatrixID 
	,	RowNumber 
	,	ColumnNumber	
	,	[Value]		
	)	

		SELECT	H.MatrixID 
		,		H.RowNumber 
		,		H.ColumnNumber	
		,		CASE WHEN H.RowNumber = H.ColumnNumber	
					 THEN convert(float,1.000)	
					 ELSE convert(float,0.000)	
				END	
		FROM	@Input_Matrix	H	
		--
		;	

	--
	--

	INSERT INTO @t_Reflections ( MatrixID , NumberOfReflections ) SELECT distinct X.MatrixID , 0 FROM @running_Q as X ; 

	--
	--

		WHILE @ColumnIterator <= @NumberOfIterations 
		BEGIN	

			--
			--	Find Householder Reflector for current 'truncated column'	
			--	

			INSERT INTO @working_Z 
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber	
			,	[Value]		
			)	

			SELECT	X.MatrixID	
			,		X.RowNumber - ( @ColumnIterator - 1 )	
			,		1 
			,		X.[Value] 
			--	
			FROM	@running_R	X	
			WHERE	X.ColumnNumber = @ColumnIterator 
			AND		X.RowNumber >= @ColumnIterator 
			--
			;	
		
			INSERT INTO @working_V  
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber	
			,	[Value]		
			)	

			SELECT	Z.MatrixID	
			,		Z.RowNumber 
			,		1 
			,		CASE WHEN Z.RowNumber = 1
						 THEN N.Norm 
						 ELSE convert(float,0.000)	
					END	- Z.[Value] 
			--	
			FROM		@working_Z	Z		
			INNER JOIN	(
							SELECT		Zs.MatrixID	
							,			CASE WHEN SUM( Zs.[Value] * Zs.[Value] ) <= @SquaredNorm_ZeroThreshold 
											 THEN 0.000 
											 ELSE SQRT(	SUM( Zs.[Value] * Zs.[Value] ) )
										END		as 	Norm		
							FROM		@working_Z	Zs	
							GROUP BY	Zs.MatrixID		
							--
							HAVING		COUNT(*) > 1	-- don't run the final column 
							--
						)	
							N	ON	Z.MatrixID = N.MatrixID		
								OR	(
										Z.MatrixID IS NULL 
									AND N.MatrixID IS NULL	
									)	
			--
			;	
		
			--
			--

				--
				--	scale V		
				--	

				UPDATE		V	
				SET			V.[Value] = CASE WHEN N.SquaredNorm > @SquaredNorm_ZeroThreshold
											 THEN V.[Value] / SQRT( N.SquaredNorm )	
											 ELSE V.[Value] 
										END		
				--	
				FROM		@working_V	 V	
				INNER JOIN	(
								SELECT		Vs.MatrixID	
								,			convert(float,
												SUM( Vs.[Value] * Vs.[Value] )	
											)	as	SquaredNorm		
								FROM		@working_V	Vs	
								GROUP BY	Vs.MatrixID		
								--	
								HAVING		SUM( Vs.[Value] * Vs.[Value] ) > @SquaredNorm_ZeroThreshold
								--	
							)	
								N	ON	V.MatrixID = N.MatrixID		
									OR	(
											V.MatrixID IS NULL 
										AND N.MatrixID IS NULL	
										)	
				--
				;		

			--
			--

				UPDATE		R	
				--	
				SET			R.NumberOfReflections += 1 
				--	
				FROM		@t_Reflections	R	
				INNER JOIN	(
								SELECT		X.MatrixID 
								FROM		@working_V	X	
								GROUP BY	X.MatrixID 
								HAVING		SUM( X.[Value] * X.[Value] ) > @SquaredNorm_ZeroThreshold 
							) 
								Q	ON	R.MatrixID = Q.MatrixID		
									OR	(
											R.MatrixID IS NULL 
										AND Q.MatrixID IS NULL	
										)	
				--	
				;	 

			--
			--	

			INSERT INTO @working_H	
			(
				MatrixID 
			,	RowNumber 
			,	ColumnNumber	
			,	[Value]		
			)	
				--
				--	H := I - 2*v*v^T		
				--	
			SELECT		L.MatrixID	
			,			L.RowNumber 
			,			R.RowNumber 
			,			CASE WHEN L.RowNumber = R.RowNumber 
							 THEN convert(float,1.000)	
							 ELSE convert(float,0.000) 
						END - convert(float,2.000) * L.[Value] * R.[Value] 
			--	
			FROM		@working_V	L	
			INNER JOIN	@working_V	R	ON	L.MatrixID = R.MatrixID 
										OR	(
												L.MatrixID IS NULL 
											AND R.MatrixID IS NULL	
											)	
			--	
			;	

			--
			--
			
			--
			--	Apply current iteration Householder Reflector to running "Q" matrix 	
			--	

				UPDATE		Q	
				SET			Q.[Value] = P.NewValue 
				--	
				FROM		@running_Q		Q	
				INNER JOIN	(
								SELECT		Hs.MatrixID		
								--
								,			Hs.RowNumber + ( @ColumnIterator - 1 ) 		as	RowNumber	
								,			Qs.ColumnNumber 
								--
								,			SUM( Hs.[Value] * Qs.[Value] )				as	NewValue	
								--	
								FROM		@working_H	Hs	
								INNER JOIN	@running_Q	Qs	ON	(
																	Hs.MatrixID = Qs.MatrixID	
																OR	(
																		Hs.MatrixID IS NULL 
																	AND Qs.MatrixID IS NULL		
																	)	
																)	
															--
															AND	Hs.ColumnNumber + ( @ColumnIterator - 1 ) = Qs.RowNumber 
															--
								--	
								GROUP BY	Hs.MatrixID		
								--
								,			Hs.RowNumber	
								,			Qs.ColumnNumber 
								--	
							)	
								P	ON	(
											Q.MatrixID = P.MatrixID 
										OR	(
												Q.MatrixID IS NULL 
											AND P.MatrixID IS NULL 
											)	
										)	
									--
									AND Q.RowNumber = P.RowNumber 
									AND Q.ColumnNumber = P.ColumnNumber 
									--
				--
				;	

			--
			--
			
			--
			--	Apply current iteration Householder Reflector to running "R" matrix 	
			--	

				UPDATE		R	
				SET			R.[Value] = P.NewValue 
				--	
				FROM		@running_R		R	
				INNER JOIN	(
								SELECT		Hs.MatrixID		
								--
								,			Hs.RowNumber + ( @ColumnIterator - 1 ) 		as	RowNumber	
								,			Rs.ColumnNumber 
								--
								,			SUM( Hs.[Value] * Rs.[Value] )				as	NewValue	
								--	
								FROM		@working_H	Hs	
								INNER JOIN	@running_R	Rs	ON	(
																	Hs.MatrixID = Rs.MatrixID	
																OR	(
																		Hs.MatrixID IS NULL 
																	AND Rs.MatrixID IS NULL		
																	)	
																)	
															--
															AND	Hs.ColumnNumber + ( @ColumnIterator - 1 ) = Rs.RowNumber 
															--
								--	
								GROUP BY	Hs.MatrixID		
								--
								,			Hs.RowNumber	
								,			Rs.ColumnNumber 
								--	
							)	
								P	ON	(
											R.MatrixID = P.MatrixID 
										OR	(
												R.MatrixID IS NULL 
											AND P.MatrixID IS NULL 
											)	
										)	
									--
									AND R.RowNumber = P.RowNumber 
									AND R.ColumnNumber = P.ColumnNumber 
									--
				--
				;		

		--
		--
			
			--
			--	Prepare for next iteration 
			--	
			DELETE FROM @working_Z ; 
			DELETE FROM @working_V ; 
			DELETE FROM @working_H ; 

			--
			--

			SET @ColumnIterator += 1 ; 

			--
			--	

		END		

	--
	--
	
		INSERT INTO @transpose_Q 
		(
			MatrixID	
		--
		,	RowNumber	
		,	ColumnNumber	
		,	[Value]		
		--		
		)	

			SELECT	Q.MatrixID	
			--
			,		Q.ColumnNumber	as	RowNumber	
			,		Q.RowNumber		as	ColumnNumber	
			,		Q.[Value]		
			--		
			FROM	@running_Q	Q	
			--
			;

		--
		--	Verify calculations		
		--	

		INSERT INTO @t_Validation	
		(
			MatrixID	
		--
		,	Q_IsOrthogonal	
		--	
		)	

		SELECT	I.MatrixID	
		--
		,		1	--	Q_IsOrthogonal	
		--	
		FROM	math.fcn_Matrix_Product ( @running_Q , @transpose_Q )	I	
		--
		GROUP BY	I.MatrixID	
		--
		HAVING		MAX( ABS( CASE WHEN I.RowNumber = I.ColumnNumber 
								   THEN convert(float,1.000)	
								   ELSE convert(float,0.000) 
							  END - I.[Value] ) ) < @ValidationThreshold 
		--
		;	

	--
	--

		UPDATE		V	
		SET			V.QR_EqualsInput = 1	
		--	
		FROM		@t_Validation	V	
		INNER JOIN	(	
						SELECT		M.MatrixID	
						--	
						FROM		math.fcn_Matrix_Product ( @transpose_Q , @running_R )	P	
						INNER JOIN	@Input_Matrix	M	ON	(
																P.MatrixID = M.MatrixID 
															OR	(
																	P.MatrixID IS NULL 
																AND M.MatrixID IS NULL	
																)	
															)	
														--
														AND	P.RowNumber = M.RowNumber 
														AND P.ColumnNumber = M.ColumnNumber		
														--
						--
						GROUP BY	M.MatrixID	
						--
						HAVING		MAX( ABS( P.[Value] - M.[Value] ) ) < @ValidationThreshold 
						--
					)	
						X	ON	V.MatrixID = X.MatrixID		
							OR	(
									V.MatrixID IS NULL 
								AND X.MatrixID IS NULL	
								)	
		--
		;	

			--
			--	Compute determinants of Q matrices	
			--	

			UPDATE		V	
			--	
			SET			V.Q_Determinant = CASE WHEN R.NumberOfReflections % 2 = 0 
											   THEN 1 
											   ELSE -1 
										  END 
			--	
			FROM		@t_Validation	V	
			INNER JOIN	@t_Reflections	R	ON	V.MatrixID = R.MatrixID		
											OR	(
													V.MatrixID IS NULL 
												AND R.MatrixID IS NULL	
												)	
			;		

	--
	--

		--
		--	Output final calculations 
		--

		INSERT INTO @Output 
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

			SELECT	Q.MatrixID		
			--	
			,		'Q Matrix'		as	 Result	
			--		
			,		Q.RowNumber		
			,		Q.ColumnNumber	
			,		Q.[Value]		
			--
			FROM		@t_Validation	V	
			INNER JOIN	@transpose_Q	Q	ON	V.MatrixID = Q.MatrixID		
											OR	(
													V.MatrixID IS NULL 
												AND Q.MatrixID IS NULL	
												)	
			--
			WHERE		V.Q_IsOrthogonal = 1 
			AND			V.QR_EqualsInput = 1 
			--
			AND			V.Q_Determinant IS NOT NULL		
			--	

			UNION ALL 
			
			SELECT	R.MatrixID		
			--	
			,		'R Matrix'		as	 Result					
			--		
			,		R.RowNumber		
			,		R.ColumnNumber	
			,		CASE WHEN R.RowNumber > R.ColumnNumber 
						 THEN convert(float,0.000)			--	ensure diagonality		
						 ELSE R.[Value]	
					END						
			--
			FROM		@t_Validation	V	
			INNER JOIN	@running_R		R	ON	V.MatrixID = R.MatrixID		
											OR	(
													V.MatrixID IS NULL 
												AND R.MatrixID IS NULL	
												)	
			--
			WHERE		V.Q_IsOrthogonal = 1 
			AND			V.QR_EqualsInput = 1 
			--
			AND			V.Q_Determinant IS NOT NULL		
			--

			UNION ALL 

			SELECT		TraceR.MatrixID		
			--	
			,			'Determinant'		as	ResultCode					
			--			
			,			null				as	RowNumber		
			,			null				as	ColumnNumber	
			,			V.Q_Determinant 
					  * TraceR.[Value]		as	[Value]		
			--	
			FROM		(
							SELECT		R.MatrixID	
							--
							,			CASE WHEN MIN( ABS( R.[Value] ) ) <= @Trace_ZeroThreshold
											 THEN convert(float,0.000)	
											 -- 
											 ELSE EXP( convert(float, SUM( CASE WHEN ABS( R.[Value] ) > @Trace_ZeroThreshold  
																				THEN convert(float, LOG( ABS( R.[Value] ) ) ) 
																				ELSE convert(float,0.0) 
																		   END ) ) ) 
												* convert(float,
													CASE WHEN try_convert(int,
															  SUM( CASE WHEN R.[Value] < 0.0000	
															  			THEN 1 
															  			ELSE 0 
															  		END ) ) % 2 = 0 
														 THEN 1.00
														 ELSE -1.00 
													END 
												  )	
										END				[Value]					
							--
							,			MAX(R.ColumnNumber)		NumberOfColumns												
							--	
							FROM		@running_R	R	
							WHERE		R.RowNumber = R.ColumnNumber 
							GROUP BY	R.MatrixID 
						)	
							TraceR		
			--
			INNER JOIN	@t_Validation	V	ON	TraceR.MatrixID = V.MatrixID 
											OR	(
													TraceR.MatrixID IS NULL 
												AND V.MatrixID IS NULL	
												)	
			--	
			;	

	--
	--

	RETURN 
END
GO

--
--

CREATE FUNCTION [math].[fcn_Matrix_Determinant]
(
	@Input_Matrix  math.UTT_MatrixCoordinate  READONLY
)
RETURNS 
@Output TABLE 
(
	MatrixID		int		null	
--	
,	Determinant		float	not null	
--	
,	UNIQUE  (
				MatrixID	
		    )
)
AS 
/**************************************************************************************

	Returns the determinant of a provided matrix, 
	 or the determinants of a provided set of matrices. 

	Defined recursively using cofactor expansion.

	Only defined for 'square' matrices. 
	
		
		Example:	

			--
			--	

		DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

			VALUES	( 1 , 1 , 1 , 5.4 ) 
			--
			,		( 2 , 1 , 1 , 5.4 )		,	( 2 , 1 , 2 , 7.2 )		
			,		( 2 , 2 , 1 , 3.1 )		,	( 2 , 2 , 2 , 6.9 )		
			--	
			,		( 3 , 1 , 1 , 5.4 )		,	( 3 , 1 , 2 , 7.2 )		,	( 3 , 1 , 3 , 7.2 )	
			,		( 3 , 2 , 1 , 3.1 )		,	( 3 , 2 , 2 , 6.9 )		,	( 3 , 2 , 3 , 6.9 )
			,		( 3 , 3 , 1 , 4.8 )		,	( 3 , 3 , 2 , 2.7 )		,	( 3 , 3 , 3 , 1.8 )
			-- 
			;	

			SELECT		X.MatrixID	
			,			X.Determinant 
			FROM		math.fcn_Matrix_Determinant	( @Test )	X	
			ORDER BY	X.MatrixID	ASC		
			;	
			
			--
			--

	Date			Action	
	----------		----------------------------
	2016-05-15		Created initial version.	
	2018-06-18		Using new math.fcn_Matrix_QRFactorization to improve speed.	
	2019-01-28		Replaced POWER function usage with CASE statement and % (modulus operator).
	
**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

		--
		--	Check for any input matrices which are not 'square' 
		--	

		IF EXISTS ( SELECT		null 
					FROM		@Input_Matrix	X	
					GROUP BY	X.MatrixID 
					HAVING		MAX(X.RowNumber) != MAX(X.ColumnNumber) ) 
		BEGIN 

			RETURN ; 

		END 

	--
	--
	--	
	-- 
	
	DECLARE @Output_Staging	TABLE 
	(
		ID				int		not null	identity(1,1)	primary key 
	--
	,	MatrixID		int		null		
	-- 
	,	Determinant		float	not null	
	--
	,	UNIQUE  (
					MatrixID		
				) 
	)	
	;	

	DECLARE @MatrixMinor TABLE 
	(
		ID							int		not null	identity(1,1)	primary key		
	--
	,	MatrixID					int		null 
	,	RowNumber					int		not null 
	--
	,	Related_CoordinateValue		float	not null	
	)	

	
	DECLARE	@t_Minor_Recursion AS math.UTT_MatrixCoordinate ; 

	
	--
	--

		--
		--	if matrix is 1x1, return the single coordinate value 
		--	

		INSERT INTO @Output_Staging 
		(
			MatrixID 
		--
		,	Determinant 
		)	

		SELECT		M.MatrixID 
		--
		,			MAX(M.[Value])	
		--	
		FROM		@Input_Matrix	M	
		--	
		GROUP BY	M.MatrixID 
		--
		HAVING		COUNT(*) = 1 
		--	
		;	
		
	--
	--
	
		--
		--	2018-06-18 :: try using QR Factorization for a speedier computation		
		--	
		
			INSERT INTO @Output_Staging		
			(
				MatrixID	
			,	Determinant		
			)	

				SELECT	X.MatrixID	
				,		ROUND ( X.[Value] , 12 )	as	Determinant		
				--		
				FROM		math.fcn_Matrix_QRFactorization	( @Input_Matrix )	X	
				LEFT  JOIN	@Output_Staging		S	ON	X.MatrixID = S.MatrixID		
													OR	(
															X.MatrixID IS NULL 
														AND S.MatrixID IS NULL	
														)	
				--	
				WHERE	X.Result = 'Determinant'	
				--
				AND		X.RowNumber IS NULL 
				AND		X.ColumnNumber IS NULL	
				--	
				AND		S.ID IS NULL	
				--	
				;		

		--
		--	// 2018-06-18	
		--

	--
	--

		--
		--	if there are still matrices without a calculated determinant, use cofactor expansion 
		--	

		IF EXISTS ( SELECT		null 
					FROM		(
									SELECT	distinct	I.MatrixID 
									FROM	@Input_Matrix	I	
								)	
													X	
					LEFT  JOIN	@Output_Staging		O	ON	X.MatrixID = O.MatrixID 
														OR	(
																X.MatrixID IS NULL 
															AND O.MatrixID IS NULL 
															)	
					WHERE		O.ID IS NULL ) 
		BEGIN 

			--
			--	generate an 'ID' value for each relevant MatrixID and RowNumber pair  
			--	

			INSERT INTO @MatrixMinor 
			(
				MatrixID 
			,	RowNumber 
			--
			,	Related_CoordinateValue 
			)	

			SELECT		Z.MatrixID 
			,			Z.RowNumber 
			--
			,			Z.[Value] 		
			--	
			FROM		(
							SELECT		X.MatrixID 
							FROM		(
											SELECT	distinct	I.MatrixID		
											FROM	@Input_Matrix	I	
										)	
														   X
							LEFT  JOIN	@Output_Staging	   O	ON	X.MatrixID = O.MatrixID 
																OR	(
																		X.MatrixID IS NULL 
																	AND O.MatrixID IS NULL 
																	)	
							WHERE		O.ID IS NULL 
						)	
										Y
			INNER JOIN	@Input_Matrix	Z	ON	(
													Y.MatrixID = Z.MatrixID 
												OR	(
														Y.MatrixID IS NULL 
													AND Z.MatrixID IS NULL 
													)	
												)	
											--
											AND	Z.ColumnNumber = 1 
											--	
			;	

			--
			--	define Minor matrices 
			--	

			INSERT INTO @t_Minor_Recursion 
			(
				MatrixID 
			--	
			,	RowNumber 
			,	ColumnNumber 
			--	
			,	[Value] 
			)	 
	
				SELECT		M.ID 
				--
				,			DENSE_RANK() OVER ( PARTITION BY M.ID 
												ORDER BY	 I.RowNumber ASC ) 
						as	Minor_RowNumber
				,			DENSE_RANK() OVER ( PARTITION BY M.ID 
												ORDER BY	 I.ColumnNumber ASC )
						as	Minor_ColumnNumber
				--
				,			I.[Value] 
				--	
				FROM		@MatrixMinor	M	
				INNER JOIN	@Input_Matrix	I	ON	(
														M.MatrixID = I.MatrixID 
													OR	(
															M.MatrixID IS NULL 
														AND I.MatrixID IS NULL 
														)	
													)	
												--
												AND	M.RowNumber != I.RowNumber 
												AND I.ColumnNumber != 1 
												--
				;

			--
			--	calculate Determinants using cofactor expansion		
			--	

			INSERT INTO @Output_Staging 
			(
				MatrixID 
			--
			,	Determinant 
			)	

			SELECT		M.MatrixID 
			--
			,	SUM(	M.Related_CoordinateValue 
					  * CASE WHEN ( 1 + M.RowNumber ) % 2 = 0 
							  THEN D.Determinant 
							  ELSE -D.Determinant
						END 
				   )			 
			--	
			FROM		@MatrixMinor					 M	
			INNER JOIN	math.fcn_Matrix_Determinant	
								( @t_Minor_Recursion )	 D	 ON	  M.ID = D.MatrixID 
			--
			GROUP BY	M.MatrixID 
			--
			;	

		END		

	--
	--

		--
		--	Output final calculations 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	Determinant	
		)	

			SELECT		S.MatrixID 
			--
			,			S.Determinant
			--		
			FROM		@Output_Staging		S	
			;	
	
	--
	--

	RETURN 
END
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the determinant of a provided matrix (table-valued as it also handles multiple input matrices)' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Matrix_Determinant'
--GO

--
--

CREATE FUNCTION [math].[fcn_Matrix_Adjugate]
(
	@Input_Matrix  math.UTT_MatrixCoordinate  READONLY
)
RETURNS 
@Output TABLE 
(
	MatrixID		int		null 
--	
,	RowNumber		int		not null	
,	ColumnNumber	int		not null	
,	[Value]			float	not null	
--
,	UNIQUE (
				MatrixID 
		   --	
		   ,	RowNumber 
		   ,	ColumnNumber 
		   )	
)
AS 
/**************************************************************************************

	Returns the adjugate of a provided matrix, 
	 or the adjugates of a provided set of matrices. 


		Example:	

			--
			--
			
		DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

			VALUES	( 1 , 1 , 1 , 5.4 ) 
			--
			,		( 2 , 1 , 1 , 5.4 )		,	( 2 , 1 , 2 , 7.2 )		
			,		( 2 , 2 , 1 , 3.1 )		,	( 2 , 2 , 2 , 6.9 )		
			--	
			,		( 3 , 1 , 1 , 5.4 )		,	( 3 , 1 , 2 , 7.2 )		,	( 3 , 1 , 3 , 7.2 )	
			,		( 3 , 2 , 1 , 3.1 )		,	( 3 , 2 , 2 , 6.9 )		,	( 3 , 2 , 3 , 6.9 )
			,		( 3 , 3 , 1 , 4.8 )		,	( 3 , 3 , 2 , 2.7 )		,	( 3 , 3 , 3 , 1.8 )
			-- 
			;	

			SELECT		X.MatrixID	
			,			X.RowNumber 
			,			X.ColumnNumber
			,			X.[Value] 
			FROM		math.fcn_Matrix_Adjugate ( @Test )	X	
			ORDER BY	X.MatrixID	ASC		
			,			X.RowNumber ASC 
			,			X.ColumnNumber ASC 
			;	

	--
	--

	Date			Action	
	----------		----------------------------
	2016-05-15		Created initial version.	
	2019-01-28		Replaced POWER function usage with CASE statement and % (modulus operator).
	
**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		
		
		--
		--	Check for any input matrices which are not 'square' 
		--	

		IF EXISTS ( SELECT		null 
					FROM		@Input_Matrix	X	
					GROUP BY	X.MatrixID 
					HAVING		MAX(X.RowNumber) != MAX(X.ColumnNumber) ) 
		BEGIN 

			RETURN ; 

		END 

	--
	--	

		DECLARE	@t_Minor AS math.UTT_MatrixCoordinate ; 

	--
	--	

		--
		--	Define minor matrices 
		--

		INSERT INTO @t_Minor	
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		--	
		,	[Value] 
		)	

			SELECT		M.ID 
			--
			,			DENSE_RANK() OVER ( PARTITION BY M.ID 
											ORDER BY	 I.RowNumber ASC ) 
					as	Minor_RowNumber
			,			DENSE_RANK() OVER ( PARTITION BY M.ID 
											ORDER BY	 I.ColumnNumber ASC )
					as	Minor_ColumnNumber
			--
			,			I.[Value] 
			--	
			FROM		@Input_Matrix	M	
			INNER JOIN	@Input_Matrix	I	ON	(
													M.MatrixID = I.MatrixID 
												OR	(
														M.MatrixID IS NULL 
													AND I.MatrixID IS NULL 
													)	
												)	
											--
											AND	M.RowNumber != I.RowNumber 
											AND M.ColumnNumber != I.ColumnNumber 
											--
			;

	--
	--

		--
		--	Output adjugate matrix 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		--
		,	[Value] 	
		)	

			SELECT		I.MatrixID 
			--
			,			I.ColumnNumber	--	 switch row number and column number 
			,			I.RowNumber		--	  to return adjugate instead of cofactor matrix 
			--
			,			CASE WHEN ( I.ColumnNumber + I.RowNumber ) % 2 = 0 
							 THEN D.Determinant  
							 ELSE - D.Determinant 
						END
			--	
			FROM		@Input_Matrix								I		
			INNER JOIN	math.fcn_Matrix_Determinant	( @t_Minor )	D	ON	I.ID = D.MatrixID 
			;	
	
	--
	--

		--
		--	Handle 1x1 input matrices by returning a matrix with single entry of 1 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		--
		,	[Value] 
		-- 
		)	

			SELECT		X.MatrixID 
			--
			,			1
			,			1 
			--
			,			convert(float, 1.0) 
			--
			FROM		(
							SELECT		M.MatrixID	
							FROM		@Input_Matrix	M	
							GROUP BY	M.MatrixID 
							HAVING		COUNT(*) = 1 
						)	
							X	
			;	

	--
	--

	RETURN 
END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the adjugate of a provided matrix' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Matrix_Adjugate'
--GO

--
--

CREATE FUNCTION [math].[fcn_Matrix_Inverse]
(
	@Input_Matrix  math.UTT_MatrixCoordinate  READONLY
)	
RETURNS 
@Output TABLE 
(
	MatrixID		int		null	
--	
,	RowNumber		int		not null	
,	ColumnNumber	int		not null	
,	[Value]			float	not null	
--
,	UNIQUE  (	
				MatrixID		
			-- 
			,	RowNumber		
			,	ColumnNumber	
			)	
) 
AS 
/**************************************************************************************

	Returns the inverse of a provided matrix, 
	 or the inverses of a provided set of matrices. 
	 
		
		Example:	

		--
		--	
		
		DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

			VALUES	( 1 , 1 , 1 , 5.4 ) 
			--
			,		( 2 , 1 , 1 , 5.4 )		,	( 2 , 1 , 2 , 7.2 )		
			,		( 2 , 2 , 1 , 3.1 )		,	( 2 , 2 , 2 , 6.9 )		
			--	
			,		( 3 , 1 , 1 , 5.4 )		,	( 3 , 1 , 2 , 7.2 )		,	( 3 , 1 , 3 , 7.2 )	
			,		( 3 , 2 , 1 , 3.1 )		,	( 3 , 2 , 2 , 6.9 )		,	( 3 , 2 , 3 , 6.9 )
			,		( 3 , 3 , 1 , 4.8 )		,	( 3 , 3 , 2 , 2.7 )		,	( 3 , 3 , 3 , 1.8 )
			-- 
			;	

			SELECT		X.MatrixID	
			,			X.RowNumber 
			,			X.ColumnNumber
			,			X.[Value] 
			FROM		math.fcn_Matrix_Inverse ( @Test )	X	
			ORDER BY	X.MatrixID	ASC		
			,			X.RowNumber ASC 
			,			X.ColumnNumber ASC 
			;	

	--
	--
	
	Date			Action	
	----------		----------------------------
	2016-05-15		Created initial version.	
	2019-01-28		Using CASE statement in final @Output INSERT (extra precaution for 0 determinant). 
	
**************************************************************************************/		
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		
		
		--
		--	Check for any input matrices which are not 'square' 
		--	

		IF EXISTS ( SELECT		null 
					FROM		@Input_Matrix	X	
					GROUP BY	X.MatrixID 
					HAVING		MAX(X.RowNumber) != MAX(X.ColumnNumber) ) 
		BEGIN 

			RETURN ; 

		END 

	--
	--	

		--
		--	Output inverse matrix (using Adjugate and Determinant functions) 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		--
		,	[Value] 	
		)	

			SELECT		A.MatrixID 
			--
			,			A.ColumnNumber
			,			A.RowNumber 
			--
			,			CASE WHEN D.Determinant = 0.00 
							 THEN null 
							 ELSE A.[Value] / D.Determinant 
						END											as	[Value]		
			--	
			FROM		math.fcn_Matrix_Adjugate( @Input_Matrix	)		A	
			INNER JOIN	math.fcn_Matrix_Determinant ( @Input_Matrix ) 	D	ON	A.MatrixID = D.MatrixID 
																			OR	(
																					A.MatrixID IS NULL 
																				AND D.MatrixID IS NULL 
																				)	
			--		
			WHERE	D.Determinant != 0.00	--	input matrix must be invertible
			--	
			;	
	
	--
	--

	RETURN 
END


GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the inverse of a provided matrix' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Matrix_Inverse'
--GO

--
--

CREATE FUNCTION [math].[fcn_Matrix_RowEchelonForm] 
(
	@Input_Matrix	math.UTT_MatrixCoordinate	READONLY	
)
RETURNS 
@Output TABLE 
(
	MatrixID		int		null		
-- 
,	RowNumber		int		not null	
,	ColumnNumber	int		not null	
,	[Value]			float	not null	
--
,	UNIQUE  (
				MatrixID	
			--	
			,	RowNumber 
			,	ColumnNumber	
			) 
)	
AS
/**************************************************************************************

	Performs Gaussian elimination to convert an input matrix 
		(or set of input matrices) into row echelon form. 

	If any input matrix is not appropriately configured 
		then no results will be returned. 

		
		Example:	

			--
			--
			
			DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

			INSERT INTO @Test ( RowNumber , ColumnNumber , [Value] )

				VALUES		( 1 , 1 , 5.00 )	,	( 1 , 2 , 3.00 )	,	( 1 , 3 , 8.00 )	
				,			( 2 , 1 , 2.00 )	,	( 2 , 2 , 7.00 )	,	( 2 , 3 , 4.00 )	
				,			( 3 , 1 , 6.00 )	,	( 3 , 2 , 5.00 )	,	( 3 , 3 , 3.00 )
				,			( 4 , 1 , 3.00 )	,	( 4 , 2 , 2.00 )	,	( 4 , 3 , 10.00 )
				,			( 5 , 1 , 3.00 )	,	( 5 , 2 , 2.00 )	,	( 5 , 3 , 10.00 )
				,			( 6 , 1 , 3.00 )	,	( 6 , 2 , 2.00 )	,	( 6 , 3 , 10.00 )
				,			( 7 , 1 , 3.00 )	,	( 7 , 2 , 2.00 )	,	( 7 , 3 , 10.00 )
				;	
			
			SELECT		X.MatrixID		
			,			X.RowNumber		
			,			X.ColumnNumber	
			,			X.[Value] 			
			FROM		math.fcn_Matrix_RowEchelonForm ( @Test ) X 
			ORDER BY	X.MatrixID	
			,			X.RowNumber 
			,			X.ColumnNumber	
			;		

			--
			--

	Date			Action	
	----------		----------------------------
	2015-12-14		Created initial version.	
	2015-12-15		Optimized for speed. 
	2016-01-07		Optimized for speed. 
	2016-05-17		Optimized for speed. 
	2016-06-22		Small change to row elimination update statement for speed improvement. 

**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		
	--
	--

		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

	--
	--

	DECLARE  @MaxIterations	 int 
	,		 @Iterator		 int		
	--	
	;	

	--	
	-- 
	
	DECLARE @Output_Staging	TABLE 
	(
		ID				int		not null	identity(1,1)	primary key 
	--
	,	MatrixID		int		null		
	-- 
	,	RowNumber		int		not null	
	,	ColumnNumber	int		not null	
	,	[Value]			float	not null	
	--
	,	UNIQUE  (
					MatrixID		
				--	
				,	RowNumber		
				,	ColumnNumber	
				) 
	)	
	;	

	DECLARE	@MatrixStatistics TABLE 
	(
		ID							int		not null	identity(1,1)	primary key 
	--
	,	MatrixID					int		null		unique	
	--
	,	NumberOfRows				int		not null	
	,	NumberOfColumns				int		not null	
	--
	,	iteration_Swap_Row_From		int		null 
	,	iteration_Swap_Row_To		int		null 
	,	iteration_Pivot_Value		float	null 
	)	
	;	

	--
	--

		DECLARE @loop_Row_Swap_Update TABLE 
		(
			Output_StagingID		int		not null	
		,	New_RowNumber			int		not null	
		--
		,	PRIMARY KEY (	--	including both columns so that New_RowNumber is indexed, 
							--	 even though Output_StagingID is unique on its own 
							Output_StagingID	
						,	New_RowNumber		
						)	
		)	
		;	

		DECLARE @loop_Row_Elimination_Multiplier TABLE 
		(
			ID				int			not null		identity(1,1)	primary key 
		--
		,	MatrixID		int			null	
		--
		,	RowNumber		int			not null 
		,	ColumnNumber	int			not null	
		--
		,	Multiplier		float		not null	
		--
		,	UNIQUE  (
						MatrixID	
					--	
					,	RowNumber	
					,	ColumnNumber	
					) 
		--	2016-06-22	
		,	UNIQUE  (
						MatrixID	
					--	
					,	ColumnNumber	
					) 
		)	
		;

	--
	--

		--
		--	Gather input records into staging table. 
		--	

	--
	--

		INSERT INTO @Output_Staging 
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]	
		)	

			SELECT		M.MatrixID	
			--
			,			M.RowNumber 
			,			M.ColumnNumber 
			,			M.[Value] 
			FROM		@Input_Matrix	M	
			;	

	--
	--

		--
		--	Calculate row and column statistics for input matrices. 
		--	

	--
	--

		INSERT INTO @MatrixStatistics 
		(
			MatrixID 
		--
		,	NumberOfRows 
		,	NumberOfColumns 
		)	

			SELECT		S.MatrixID 
			--
			,			MAX(S.RowNumber)		
			,			MAX(S.ColumnNumber)		
			FROM		@Output_Staging		S	
			GROUP BY	S.MatrixID 		
			;	
			
	--
	--
	
		--
		--	Prepare for Gaussian elimination calculation loop. 
		--	

	--
	--

	SELECT  @MaxIterations = CASE WHEN MAX(S.NumberOfRows) < MAX(S.NumberOfColumns) 
								  THEN MAX(S.NumberOfRows)	
								  ELSE MAX(S.NumberOfColumns)	
							 END 
	FROM	@MatrixStatistics	S		
	;	

	SET		@Iterator = 1 
	;	

	--
	--

		--
		--	Run calculation loop. 
		--	
	
	--
	--

	WHILE @Iterator <= @MaxIterations 
	BEGIN 

		--
		--	clear swap and pivot column values for current iteration 
		--	
		
		UPDATE	M 
		SET		M.iteration_Swap_Row_From	=	null 
		,		M.iteration_Swap_Row_To		=	null 
		,		M.iteration_Pivot_Value		=	null 
		FROM	@MatrixStatistics	M	
		;	

		--
		--	swap rows, if necessary 
		-- 

		UPDATE		M 
		SET			M.iteration_Swap_Row_From	=	X.RowNumber 
		,			M.iteration_Pivot_Value		=	X.[Value] 
		,			M.iteration_Swap_Row_To		=	CASE WHEN X.[Value] = 0 
														 THEN X.RowNumber 
														 ELSE @Iterator 
													END 
		FROM		@MatrixStatistics	M	
		INNER JOIN	(
						SELECT	S.MatrixID 
						,		S.RowNumber 
						,		S.Value		
						,		RANK() OVER ( 
												PARTITION BY	S.MatrixID	
												ORDER BY		ABS( S.[Value] )	DESC 
												,				S.RowNumber			ASC 
											)	
											as	ValueRank	
						FROM	@Output_Staging	 S 	
						WHERE	S.ColumnNumber = @Iterator 	
						AND		S.RowNumber >= @Iterator
					)	
						X	ON	M.MatrixID = X.MatrixID 
							OR	(
									M.MatrixID IS NULL 
								AND X.MatrixID IS NULL 
								)	
		WHERE	X.ValueRank = 1 
		;	

		--
		--

		IF EXISTS ( SELECT	null 
					FROM	@MatrixStatistics	S	
					WHERE	(
								S.NumberOfColumns >= @Iterator 
							AND	S.NumberOfRows >= @Iterator 
							AND	(
								   S.iteration_Swap_Row_From IS NULL 
								OR S.iteration_Swap_Row_From < 1 
								OR S.iteration_Swap_Row_From > S.NumberOfRows 
								--
								OR S.iteration_Swap_Row_To IS NULL 
								OR S.iteration_Swap_Row_To < 1 
								OR S.iteration_Swap_Row_To > S.NumberOfRows 
								--
								OR S.iteration_Pivot_Value IS NULL 
								) 
							)	
					OR		(
								(
									S.NumberOfColumns < @Iterator 
								OR	S.NumberOfRows < @Iterator 
								)	
							AND	(
								   S.iteration_Swap_Row_From IS NOT NULL 
								--
								OR S.iteration_Swap_Row_To IS NOT NULL 
								--
								OR S.iteration_Pivot_Value IS NOT NULL 
								) 
							)	
				  ) 
		BEGIN 
			
			--	
			--	There was a problem defining the swap indices on the current iteration. 
			--	
			RETURN ; 

		END	

			--
			--	Perform UPDATE to swap matrix rows 
			--	

		/*	
			--
			--	2016-05-17 : old logic is here, replaced by below INSERT/UPDATE to improve speed 	
			--	

			UPDATE		S 
			SET			S.RowNumber = CASE S.RowNumber	
										WHEN M.iteration_Swap_Row_From THEN M.iteration_Swap_Row_To 
										WHEN M.iteration_Swap_Row_To   THEN M.iteration_Swap_Row_From 
									  END 
			FROM		@Output_Staging		S		
			INNER JOIN	@MatrixStatistics	M	ON	(
														S.MatrixID = M.MatrixID		
													OR	(
															S.MatrixID IS NULL 
														AND	M.MatrixID IS NULL 
														)	
													)	
												AND S.RowNumber IN ( M.iteration_Swap_Row_From 
																   , M.iteration_Swap_Row_To ) 
			WHERE		M.iteration_Swap_Row_From != M.iteration_Swap_Row_To 
			;	
		--
		--
		--	
		*/	

			IF EXISTS ( SELECT	null 
						FROM	@loop_Row_Swap_Update ) 
			BEGIN 

				DELETE 
				FROM	@loop_Row_Swap_Update 
				;	
				
			END		
			
			--
			--

			INSERT INTO @loop_Row_Swap_Update	
			(
				Output_StagingID 
			,	New_RowNumber 
			)	

			SELECT		S.ID 
			,			M.iteration_Swap_Row_To 
			FROM		@Output_Staging		S		
			INNER JOIN	@MatrixStatistics	M	ON	(
														S.MatrixID = M.MatrixID		
													OR	(
															S.MatrixID IS NULL 
														AND	M.MatrixID IS NULL 
														)	
													)	
												AND S.RowNumber = M.iteration_Swap_Row_From 
			--	
			WHERE		M.iteration_Swap_Row_From != M.iteration_Swap_Row_To 
			--
			;	
			
			INSERT INTO @loop_Row_Swap_Update	
			(
				Output_StagingID 
			,	New_RowNumber 
			)	

			SELECT		S.ID 
			,			M.iteration_Swap_Row_From  
			FROM		@Output_Staging		S		
			INNER JOIN	@MatrixStatistics	M	ON	(
														S.MatrixID = M.MatrixID		
													OR	(
															S.MatrixID IS NULL 
														AND	M.MatrixID IS NULL 
														)	
													)	
												AND S.RowNumber = M.iteration_Swap_Row_To  
			--	
			WHERE		M.iteration_Swap_Row_From != M.iteration_Swap_Row_To 
			--
			;	

			--
			--

			UPDATE		S  
			SET			S.RowNumber = U.New_RowNumber 
			FROM		@Output_Staging			S	
			INNER JOIN	@loop_Row_Swap_Update	U	ON	S.ID = U.Output_StagingID	
			;	
				

		--
		--
		--


		IF EXISTS ( SELECT	null 
					FROM	@loop_Row_Elimination_Multiplier ) 
		BEGIN 
			
			DELETE 
			FROM	@loop_Row_Elimination_Multiplier 
			;	

		END		


		--		
		--	eliminate values in current pivot column for rows beneath the current pivot row 
		--

			INSERT INTO @loop_Row_Elimination_Multiplier 
			(
				MatrixID 
			--
			,	RowNumber 
			,	ColumnNumber 
			--
			,	Multiplier 
			)	

				SELECT		M.MatrixID 
				--
				,			M.RowNumber 
				,			M.ColumnNumber 
				--
				,			M.[Value] / S.iteration_Pivot_Value 
				FROM		@MatrixStatistics	S	
				INNER JOIN	@Output_Staging		M	ON	(
															S.MatrixID = M.MatrixID		
														OR	(
																S.MatrixID IS NULL 
															AND	M.MatrixID IS NULL 
															)	
														)	
													AND S.iteration_Pivot_Value != 0 
													AND S.iteration_Swap_Row_To = M.RowNumber 
													--
													AND M.ColumnNumber > @Iterator	--	added 2015-05-17	
													--	
				;	

		/*  --
			--  2016-05-17 : only populating the table above for columns after @Iterator, 
			--				  and breaking the below UPDATE statement (previous logic) into 2 separate statements 
			-- 

			UPDATE		N 
			SET			N.[Value] = CASE WHEN N.ColumnNumber = @Iterator 
									     THEN 0 
									     WHEN F.[Value] = 0 
									     OR   M.Multiplier = 0 
									     THEN N.[Value]  
									     ELSE N.[Value] - F.[Value] * M.Multiplier
								    END 
			FROM		@loop_Row_Elimination_Multiplier	M	
			INNER JOIN	@Output_Staging						F	ON	(
																		M.MatrixID = F.MatrixID		
																	OR	(
																			M.MatrixID IS NULL 
																		AND	F.MatrixID IS NULL 
																		)	
																	)	
																AND F.RowNumber > M.RowNumber 
																AND F.ColumnNumber = @Iterator 
			INNER JOIN	@Output_Staging						N	ON	(
																		F.MatrixID = N.MatrixID		
																	OR	(
																			F.MatrixID IS NULL 
																		AND	N.MatrixID IS NULL 
																		)	
																	)	
																AND M.ColumnNumber = N.ColumnNumber 
																AND F.RowNumber = N.RowNumber 
			;	
		--
		--
		--		
		*/ 


		UPDATE		N 
		SET			N.[Value] = N.[Value] - F.[Value] * M.Multiplier 
		--	
		FROM		@loop_Row_Elimination_Multiplier	M	
		INNER JOIN	@Output_Staging						F	ON	(
																	M.MatrixID = F.MatrixID		
																OR	(
																		M.MatrixID IS NULL 
																	AND	F.MatrixID IS NULL 
																	)	
																)	
															AND F.RowNumber > M.RowNumber 
															AND F.ColumnNumber = @Iterator 
															--
															AND (	-- 2016-06-22 
																	F.[Value] != 0 
																OR	M.Multiplier != 0 
																)	
															--	
		INNER JOIN	@Output_Staging						N	ON	(
																	F.MatrixID = N.MatrixID		
																OR	(
																		F.MatrixID IS NULL 
																	AND	N.MatrixID IS NULL 
																	)	
																)	
															AND M.ColumnNumber = N.ColumnNumber 
															AND F.RowNumber = N.RowNumber 
		--	
		;	


		UPDATE		N 
		SET			N.[Value] = 0 
		FROM		@MatrixStatistics	X	
		INNER JOIN	@Output_Staging		N	ON	X.MatrixID = N.MatrixID 
											OR	(
													X.MatrixID IS NULL 
												AND N.MatrixID IS NULL 
												)	
		WHERE		N.ColumnNumber = @Iterator 
		AND			X.iteration_Pivot_Value != 0 
		AND			N.RowNumber > X.iteration_Swap_Row_To
		;	


		--
		--	prepare for next iteration	
		--

		SET	@Iterator += 1 ; 

	END		
	
	--
	--

		--
		--	Output final calculations 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]	
		)	

			SELECT		S.MatrixID 
			--
			,			S.RowNumber 
			,			S.ColumnNumber 
			,			S.[Value]		
			FROM		@Output_Staging		S	
			;	
	
	--
	--

	RETURN 
END


GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Performs Gaussian elimination to convert an input matrix into row echelon form' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Matrix_RowEchelonForm'
--GO

--
--

CREATE FUNCTION [math].[fcn_Matrix_Eigendecomposition]
(
	@Input_Matrix  math.UTT_MatrixCoordinate  READONLY
)
RETURNS 
@Output TABLE 
(
	MatrixID		int				null	
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
AS 
/**************************************************************************************

	For an input square, symmetric matrix A, returns a square matrix Q of the same size 
	and a column vector D of eigenvalues for A 
	such that:		A =  Q * diag(D) * Q^T 
			   and	Q is orthogonal. 


		Uses repeated QR factorization. 

	
		
		Example:	

			--
			--	

		DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test ( RowNumber , ColumnNumber , Value ) 

			VALUES	( 1 , 1 , 1 )	,	( 1 , 2 , 1 )	,	( 1 , 3 ,  1 )	,	( 1 , 4 , 1 )	,	( 1 , 5 , 1 )	
			,		( 2 , 1 , 1 )	,	( 2 , 2 , 1 )	,	( 2 , 3 ,  1 )	,	( 2 , 4 , 1 )	,	( 2 , 5 , 1 )	
			,		( 3 , 1 , 1 )	,	( 3 , 2 , 1 )	,	( 3 , 3 ,  1 )	,	( 3 , 4 , 1 )	,	( 3 , 5 , 1 )	
			,		( 4 , 1 , 1 )	,	( 4 , 2 , 1 )	,	( 4 , 3 ,  1 )	,	( 4 , 4 , 1 )	,	( 4 , 5 , 1 )	
			,		( 5 , 1 , 1 )	,	( 5 , 2 , 1 )	,	( 5 , 3 ,  1 )	,	( 5 , 4 , 1 )	,	( 5 , 5 , 1 )	
			-- 
			;	

			SELECT		X.Result					
			--								
			,			X.RowNumber			
			,			X.ColumnNumber		
			,			X.[Value]			
			--
			FROM		math.fcn_Matrix_Eigendecomposition ( @Test )	X	
			--
			ORDER BY	X.Result			ASC		
			,			X.ColumnNumber		ASC		
			,			X.RowNumber			ASC		
			--
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2018-06-19		Created initial version.	
	2019-04-05		Adjusted configured variable values for @MaximumNumberOfIterations and @ValidationThreshold. 
	
**************************************************************************************/	
BEGIN
	
	--
	--

		DECLARE		@Iterator						int		=	1	
		,			@MinimumNumberOfIterations		int		=	10
		,			@MaximumNumberOfIterations		int		=	2500	 --  changed from 500	on 2019-04-05	
		--																 
		,			@ValidationThreshold			float	=	0.0001	 --  changed from 0.000001	on 2019-04-05	
		--	
		;	

	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

		--
		--	Check for any input matrices which are not 'square' 
		--	

		IF EXISTS ( SELECT		null 
					FROM		@Input_Matrix	X	
					GROUP BY	X.MatrixID 
					HAVING		MAX(X.RowNumber) != MAX(X.ColumnNumber) ) 
		BEGIN 

			RETURN ; 

		END 
		
	--
	--

		--
		--	Check for any input matrices which are not 'symmetric' 
		--	

		IF EXISTS ( SELECT		null 
					FROM		@Input_Matrix	X	
					INNER JOIN	@Input_Matrix	Y	ON	(
															X.MatrixID = Y.MatrixID		
														OR	(
																X.MatrixID IS NULL 
															AND Y.MatrixID IS NULL	
															)	
														)	
													--	
													AND X.ColumnNumber = Y.RowNumber	
													AND X.RowNumber = Y.ColumnNumber	
													--
													AND X.ColumnNumber <= Y.RowNumber 
													--
					GROUP BY	X.MatrixID 
					HAVING		MAX( ABS( X.[Value] - Y.[Value] ) ) > @ValidationThreshold ) 
		BEGIN 

			RETURN ; 

		END 

	--
	--
	--	
	-- 
	
	DECLARE	@current_Q AS math.UTT_MatrixCoordinate ; 
	DECLARE	@current_R AS math.UTT_MatrixCoordinate ; 
	--
	DECLARE	@working_Q AS math.UTT_MatrixCoordinate ; 
	DECLARE	@working_D AS math.UTT_MatrixCoordinate ; 
	--	
	;	

	DECLARE @QRFactorization_Result TABLE 
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
	,	UNIQUE	(
					MatrixID	
				,	Result	
				,	RowNumber	
				,	ColumnNumber	
				)	
	--
	)	 
	--
	;	

	DECLARE @Output_Staging TABLE 
	(
		MatrixID		int				null	
	--	
	,	Result			varchar(10)		not null	
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
	--	 
	)
	--
	;	

	DECLARE @t_Validation TABLE 
	(
		ID					int		not null	identity(1,1)	primary key		
	--
	,	MatrixID			int		null		unique	
	--
	,	D_IsDiagonal		bit		null	
	--,	QDQT_EqualsInput	bit		null		
	--	
	) 
	--
	;	
		
	--
	--
	--
	--
	
		INSERT INTO @working_D 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber
		,	[Value] 
		)	

			SELECT	A.MatrixID 
			,		A.RowNumber 
			,		A.ColumnNumber
			,		A.[Value] 
			FROM	@Input_Matrix	A	
			--	
			;	

		--
		--

			--
			--	identity matrix		
			--	
		INSERT INTO @working_Q	
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber
		,	[Value] 
		)	

			SELECT	A.MatrixID 
			,		A.RowNumber 
			,		A.ColumnNumber
			,		CASE WHEN A.RowNumber = A.ColumnNumber 
						 THEN CONVERT(float,1.000) 
						 ELSE CONVERT(float,0.000)
					END										as	[Value] 
			FROM	@Input_Matrix	A	
			--	
			;	

	--
	--

	WHILE @Iterator <= @MaximumNumberOfIterations 
	AND EXISTS ( SELECT null 
				 FROM	@working_D )	
	BEGIN	

		--
		--

		IF @Iterator >= @MinimumNumberOfIterations
		OR @Iterator = 1 
		BEGIN	
			
			INSERT INTO @t_Validation 
			(	
				MatrixID 
			,	D_IsDiagonal
			)	

			SELECT		X.MatrixID	
			,			1	
			--	
			FROM		@working_D	X	
			GROUP BY	X.MatrixID	
			--	
			HAVING		MAX( CASE WHEN X.RowNumber = X.ColumnNumber		
								  THEN convert(float,0.000)		 
								  ELSE ABS( X.[Value] ) 
							 END ) < @ValidationThreshold 
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
			--	 
			)

				SELECT		Q.MatrixID 
				--
				,			'Q Matrix'	
				--			
				,			Q.RowNumber	
				,			Q.ColumnNumber
				,			Q.[Value]		
				--	 
				FROM		@t_Validation	V	
				INNER JOIN	@working_Q		Q	ON	V.MatrixID = Q.MatrixID		
												OR	(
														V.MatrixID IS NULL 
													AND Q.MatrixID IS NULL 
													)	
				--
				WHERE		V.D_IsDiagonal = 1	
				--

				UNION ALL 
				
				SELECT		D.MatrixID 
				--
				,			'Eigenvalue'	
				--			
				,			D.RowNumber	
				,			1				as	ColumnNumber
				,			D.[Value]			
				--	 
				FROM		@t_Validation	V	
				INNER JOIN	@working_D		D	ON	(
														V.MatrixID = D.MatrixID		
													OR	(
															V.MatrixID IS NULL 
														AND D.MatrixID IS NULL 
														)	
													) 
												--
												AND D.ColumnNumber = D.RowNumber 
												--
				--
				WHERE		V.D_IsDiagonal = 1	
				--

			--
			--

			DELETE		D	
			FROM		@t_Validation	V	
			INNER JOIN	@working_D		D	ON	V.MatrixID = D.MatrixID		
											OR	(
													V.MatrixID IS NULL 
												AND D.MatrixID IS NULL 
												)	
			--
			WHERE		V.D_IsDiagonal = 1	
			--
			;	
			
			DELETE		Q
			FROM		@t_Validation	V	
			INNER JOIN	@working_Q		Q	ON	V.MatrixID = Q.MatrixID		
											OR	(
													V.MatrixID IS NULL 
												AND Q.MatrixID IS NULL 
												)	
			--
			WHERE		V.D_IsDiagonal = 1	
			--
			;	

			--
			--

			DELETE FROM	@t_Validation ; 

			--
			--	

		END		

		--
		--

		INSERT INTO @QRFactorization_Result 
		(
			MatrixID 
		,	Result	
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]		
		)	
		
			SELECT	X.MatrixID 
			,		X.Result	
			,		X.RowNumber 
			,		X.ColumnNumber 
			,		X.[Value]		
			--	
			FROM	math.fcn_Matrix_QRFactorization ( @working_D )	X	
			--
			;	

		--
		--

		DELETE FROM @current_Q ; 
		DELETE FROM @current_R ; 

		--
		--

		INSERT INTO @current_Q	
		(
			MatrixID 
		,	RowNumber
		,	ColumnNumber
		,	[Value]		
		)	

			SELECT	X.MatrixID 
			,		X.RowNumber
			,		X.ColumnNumber
			,		X.[Value]		
			--	
			FROM	@QRFactorization_Result		X	
			WHERE	X.Result = 'Q Matrix' 
			--
			;	
			
		INSERT INTO @current_R	
		(
			MatrixID 
		,	RowNumber
		,	ColumnNumber
		,	[Value]		
		)	

			SELECT	X.MatrixID 
			,		X.RowNumber
			,		X.ColumnNumber
			,		X.[Value]		
			--	
			FROM	@QRFactorization_Result		X	
			WHERE	X.Result = 'R Matrix' 
			--
			;	

		--
		--

		DELETE FROM @QRFactorization_Result ; 
		DELETE FROM @working_D ; 
		
		--
		--
			
		INSERT INTO @working_D	
		(
			MatrixID 
		,	RowNumber
		,	ColumnNumber
		,	[Value]		
		)	

			SELECT	X.MatrixID 
			,		X.RowNumber
			,		X.ColumnNumber
			,		X.[Value]		
			--	
			FROM	math.fcn_Matrix_Product ( @current_R , @current_Q )	 X	
			--
			;	

		--
		--

		UPDATE		X	
		SET			X.[Value] = P.[Value] 
		FROM		@working_Q	X	
		INNER JOIN	math.fcn_Matrix_Product ( @working_Q , @current_Q )	 P	
						ON  ( 
								X.MatrixID = P.MatrixID 
							OR	(
									X.MatrixID IS NULL 
								AND P.MatrixID IS NULL 
								)	
							) 
						--
						AND X.RowNumber = P.RowNumber 
						AND X.ColumnNumber = P.ColumnNumber 
						--
		--
		;	

		--
		--

		SET @Iterator += 1 ; 

		--
		--

	END		

	--
	--

		--
		--	Output final calculations 
		--

		INSERT INTO @Output 
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

			SELECT	S.MatrixID		
			--	
			,		S.Result 			
			--		
			,		S.RowNumber		
			,		S.ColumnNumber	
			,		S.[Value]	
			--	
			FROM	@Output_Staging		S	
			--	
			;	

	--
	--

	RETURN 
END
GO

--
--

CREATE FUNCTION [math].[fcn_CorrelationMatrix]  
(
	@RowVectors		math.UTT_MatrixCoordinate  READONLY	
--
)
RETURNS 
@Output TABLE 
(
	MatrixID		int		null		
--
,	RowNumber		int		not null	
,	ColumnNumber	int		not null	
--
,	[Value]			float	null	
--
,	UNIQUE  (
				MatrixID	
			-- 
			,	RowNumber		
			,	ColumnNumber	
			--					
			) 
)
AS
/**************************************************************************************

	Returns the Correlation Matrix for a given input list of row vectors. 

		The Correlation Matrix can be obtained from the Covariance Matrix, 
		 by dividing each (i,j)-coordinate 
			by the standard deviations of the i & j variables.  

		Alternatively, the Correlation Matrix is the Covariance Matrix 
		 of the 'standardized' variables [ X_i / sigma_p(X_i) ] 
		  where sigma_p represents the population standard deviation. 


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

				VALUES		( 1 , 1 , 1.00 )	,	( 1 , 2 , 0.00 )	,	( 1 , 3 , 0.00 )	
				,			( 2 , 1 , 0.00 )	,	( 2 , 2 , 1.00 )	,	( 2 , 3 , 0.00 )	
				,			( 3 , 1 , 0.00 )	,	( 3 , 2 , 0.00 )	,	( 3 , 3 , 1.00 )	
				;	

			--
			--
			
			SELECT		X.*	
			--	
			FROM		math.fcn_CorrelationMatrix ( @Test_RowVectors ) X 
			--	
			ORDER BY	X.RowNumber
			,			X.ColumnNumber	
			--	
			;		

			--
			--

	Date			Action	
	----------		----------------------------
	2019-04-08		Created initial version (based on math.fcn_CovarianceMatrix).	

**************************************************************************************/	
BEGIN
	
	--
	--
	
		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
	
	--
	--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @RowVectors , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

	--
	--

		DECLARE @ColumnMeans TABLE 
		(
			ID				int		not null	identity(1,1)	primary key		
		--
		,	MatrixID		int		null 
		,	ColumnNumber	int		not null	
		--
		,	MeanValue		float	not null	
		--
		,	StdDevP			float	not null	
		--	
		)	
		--
		;

	--
	--
	
		--
		--	Compute column means	
		--

		INSERT INTO @ColumnMeans 
		(	
			MatrixID	
		,	ColumnNumber	
		--
		,	MeanValue	
		--
		,	StdDevP 
		--	
		) 

			SELECT		V.MatrixID	
			,			V.ColumnNumber	
			--
			,			AVG( V.[Value] )		--	MeanValue	
			--
			,			STDEVP( V.[Value] )		--	StdDevP		
			--
			FROM		@RowVectors		V
			--		
			GROUP BY	V.MatrixID	
			,			V.ColumnNumber	
			--
			;	

	--
	--
	
		--
		--	Compute and return output covariance matrices  
		--

		INSERT INTO @Output 
		(
			MatrixID		
		--					
		,	RowNumber		
		,	ColumnNumber	
		--					
		,	[Value]			
		--	
		) 

			SELECT		V.MatrixID	
			--	
			,			V.ColumnNumber 
			,			X.ColumnNumber 
			--
			,			SUM ( ( V.[Value] - C.MeanValue ) * ( X.[Value] - D.MeanValue ) 
								/ CASE WHEN C.StdDevP = 0.00 
									   OR   D.StdDevP = 0.00 
									   OR	C.StdDevP * D.StdDevP = 0.00	
									   THEN convert(float,1.00)
									   ELSE C.StdDevP * D.StdDevP 
								  END )
						/ convert(float,COUNT(*))		--	Value	
			--
			FROM		@RowVectors		V	
			--	
			INNER JOIN	@ColumnMeans	C	ON	V.ColumnNumber = C.ColumnNumber 
											AND (
													V.MatrixID = C.MatrixID 
												OR	(
														V.MatrixID IS NULL 
													AND C.MatrixID IS NULL	
													)	
												)	
			INNER JOIN	@ColumnMeans	D	ON	C.MatrixID = D.MatrixID 
											OR	(
													C.MatrixID IS NULL 
												AND D.MatrixID IS NULL	
												)	
			--	
			INNER JOIN	@RowVectors		X	ON	D.ColumnNumber = X.ColumnNumber 
											AND V.RowNumber = X.RowNumber 
											AND (
													D.MatrixID = X.MatrixID		
												OR	(
														D.MatrixID IS NULL 
													AND X.MatrixID IS NULL	
													)	
												)	
			--		
			GROUP BY	V.MatrixID	
			--	
			,			V.ColumnNumber 
			,			X.ColumnNumber 
			--
			;	

	--
	--

	RETURN 
END

GO

--
--

CREATE FUNCTION [math].[fcn_CovarianceMatrix]  
(
	@RowVectors		math.UTT_MatrixCoordinate  READONLY	
--
)
RETURNS 
@Output TABLE 
(
	MatrixID		int		null		
--
,	RowNumber		int		not null	
,	ColumnNumber	int		not null	
--
,	[Value]			float	null	
--
,	UNIQUE  (
				MatrixID	
			-- 
			,	RowNumber		
			,	ColumnNumber	
			--					
			) 
)
AS
/**************************************************************************************

	Returns the Covariance Matrix for a given input list of row vectors. 


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

				VALUES		( 1 , 1 , 1.00 )	,	( 1 , 2 , 0.00 )	,	( 1 , 3 , 0.00 )	
				,			( 2 , 1 , 0.00 )	,	( 2 , 2 , 1.00 )	,	( 2 , 3 , 0.00 )	
				,			( 3 , 1 , 0.00 )	,	( 3 , 2 , 0.00 )	,	( 3 , 3 , 1.00 )	
				;	

			--
			--
			
			SELECT		X.*	
			--	
			FROM		math.fcn_CovarianceMatrix ( @Test_RowVectors ) X 
			--	
			ORDER BY	X.RowNumber
			,			X.ColumnNumber	
			--	
			;		

			--
			--

	Date			Action	
	----------		----------------------------
	2018-11-04		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--
	
		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
	
	--
	--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @RowVectors , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

	--
	--

		DECLARE @ColumnMeans TABLE 
		(
			ID				int		not null	identity(1,1)	primary key		
		--
		,	MatrixID		int		null 
		,	ColumnNumber	int		not null	
		--
		,	MeanValue		float	not null	
		--	
		)	
		--
		;

	--
	--
	
		--
		--	Compute column means	
		--

		INSERT INTO @ColumnMeans 
		(	
			MatrixID	
		,	ColumnNumber	
		--
		,	MeanValue	
		--	
		) 

			SELECT		V.MatrixID	
			,			V.ColumnNumber	
			--
			,			AVG( V.[Value] )	--	MeanValue	
			--
			FROM		@RowVectors		V
			--		
			GROUP BY	V.MatrixID	
			,			V.ColumnNumber	
			--
			;	

	--
	--
	
		--
		--	Compute and return output covariance matrices  
		--

		INSERT INTO @Output 
		(
			MatrixID		
		--					
		,	RowNumber		
		,	ColumnNumber	
		--					
		,	[Value]			
		--	
		) 

			SELECT		V.MatrixID	
			--	
			,			V.ColumnNumber 
			,			X.ColumnNumber 
			--
			--,			AVG ( ( V.[Value] - C.MeanValue ) * ( X.[Value] - D.MeanValue ) )	
			,			SUM ( ( V.[Value] - C.MeanValue ) * ( X.[Value] - D.MeanValue ) )	
					*	( convert(float,1.00) / convert(float,COUNT(*)-1) )					--	Value	
			--
			FROM		@RowVectors		V	
			--	
			INNER JOIN	@ColumnMeans	C	ON	V.ColumnNumber = C.ColumnNumber 
											AND (
													V.MatrixID = C.MatrixID 
												OR	(
														V.MatrixID IS NULL 
													AND C.MatrixID IS NULL	
													)	
												)	
			INNER JOIN	@ColumnMeans	D	ON	C.MatrixID = D.MatrixID 
											OR	(
													C.MatrixID IS NULL 
												AND D.MatrixID IS NULL	
												)	
			--	
			INNER JOIN	@RowVectors		X	ON	D.ColumnNumber = X.ColumnNumber 
											AND V.RowNumber = X.RowNumber 
											AND (
													D.MatrixID = X.MatrixID		
												OR	(
														D.MatrixID IS NULL 
													AND X.MatrixID IS NULL	
													)	
												)	
			--		
			GROUP BY	V.MatrixID	
			--	
			,			V.ColumnNumber 
			,			X.ColumnNumber 
			--
			;	

	--
	--

	RETURN 
END

GO

--
--

CREATE FUNCTION [math].[fcn_LinearSystemSolution]  
(
	@Input_AugmentedMatrix  math.UTT_MatrixCoordinate  READONLY	
)
RETURNS 
@Output TABLE 
(
	MatrixID		int		null		
--
,	ColumnNumber	int		not null	
,	[Value]			float	not null	
--
,	UNIQUE  (
				MatrixID	
			-- 
			,	ColumnNumber	
			) 
)
AS
/**************************************************************************************

	Returns a solution vector for one or more systems of linear equations, 
		each given as an augmented matrix. 

	If there are no solutions, or if the solution is not unique, 
		no values will be returned. 

		
		Example:	

			--
			--
			
			DECLARE	@Test AS math.UTT_MatrixCoordinate ; 

			INSERT INTO @Test 
			(	
				RowNumber
			,	ColumnNumber 
			,	[Value] 
			)	

				VALUES		( 1 , 1 , 5.00 )	,	( 1 , 2 , 3.00 )	,	( 1 , 3 , 8.00 )	
				,			( 2 , 1 , 2.00 )	,	( 2 , 2 , 7.00 )	,	( 2 , 3 , 4.00 )	
				;	
			
			SELECT		X.MatrixID		
			,			X.ColumnNumber	
			,			X.[Value]			
			FROM		math.fcn_LinearSystemSolution ( @Test ) X 
			ORDER BY	X.MatrixID	
			,			X.ColumnNumber	
			;		

			--
			--

	Date			Action	
	----------		----------------------------
	2015-12-15		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
	
	--
	--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_AugmentedMatrix , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

	--
	--

	DECLARE  @MaxIterations	 int 
	,		 @Iterator		 int		
	--	
	;	

	--	
	-- 
	
	DECLARE @Row_Echelon_Input_Matrix TABLE 
	(
		ID					int			not null	identity(1,1)	primary key 
	--
	,	MatrixID			int			null	
	--
	,	RowNumber			int			not null 
	,	ColumnNumber		int			not null 
	,	[Value]				float		not null	
	--
	,	UNIQUE	(
					MatrixID	
				--	
				,	RowNumber		
				,	ColumnNumber	
				)	
	)	
	;

	DECLARE @Matrix_ColumnCount TABLE 
	(
		ID				int			not null	identity(1,1)	primary key 
	--
	,	MatrixID		int			null		unique	
	,	ColumnCount		int			not null	
	)	
	;

	--
	--

		DECLARE @Deletion_ZeroRow TABLE 
		(
			ID			int		not null	identity(1,1)	primary key 
		--
		,	MatrixID	int		null	
		,	RowNumber	int		not null	
		--
		,	UNIQUE	(	
						MatrixID	
					,	RowNumber	
					)	
		)	
		;	

	--
	--

		DECLARE @Loop_LeadingCoefficients TABLE 
		(
			ID				int		not null	identity(1,1)	primary key 
		--
		,	MatrixID		int		null	
		,	ColumnNumber	int		not null	
		--
		,	[Value]			float	not null 
		--
		,	UNIQUE	( 
						MatrixID		
					,	ColumnNumber	
					)	
		)	
		;	

		DECLARE	@Loop_FinalColumn TABLE 
		(
			ID				int		not null	identity(1,1)	primary key 
		--
		,	MatrixID		int		null		unique	
		--
		,	[Value]			float	not null 
		)	
		;

	--
	--

	DECLARE @Output_Staging	TABLE 
	(
		ID				int		not null	identity(1,1)	primary key 
	--
	,	MatrixID		int		null		
	-- 
	,	ColumnNumber	int		not null	
	,	[Value]			float	not null	
	--
	,	UNIQUE  (
					MatrixID		
				--	
				,	ColumnNumber	
				) 
	)	
	;	

	--
	--

		--
		--	Convert input augmented matrices to row echelon form 
		--	

	--
	--

	INSERT INTO @Row_Echelon_Input_Matrix  
	(
		MatrixID			
	--
	,	RowNumber			
	,	ColumnNumber		
	,	[Value]				
	) 

		SELECT		X.MatrixID	
		--
		,			X.RowNumber 
		,			X.ColumnNumber 
		,			X.[Value]		
		FROM		math.fcn_Matrix_RowEchelonForm ( @Input_AugmentedMatrix ) X 
		;	

	--
	--
	
		INSERT INTO @Matrix_ColumnCount 	
		(
			MatrixID	
		,	ColumnCount 
		)	

			SELECT		N.MatrixID				
			,			MAX(N.ColumnNumber)		ColumnCount	
			FROM		@Row_Echelon_Input_Matrix	N	
			GROUP BY	N.MatrixID	
			;

	--
	--

		--
		--	Delete records related to systems without unique solutions 
		--	
	
	--
	--

		/*

			If the number of rows with non-zero coordinates before the last column 
			 is less than the number of columns before the last column, 
			 any solution is at best non-unique. 
			
		*/	
	
	DELETE		M 
	FROM		@Row_Echelon_Input_Matrix	M	
	INNER JOIN	@Matrix_ColumnCount			C	ON	M.MatrixID = C.MatrixID 
												AND (
														M.MatrixID IS NULL 
													OR	C.MatrixID IS NULL 
													)	
	LEFT  JOIN	(
					SELECT		T.MatrixID 
					,			COUNT(*)	NonZeroRowCount		
					FROM		(
									SELECT		Z.MatrixID 
									,			Z.RowNumber 
									FROM		@Matrix_ColumnCount			Y	
									INNER JOIN	@Row_Echelon_Input_Matrix	Z	ON	Y.MatrixID = Z.MatrixID 
																				OR	(
																						Y.MatrixID IS NULL 
																					AND Z.MatrixID IS NULL 
																					)	
									WHERE		Z.ColumnNumber < Y.ColumnCount 
									GROUP BY	Z.MatrixID 
									,			Z.RowNumber 
									HAVING		SUM(CASE WHEN Z.[Value] != 0 THEN 1 ELSE 0 END) > 0 
								)	
									T	
					GROUP BY	T.MatrixID	
				)	
					X	ON	M.MatrixID = X.MatrixID		
						OR	(
								M.MatrixID IS NULL 
							AND X.MatrixID IS NULL 
							)	
	WHERE		coalesce(X.NonZeroRowCount,0) < C.ColumnCount - 1 
	;	

	--
	--

		/*

			If there is a row whose only non-zero value is in the final column, 
				there is no solution to the associated system. 
		
		*/	

		INSERT INTO @Deletion_ZeroRow	
		(
			MatrixID 
		,	RowNumber	
		)	

			SELECT		Z.MatrixID 
			,			Z.RowNumber 
			FROM		@Row_Echelon_Input_Matrix	M	
			INNER JOIN	@Matrix_ColumnCount			C	ON	(
																M.MatrixID = C.MatrixID 
															OR	(
																	M.MatrixID IS NULL 
																AND C.MatrixID IS NULL 
																)	
															)
														AND M.ColumnNumber = C.ColumnCount 
														AND M.[Value] != 0 
			INNER JOIN	@Row_Echelon_Input_Matrix	Z	ON	(
																M.MatrixID = Z.MatrixID 
															OR	(
																	M.MatrixID IS NULL 
																AND Z.MatrixID IS NULL 
																)	
															)
														AND M.RowNumber = Z.RowNumber 
														AND Z.ColumnNumber < C.ColumnCount 
			GROUP BY	Z.MatrixID 
			,			Z.RowNumber 
			HAVING		MAX(ABS(Z.[Value])) = 0 
			;

	DELETE		N 
	FROM		@Row_Echelon_Input_Matrix	N	
	INNER JOIN	(	
					SELECT	distinct  X.MatrixID 
					FROM	@Deletion_ZeroRow
									X	
				)	
					D	ON	N.MatrixID = D.MatrixID 
						OR	(
								N.MatrixID IS NULL 
							AND D.MatrixID IS NULL 
							)	
	;	

		DELETE FROM @Deletion_ZeroRow 
		;	

	--
	--
	
		/*

			Delete all coordinates which are not in the final column 
				and have value zero - these are unnecessary for calculating solution vectors. 
			
		*/	

	DELETE		M 
	FROM		@Row_Echelon_Input_Matrix	M	
	INNER JOIN	@Matrix_ColumnCount			C	ON	M.MatrixID = C.MatrixID 
												OR	(
														M.MatrixID IS NULL 
													AND C.MatrixID IS NULL 
													)	
	WHERE		M.ColumnNumber < C.ColumnCount 
	AND			M.[Value] = 0 
	;

	--
	--
	
		--
		--	Delete obsolete column count information 
		--

	--
	--

		DELETE		C 
		FROM		@Matrix_ColumnCount			C	
		LEFT  JOIN	@Row_Echelon_Input_Matrix	M	ON	C.MatrixID = M.MatrixID 
													OR	(
															C.MatrixID IS NULL 
														AND M.MatrixID IS NULL 
														)	
		WHERE		M.[Value] IS NULL 
		; 
		
	--
	--

		--
		--	Prepare to calculate vector solutions 
		--
	
	--
	--
		 
	SELECT	@MaxIterations = MAX(M.RowNumber)	
	FROM	@Row_Echelon_Input_Matrix	M	
	;	

	SET @Iterator = 1 
	;	

	--
	--

		--
		--	Run calculation loop 
		--	

	--
	--

	WHILE	@Iterator <= @MaxIterations 
	BEGIN 
		
		--
		--	Summarize information on current row 
		--	

		INSERT INTO @Loop_LeadingCoefficients 
		(
			MatrixID 
		,	ColumnNumber 
		,	[Value]	
		)	

			SELECT		M.MatrixID 
			,			M.ColumnNumber 
			,			M.[Value] 
			FROM		@Row_Echelon_Input_Matrix	M	
			INNER JOIN	@Matrix_ColumnCount			C	ON	M.MatrixID = C.MatrixID 
														OR	(
																M.MatrixID IS NULL 
															AND C.MatrixID IS NULL 
															)	
			WHERE		M.ColumnNumber < C.ColumnCount 
			AND			M.RowNumber = @MaxIterations - @Iterator + 1 
			AND			M.[Value] != 0 
			;	

		INSERT INTO @Loop_FinalColumn	
		(
			MatrixID 
		,	[Value]	
		)	

			SELECT		M.MatrixID 
			,			M.[Value] 
			FROM		@Row_Echelon_Input_Matrix	M	
			INNER JOIN	@Matrix_ColumnCount			C	ON	M.MatrixID = C.MatrixID 
														OR	(
																M.MatrixID IS NULL 
															AND C.MatrixID IS NULL 
															)	
			WHERE		M.ColumnNumber = C.ColumnCount 
			AND			M.RowNumber = @MaxIterations - @Iterator + 1 
			;	


		--
		--	Compute solution vector coordinate 
		--	

		INSERT INTO @Output_Staging 
		(
			MatrixID		
		,	ColumnNumber	
		,	[Value]			
		)	

			SELECT		C.MatrixID 
			,			C.ColumnNumber 
			,			( F.[Value] - coalesce(S.[Value],0) ) / C.[Value] 
			FROM		@Loop_LeadingCoefficients	C	
			INNER JOIN	@Loop_FinalColumn			F	ON	(
																C.MatrixID = F.MatrixID 
															OR	(
																	C.MatrixID IS NULL 
																AND F.MatrixID IS NULL 
																)	
															) 
														AND C.ColumnNumber = @MaxIterations - @Iterator + 1 
			LEFT  JOIN	(
							SELECT		D.MatrixID	
							,			SUM(D.[Value]*O.[Value])	[Value] 
							FROM		@Loop_LeadingCoefficients	D	
							INNER JOIN	@Output_Staging				O	ON	(
																				D.MatrixID = O.MatrixID 
																			OR	(
																					D.MatrixID IS NULL 
																				AND O.MatrixID IS NULL 
																				)	
																			)	
																		AND	D.ColumnNumber = O.ColumnNumber 
							GROUP BY	 D.MatrixID 
						)	
							S	ON	(
										C.MatrixID = S.MatrixID 
									OR	(
											C.MatrixID IS NULL 
										AND S.MatrixID IS NULL 
										)	
									) 
			;	

		--
		--

		DELETE FROM @Loop_LeadingCoefficients ; 
		DELETE FROM @Loop_FinalColumn ; 

		--
		--

		SET @Iterator += 1 ; 

	END		

	--
	--

		--
		--	Output final calculations 
		--

		INSERT INTO @Output 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	[Value]	
		)	

			SELECT		S.MatrixID 
			--
			,			S.ColumnNumber 
			,			S.[Value]		
			FROM		@Output_Staging		S	
			;	

	--
	--

	RETURN 
END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Solves linear systems of equations provided as augmented matrices, using row-reduction' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_LinearSystemSolution'
--GO

--
--

CREATE FUNCTION [math].[fcn_SimpleLinearRegression]
(
	@Input_Pairs	   math.UTT_OrderedPair  READONLY
)
RETURNS TABLE 
AS 
/**************************************************************************************

	Returns simple linear regression results for provided lists of ordered pairs. 

	Explanatory variable values are the "X" Values and dependent variable values are "Y". 

	 
		Example:	

			--
			--
			
		DECLARE	@Input_Pairs AS math.UTT_OrderedPair ; 

		INSERT INTO @Input_Pairs ( ListID , X_Value , Y_Value ) 

			VALUES	( 1 , 1 , 1 )	
			,		( 1 , 2 , 1 )	
			,		( 1 , 3 , 1 )	
			,		( 1 , 4 , 1 )	
			,		( 1 , 5 , 1 )	
			--	
			,		( 2 , 1 , 1.11 )	
			,		( 2 , 2 , 1.99 )	
			,		( 2 , 3 , 3.12 )	
			,		( 2 , 4 , 3.98 )	
			,		( 2 , 5 , 5.13 )	
			-- 
			,		( 3 , 1 , 1.41 )	
			,		( 3 , 2 , 5.41 )	
			,		( 3 , 3 , 1.41 )	
			,		( 3 , 4 , 5.41 )	
			,		( 3 , 5 , 5.41 )	
			-- 
			;	

		--
		--

			SELECT		X.* 
			--	
			FROM		math.fcn_SimpleLinearRegression ( @Input_Pairs )	X	
			--
			ORDER BY	X.ListID	ASC	
			--
			;	
			
			--
			--

	Date			Action	
	----------		----------------------------
	2018-06-16		Created initial version.	
	
**************************************************************************************/	
RETURN	
(   --
	--
	--	
WITH cte_MainResult AS 
( 
SELECT		R.ListID	
--
,			R.NumberOfInputPairs		
,			R.Distinct_X_Values		
,			R.Distinct_Y_Values		
--			
,			R.Slope					
,			R.Y_Intercept				
,			R.R_Squared				
--	
FROM	( 

			SELECT	A.ListID	
			--
			,		A.NumberOfInputPairs 
			,		A.Distinct_X_Values		
			,		A.Distinct_Y_Values		
			--
			,		CASE WHEN B.Slope_Denominator != 0.0000	
						 THEN B.Slope_Numerator	
							  / B.Slope_Denominator 
						 ELSE null 
					END															as	Slope	
			--
			,		CASE WHEN B.Slope_Denominator != 0.0000	
						 THEN ( A.Sum_X_Squared*A.Sum_Y - A.Sum_X*A.Sum_XY )		
							  / B.Slope_Denominator 
						 ELSE null 
					END															as	Y_Intercept			
			--
			,		CASE WHEN B.Slope_Denominator != 0.0000	
						 AND  B.R_Squared_Denominator2 != 0.0000 
						 --
						 AND  ( B.Slope_Denominator * B.R_Squared_Denominator2 ) != 0.0000 
						 --
						 THEN B.Slope_Numerator	* B.Slope_Numerator 	
							  / ( B.Slope_Denominator * B.R_Squared_Denominator2 ) 
						 ELSE null 
					END															as	R_Squared			
			--	
			FROM	(
						SELECT		X.ListID	
						--
						,			convert(float, COUNT(*) )					  NumberOfInputPairs	
						,			convert(float, COUNT(DISTINCT(X.X_Value)) )	  Distinct_X_Values	
						,			convert(float, COUNT(DISTINCT(X.Y_Value)) )	  Distinct_Y_Values	
						--
						,			SUM( X.X_Value )				Sum_X	
						,			SUM( X.Y_Value )				Sum_Y	
						--	
						,			SUM( X.X_Value * X.X_Value )	Sum_X_Squared	
						,			SUM( X.Y_Value * X.Y_Value )	Sum_Y_Squared		
						,			SUM( X.X_Value * X.Y_Value )	Sum_XY		
						--	
						FROM		@Input_Pairs	X	
						--	
						GROUP BY	X.ListID	
						--	
					)	
						A	
			--
			OUTER APPLY		(
								SELECT	( A.NumberOfInputPairs*A.Sum_X_Squared - A.Sum_X*A.Sum_X ) 
									as	Slope_Denominator			
								--
								,		( A.NumberOfInputPairs*A.Sum_XY - A.Sum_X*A.Sum_Y )		
									as	Slope_Numerator		
								--
								,		( A.NumberOfInputPairs*A.Sum_Y_Squared - A.Sum_Y*A.Sum_Y ) 
									as	R_Squared_Denominator2	
								--	
							)	
								B	
			--
		)	
			R		
)	--
	--
	--	
	SELECT		R.ListID	
	--		
	,			try_convert(int, R.NumberOfInputPairs )   as  NumberOfInputPairs
	,			try_convert(int, R.Distinct_X_Values  )	  as  Distinct_X_Values 
	,			try_convert(int, R.Distinct_Y_Values  )	  as  Distinct_Y_Values 
	--			
	,			R.Slope					
	,			R.Y_Intercept				
	,			R.R_Squared		
	--
	,			E.Sum_SquaredError / R.NumberOfInputPairs		as	MeanSquaredError		
	,			E.Sum_AbsoluteError / R.NumberOfInputPairs		as	MeanAbsoluteError	
	--		
	FROM		cte_MainResult		R	
	--
	LEFT  JOIN	(	
					SELECT		Rs.ListID	
					--
					,			SUM ( Es.Error * Es.Error )		as	Sum_SquaredError		
					--	
					,			SUM ( ABS( Es.Error ) )			as	Sum_AbsoluteError		
					--	
					FROM		cte_MainResult	 Rs	
					INNER JOIN	@Input_Pairs	 Xs	  ON  Rs.ListID = Xs.ListID	
													  OR  (
															  Rs.ListID IS NULL 
														  AND Xs.ListID IS NULL		
														  ) 
					--
					OUTER APPLY	(
									SELECT	Xs.Y_Value
										-	( Rs.Slope * Xs.X_Value + Rs.Y_Intercept ) 
										as	Error	
								)	
									Es
					--	
					WHERE		Rs.Slope IS NOT NULL 
					AND			Rs.Y_Intercept IS NOT NULL	
					--	
					GROUP BY	Rs.ListID	
				)	
					E	ON	R.ListID = E.ListID		
						OR  (
							    R.ListID IS NULL 
							AND E.ListID IS NULL		
							) 
    --
    --
)   --	
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns Simple Linear Regression analysis/results for input observations' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_SimpleLinearRegression'
--GO

--
--

CREATE FUNCTION [math].[fcn_MultipleLinearRegression]
(
	@Input_Matrix_Explanatory  math.UTT_MatrixCoordinate  READONLY
,	@Input_Matrix_Dependent	   math.UTT_MatrixCoordinate  READONLY
)
RETURNS 
@Output TABLE 
(
	MatrixID	int		null	
--	
,	ResultID	int		null	
,	[Value]		float	null	
--	
UNIQUE	(	
			MatrixID	
		--	
		,	ResultID	
		)	
)
AS 
/**************************************************************************************

	Returns the coefficient vector which represents the least-squares best fit 
	 for a provided series of explanatory and dependent variable values. 

	Explanatory variable values are provided as a matrix 
	 with each ROW representing one set of readings 
	 corresponding to the same ROW value dependent variable measurement 
	  in the input column vector of dependent variable values. 

	In the result set, the ResultID corresponds to the ColumnNumber values
	 in the explanatory variable input matrix for any positive value. 
	 The value for ResultID of 0 is the R-squared measurement for the regression. 

	 
		Example:	

			--
			--
			
		DECLARE	@Test_Explanatory AS math.UTT_MatrixCoordinate ; 

		INSERT INTO @Test_Explanatory ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

			VALUES	( 1 , 1 , 1 , 5.4 )		,	( 1 , 1 , 2 , 7.2 )		,	( 1 , 1 , 3 , 7.2 )	
			,		( 1 , 2 , 1 , 3.1 )		,	( 1 , 2 , 2 , 6.9 )		,	( 1 , 2 , 3 , 6.9 )
			,		( 1 , 3 , 1 , 4.8 )		,	( 1 , 3 , 2 , 2.7 )		,	( 1 , 3 , 3 , 1.8 )
			,		( 1 , 4 , 1 , 4.9 )		,	( 1 , 4 , 2 , 5.1 )		,	( 1 , 4 , 3 , 0.2 )
			,		( 1 , 5 , 1 , 4.8 )		,	( 1 , 5 , 2 , 2.7 )		,	( 1 , 5 , 3 , 1.8 )
			-- 
			;	

		DECLARE @Test_Dependent AS math.UTT_MatrixCoordinate ; 
		
		INSERT INTO @Test_Dependent ( MatrixID , RowNumber , ColumnNumber , [Value] ) 

			VALUES	( 1 , 1 , 1 , 29.232 )
			,		( 1 , 2 , 1 , 23.864 )
			,		( 1 , 3 , 1 , 11.508 )
			,		( 1 , 4 , 1 , -4.388 )
			,		( 1 , 5 , 1 , 11.508 )	
			--
			;	

		--
		--

			SELECT		X.MatrixID	
			,			X.ResultID 
			,			X.[Value] 
			FROM		math.fcn_MultipleLinearRegression ( @Test_Explanatory , @Test_Dependent )	X	
			ORDER BY	X.MatrixID	ASC	
			,			X.ResultID  ASC 
			;	
			
			--
			--

	Date			Action	
	----------		----------------------------
	2016-05-15		Created initial version.	
	
**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix_Explanatory , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		
		IF math.fcn_Matrix_IntegrityCheck ( @Input_Matrix_Dependent , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

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
								SELECT distinct	 X.MatrixID 
											,	 X.RowNumber 
								FROM	@Input_Matrix_Explanatory	X	
							)
														 A	
					FULL JOIN	@Input_Matrix_Dependent	 B	ON	(
																	A.MatrixID = B.MatrixID 
																OR	(
																		A.MatrixID IS NULL 
																	AND B.MatrixID IS NULL 
																	)		
																)	
															AND A.RowNumber = B.RowNumber 
					WHERE	A.RowNumber IS NULL 
					OR		B.RowNumber IS NULL		)	
		BEGIN 

			RETURN 

		END		

	--
	--	

		--
		--	Calculate least-squares solution vector 
		--

		DECLARE @t_Explanatory_Transpose AS math.UTT_MatrixCoordinate ; 
		DECLARE @t_Explanatory_ProductOfTransposeAndOriginal AS math.UTT_MatrixCoordinate ; 
		DECLARE @t_Explanatory_ProductOfTransposeAndOriginal_Inverse AS math.UTT_MatrixCoordinate ; 
		DECLARE @t_Explanatory_FinalStepLeftOperator AS math.UTT_MatrixCoordinate ; 


		INSERT INTO @t_Explanatory_Transpose 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		)	
			SELECT	X.MatrixID 
			,		X.RowNumber 
			,		X.ColumnNumber 
			,		X.[Value] 
			FROM	math.fcn_Matrix_Transpose ( @Input_Matrix_Explanatory ) X 
			;	


		INSERT INTO @t_Explanatory_ProductOfTransposeAndOriginal 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		)	
			SELECT	X.MatrixID 
			,		X.RowNumber 
			,		X.ColumnNumber 
			,		X.[Value] 
			FROM	math.fcn_Matrix_Product ( @t_Explanatory_Transpose , @Input_Matrix_Explanatory ) X 
			;	


		INSERT INTO @t_Explanatory_ProductOfTransposeAndOriginal_Inverse 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		)	
			SELECT	X.MatrixID 
			,		X.RowNumber 
			,		X.ColumnNumber 
			,		X.[Value] 
			FROM	math.fcn_Matrix_Inverse ( @t_Explanatory_ProductOfTransposeAndOriginal ) X 
			;	

			
		INSERT INTO @t_Explanatory_FinalStepLeftOperator 
		(
			MatrixID 
		,	RowNumber 
		,	ColumnNumber 
		,	[Value] 
		)	
			SELECT	X.MatrixID 
			,		X.RowNumber 
			,		X.ColumnNumber 
			,		X.[Value] 
			FROM	math.fcn_Matrix_Product ( @t_Explanatory_ProductOfTransposeAndOriginal_Inverse , @t_Explanatory_Transpose ) X 
			;	

		
		--
		--
		--


		INSERT INTO @Output 
		(
			MatrixID 
		,	ResultID 
		,	[Value] 
		)	

			SELECT	X.MatrixID 
			,		X.RowNumber 
			,		X.[Value]		
			FROM	math.fcn_Matrix_Product ( @t_Explanatory_FinalStepLeftOperator , @Input_Matrix_Dependent ) X 
			;	
		


		--
		--	Calculate R-squared value 
		--


		INSERT INTO @Output 
		(
			MatrixID 
		,	ResultID 
		,	[Value] 
		) 

			SELECT		X.MatrixID 
			,			0 
			,		CASE WHEN MAX( ABS(Y.[Value]) ) =  0 
						 THEN NULL 
						 ELSE SUM( X.RegressionPrediction * X.RegressionPrediction )
							/ SUM( Y.[Value] * Y.[Value] )
					END		
					-- 
					as	R_Squared	--	this is one of multiple "R_Squared" analogues for multilinear regression 
					--	
			FROM		(
							SELECT		E.MatrixID 
							,			E.RowNumber
							,			SUM( O.[Value] * E.[Value] )	RegressionPrediction 
							FROM		@Output						O	
							INNER JOIN	@Input_Matrix_Explanatory	E	ON	(
																				O.MatrixID = E.MatrixID 
																			OR	(
																					O.MatrixID IS NULL 
																				AND E.MatrixID IS NULL 
																				)	
																			) 
																		AND O.ResultID = E.ColumnNumber 
							GROUP BY	E.MatrixID 
							,			E.RowNumber 
						)
													X	
			INNER JOIN	@Input_Matrix_Dependent		Y	ON	(
																X.MatrixID = Y.MatrixID 
															OR	(
																	X.MatrixID IS NULL 
																AND Y.MatrixID IS NULL 
																)	 
															)	
														AND X.RowNumber = Y.RowNumber 
			GROUP BY	X.MatrixID 
			;	

	--
	--

	RETURN 
END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Performs multiple-linear regression on input data-sets.' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_MultipleLinearRegression'
--GO

--
--

CREATE FUNCTION [math].[fcn_Interpolation_CubicSpline]   
(
	@Input_Pairs   math.UTT_OrderedPair   READONLY	
,	@SplineType	   varchar(10)			  -- 'Natural' or 'Not-A-Knot'	
)
RETURNS 
@Output TABLE 
(
	ListID			int		null		
--
,	Min_X_Value		float	not null 
,	Max_X_Value		float	not null 
--
,	A_Coefficient	float	not null 
,	B_Coefficient	float	not null 
,	C_Coefficient	float	not null 
,	D_Coefficient	float	not null 
--
,	UNIQUE  (
				ListID		
			--				
			,	Min_X_Value	
			) 
,	UNIQUE  (
				ListID		
			--				
			,	Max_X_Value	
			) 
)
AS
/**************************************************************************************

	Returns a set of intervals and parameters defining 
		piecewise components of a cubic spline function based on 
		 an interpolation of provided input coordinate pairs. 
		
		 
	Each 'piece' takes the form  
		
			S_i (x) = a_i (x - x_i)^3 + b_i (x - x_i)^2 + c_i (x - x_i) + d_i  
		
	   for all x in an interval [x_i , x_(i+1)] .	
	

	An input list of ordered pairs must have at least 3 distinct measurements for 
		the 'X_Value' field in order for a 'Natural' cubic spline to be derived, 
		 and at least 4 distinct measurements to define a 'Not-A-Knot' cubic spline.  

		
		Example:	

			--
			--

			DECLARE @Test AS math.UTT_OrderedPair ; 
			INSERT INTO @Test 
			(
				X_Value 
			,	Y_Value		
			) 
			VALUES		( 1.00 , 5.00 )		
			,			( 2.00 , 7.00 )		
			,			( 3.00 , 12.00 )	
			,			( 5.00 , 15.00 )	
			,			( 7.00 , 19.00 )	
			;	

			SELECT		X.ListID			
			--
			,			X.Min_X_Value		
			,			X.Max_X_Value		
			--
			,			X.A_Coefficient		
			,			X.B_Coefficient		
			,			X.C_Coefficient		
			,			X.D_Coefficient		
			FROM		math.fcn_Interpolation_CubicSpline ( @Test , 'Not-A-Knot' ) X 
			--
			ORDER BY	X.ListID		ASC 
			,			X.Min_X_Value	ASC		
			--	
			;	
				
			--	
			--	
				
	Date			Action	
	----------		----------------------------
	2015-12-15		Created initial version.	
	2016-01-08		Replaced 'POWER' function with repeated multiplication (improves result decimal precision). 

**************************************************************************************/	
BEGIN
	
	--
	--

	DECLARE		@SplineType_Natural		varchar(10)		=	'Natural' 
	,			@SplineType_NotAKnot	varchar(10)		=	'Not-A-Knot'	
	--	
	;	

	--
	--

		IF @SplineType IS NULL 
		BEGIN 
			--
			--	if @SplineType is not provided, default to @SplineType_Natural 
			--
			SET @SplineType = @SplineType_Natural
		END 
		IF @SplineType NOT IN ( @SplineType_Natural , @SplineType_NotAKnot )	
		BEGIN 
			--
			--	unexpected @SplineType value 
			--
			RETURN ; 
		END		

	--
	--

		DECLARE		@MaxIteration	int		=	4	
		,			@Iterator		int		=	1	
		--	
		;	

	--
	--

		DECLARE @Internal_Pairs	TABLE 
		(
			ID			int		not null	identity(1,1)	primary key 
		--
		,	ListID		int		null	
		,	RankInList	int		not null	
		,	X_Value		float	not null	
		,	Y_Value		float	not null	
		--
		,	UNIQUE	(
						ListID		
					,	RankInList		
					)	
		,	UNIQUE	(
						ListID		
					,	X_Value		
					)	
		)	
		;

		DECLARE @ListStatistics TABLE 
		(
			ID					int		not null	identity(1,1)	primary key 
		--
		,	ListID				int		null		
		,	PairCount			int		not null	
		)	
		;

			--
			--

				DECLARE @LinearSystem_Augmented_Matrix AS math.UTT_MatrixCoordinate 
				;	

			--
			--

		DECLARE @LinearSystem_SolutionVector TABLE 
		(
			ID				int		not null	identity(1,1)	primary key 
		--	
		,	MatrixID		int		null		
		,	ColumnNumber	int		not null	
		--	
		,	[Value]			float	not	null	
		--
		,	UNIQUE  (
						MatrixID		
					,	ColumnNumber	
					)	
		) 
		;

		DECLARE @Output_Staging TABLE 
		(
			ListID			int		null		
		--
		,	Min_X_Value		float	not null 
		,	Max_X_Value		float	not null 
		--
		,	A_Coefficient	float	not null 
		,	B_Coefficient	float	not null 
		,	C_Coefficient	float	not null 
		,	D_Coefficient	float	not null 
		--
		,	UNIQUE  (
						ListID		
					--				
					,	Min_X_Value	
					) 
		,	UNIQUE  (
						ListID		
					--				
					,	Max_X_Value	
					) 
		)
		;	

	--
	--
	
		--
		--	Gather input pairs with averaged Y_Value for each X_Value 
		--

		INSERT INTO @Internal_Pairs		
		(
			ListID 
		,	RankInList 
		,	X_Value 
		,	Y_Value		
		)	

			SELECT		X.ListID	
			,			RANK() OVER ( PARTITION BY	X.ListID		
									  ORDER BY		X.X_Value ASC )			
			,			X.X_Value	
			,			X.Y_Value	
			FROM		(
							SELECT		P.ListID		
							,			P.X_Value		
							,			AVG(P.Y_Value)	Y_Value 
							FROM		@Input_Pairs	P			
							GROUP BY	P.ListID		
							,			P.X_Value	
						)	
							X	
			;			
		
		INSERT INTO @ListStatistics 
		(
			ListID 
		,	PairCount 
		)	
			
			SELECT		P.ListID			
			,			MAX(P.RankInList)	
			FROM		@Internal_Pairs		P	
			GROUP BY	P.ListID			
			HAVING		(
							COUNT(*) >= 3 
						AND @SplineType = @SplineType_Natural
						) 
			OR			(
							COUNT(*) >= 4 
						AND @SplineType = @SplineType_NotAKnot 
						)	
			;	

		--
		--

		DELETE		P	 
		FROM		@Internal_Pairs		P	
		LEFT  JOIN	@ListStatistics		L	ON	P.ListID = L.ListID		
											OR	(
													P.ListID IS NULL 
												AND L.ListID IS NULL 
												)	
		WHERE		L.ID IS NULL 
		;	

	--
	--

		--
		--	Define systems of linear equations 
		--

		IF @SplineType = @SplineType_Natural
		BEGIN 
			--
			--	second derivative is zero at first point 
			--	
			INSERT INTO @LinearSystem_Augmented_Matrix 
			(
				MatrixID	
			,	RowNumber 
			,	ColumnNumber 
			,	[Value]	
			)	

			SELECT		P.ListID 
			,			1 
			,			Y.ColumnNumber 
			,			Y.[Value] 
			FROM		@Internal_Pairs		P	
			INNER JOIN	@ListStatistics		L	ON	(
														P.ListID = L.ListID 
													OR	(
															P.ListID IS NULL 
														AND L.ListID IS NULL 
														)	
													)	
												AND P.RankInList = 1 
			CROSS APPLY (
							SELECT	X.ColumnNumber 
							,		X.[Value] 
							FROM	(
										VALUES	(  2  ,	 convert(float,2.0)  )	
										--						
										,		(  ( L.PairCount - 1 ) * 4 + 1	 ,	convert(float,0.0)  )		
									)	
										X	( ColumnNumber , [Value] )	
						)
							Y		
			;	

			--
			--	second derivative is zero at last point 
			--	
			INSERT INTO @LinearSystem_Augmented_Matrix 
			(
				MatrixID	
			,	RowNumber 
			,	ColumnNumber 
			,	[Value]	
			)	

			SELECT		P.ListID 
			,			2  
			,			Y.ColumnNumber 
			,			Y.[Value] 
			FROM		@Internal_Pairs		P	
			INNER JOIN	@ListStatistics		L	ON	(
														P.ListID = L.ListID 
													OR	(
															P.ListID IS NULL 
														AND L.ListID IS NULL 
														)	
													)	
												AND P.RankInList = L.PairCount 
			INNER JOIN	@Internal_Pairs		Q	ON	(
														P.ListID = Q.ListID 
													OR	(
															P.ListID IS NULL 
														AND Q.ListID IS NULL 
														)	
													)	
												AND Q.RankInList = P.RankInList - 1 
			CROSS APPLY (
							SELECT	X.ColumnNumber 
							,		X.[Value] 
							FROM	(
										VALUES	( ( L.PairCount - 2 ) * 4 + 1  ,  convert(float,6.0) * (P.X_Value - Q.X_Value) ) 
										,		( ( L.PairCount - 2 ) * 4 + 2  ,  convert(float,2.0) ) 
										--									  	  
										,		( ( L.PairCount - 1 ) * 4 + 1  ,  convert(float,0.0) )		
									)	
										X	( ColumnNumber , [Value] )	
						)
							Y		
			;	

		END		

		--
		--

		IF @SplineType = @SplineType_NotAKnot
		BEGIN 
			--
			--	third derivatives of piecewise components agree at second point 
			--	
			INSERT INTO @LinearSystem_Augmented_Matrix 
			(
				MatrixID	
			,	RowNumber 
			,	ColumnNumber 
			,	[Value]	
			)	

			SELECT		P.ListID 
			,			1 
			,			Y.ColumnNumber 
			,			Y.[Value] 
			FROM		@Internal_Pairs		P	
			INNER JOIN	@ListStatistics		L	ON	(
														P.ListID = L.ListID 
													OR	(
															P.ListID IS NULL 
														AND L.ListID IS NULL 
														)	
													)	
												AND P.RankInList = 1 
			CROSS APPLY (
							SELECT	X.ColumnNumber 
							,		X.[Value] 
							FROM	(
										VALUES	( 1 , convert(float, 1.0) )	
										,		( 5 , convert(float,-1.0) )	
										--
										,		(  ( L.PairCount - 1 ) * 4 + 1	 ,	convert(float,0.0)  ) 
									)	
										X	( ColumnNumber , [Value] )	
						)
							Y		
			;	
			
			--
			--	third derivatives of piecewise components agree at second-last point 
			--	
			INSERT INTO @LinearSystem_Augmented_Matrix 
			(
				MatrixID	
			,	RowNumber 
			,	ColumnNumber 
			,	[Value]	
			)	

			SELECT		P.ListID 
			,			2  
			,			Y.ColumnNumber 
			,			Y.[Value] 
			FROM		@Internal_Pairs		P	
			INNER JOIN	@ListStatistics		L	ON	(
														P.ListID = L.ListID 
													OR	(
															P.ListID IS NULL 
														AND L.ListID IS NULL 
														)	
													)	
												AND P.RankInList = 1 
			CROSS APPLY (
							SELECT	X.ColumnNumber 
							,		X.[Value] 
							FROM	(
										VALUES	(  ( L.PairCount - 3 ) * 4 + 1	 ,  convert(float, 1.0)	 )	
										,		(  ( L.PairCount - 2 ) * 4 + 1	 ,  convert(float,-1.0)	 )	
										--																 
										,		(  ( L.PairCount - 1 ) * 4 + 1	 ,	convert(float, 0.0)	 )	
									)	
										X	( ColumnNumber , [Value] )	
						)
							Y		
			;	
			
		END		

		--
		--

		--
		--	constraints for values at input coordinates 
		--

		INSERT INTO @LinearSystem_Augmented_Matrix 
		(
			MatrixID	
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]	
		)	

		SELECT		P.ListID 
		,			2 + P.RankInList 
		,			Y.ColumnNumber 
		,			Y.[Value] 
		FROM		@Internal_Pairs		P	
		INNER JOIN	@ListStatistics		L	ON	(
													P.ListID = L.ListID 
												OR	(
														P.ListID IS NULL 
													AND L.ListID IS NULL 
													)	
												)	
											AND P.RankInList < L.PairCount 
		CROSS APPLY (
						SELECT	X.ColumnNumber 
						,		X.[Value] 
						FROM	(
									VALUES	(  P.RankInList * 4  ,  convert(float,1.0)  )	
									--	
									,		(  ( L.PairCount - 1 ) * 4 + 1	 ,	P.Y_Value  )	
								)	
									X	( ColumnNumber , [Value] )	
					)
						Y	
		;		
		
		INSERT INTO @LinearSystem_Augmented_Matrix 
		(
			MatrixID	
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]	
		)	

		SELECT		P.ListID 
		,			2 + ( L.PairCount - 1 ) + P.RankInList - 1 
		,			Y.ColumnNumber 
		,			Y.[Value] 
		FROM		@Internal_Pairs		P	
		INNER JOIN	@ListStatistics		L	ON	(
													P.ListID = L.ListID 
												OR	(
														P.ListID IS NULL 
													AND L.ListID IS NULL 
													)	
												)	
											AND P.RankInList > 1 
		INNER JOIN	@Internal_Pairs		Q	ON	(
													P.ListID = Q.ListID 
												OR	(
														P.ListID IS NULL 
													AND Q.ListID IS NULL 
													)	
												)	
											AND Q.RankInList = P.RankInList - 1 
		CROSS APPLY (
						SELECT	X.ColumnNumber 
						,		X.[Value] 
						FROM	(
									VALUES	(  Q.RankInList * 4 - 3 ,  (P.X_Value - Q.X_Value)*(P.X_Value - Q.X_Value)*(P.X_Value - Q.X_Value) ) 
									,		(  Q.RankInList * 4 - 2 ,  (P.X_Value - Q.X_Value)*(P.X_Value - Q.X_Value) ) 
									,		(  Q.RankInList * 4 - 1 ,  (P.X_Value - Q.X_Value)	) 
									,		(  Q.RankInList * 4     ,  convert(float, 1.0)	) 
									--	
									,		(  ( L.PairCount - 1 ) * 4 + 1	 ,	P.Y_Value  )	
								)	
									X	( ColumnNumber , [Value] )	
					)
						Y		
		;		

		
		--
		--	constraints for first derivative continuity 
		--

		INSERT INTO @LinearSystem_Augmented_Matrix 
		(
			MatrixID	
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]	
		)	

		SELECT		P.ListID 
		,			2 + 2 * ( L.PairCount - 1 ) + P.RankInList - 1 
		,			Y.ColumnNumber 
		,			Y.[Value] 
		FROM		@Internal_Pairs		P	
		INNER JOIN	@ListStatistics		L	ON	(
													P.ListID = L.ListID 
												OR	(
														P.ListID IS NULL 
													AND L.ListID IS NULL 
													)	
												)	
											AND P.RankInList > 1 
											AND P.RankInList < L.PairCount 
		INNER JOIN	@Internal_Pairs		Q	ON	(
													P.ListID = Q.ListID 
												OR	(
														P.ListID IS NULL 
													AND Q.ListID IS NULL 
													)	
												)	
											AND Q.RankInList = P.RankInList - 1 
		CROSS APPLY (
						SELECT	X.ColumnNumber 
						,		X.[Value] 
						FROM	(
									VALUES	(  Q.RankInList * 4 - 3 ,  convert(float,3.0) * (P.X_Value - Q.X_Value)*(P.X_Value - Q.X_Value) ) 
									,		(  Q.RankInList * 4 - 2 ,  convert(float,2.0) * (P.X_Value - Q.X_Value) ) 
									,		(  Q.RankInList * 4 - 1 ,  convert(float, 1.0)  ) 
									,		(  P.RankInList * 4 - 1 ,  convert(float,-1.0)  ) 
									--	
									,		(  ( L.PairCount - 1 ) * 4 + 1	 ,	convert(float,0.0)  )	
								)	
									X	( ColumnNumber , [Value] )	
					)
						Y		
		;		


		--
		--	constraints for second derivative continuity 
		--

		INSERT INTO @LinearSystem_Augmented_Matrix 
		(
			MatrixID	
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]	
		)	

		SELECT		P.ListID 
		,			2 + 2 * ( L.PairCount - 1 ) + ( L.PairCount - 2 ) + P.RankInList - 1 
		,			Y.ColumnNumber 
		,			Y.[Value] 
		FROM		@Internal_Pairs		P	
		INNER JOIN	@ListStatistics		L	ON	(
													P.ListID = L.ListID 
												OR	(
														P.ListID IS NULL 
													AND L.ListID IS NULL 
													)	
												)	
											AND P.RankInList > 1 
											AND P.RankInList < L.PairCount 
		INNER JOIN	@Internal_Pairs		Q	ON	(
													P.ListID = Q.ListID 
												OR	(
														P.ListID IS NULL 
													AND Q.ListID IS NULL 
													)	
												)	
											AND Q.RankInList = P.RankInList - 1 
		CROSS APPLY (
						SELECT	X.ColumnNumber 
						,		X.[Value] 
						FROM	(
									VALUES	(  Q.RankInList * 4 - 3 , convert(float, 6.0) * (P.X_Value - Q.X_Value) ) 
									,		(  Q.RankInList * 4 - 2 , convert(float, 2.0) ) 
									,		(  P.RankInList * 4 - 2 , convert(float,-2.0) ) 
									--	
									,		(  ( L.PairCount - 1 ) * 4 + 1  ,  convert(float,0.0)  ) 
								)	
									X	( ColumnNumber , [Value] )	
					)
						Y		
		;		

	--
	--

		--
		--	all constraints have been included 
		--

		--
		--	fill in missing coordinates with zero values 
		--	
	
	--
	--
		
		INSERT INTO @LinearSystem_Augmented_Matrix	
		(
			MatrixID	
		,	RowNumber 
		,	ColumnNumber 
		,	[Value]	
		)	

			SELECT		X.MatrixID	
			,			X.RowNumber 
			,			Y.ColumnNumber	
			,			0	
			FROM		(
							SELECT	distinct	M.MatrixID	
							,					M.RowNumber		
							FROM	@LinearSystem_Augmented_Matrix	M	
						)	
							X	
			INNER JOIN	(
							SELECT	distinct	M.MatrixID	
							,					M.ColumnNumber			
							FROM	@LinearSystem_Augmented_Matrix	M	
						)	
							Y	ON	X.MatrixID = Y.MatrixID		
								OR	(
										X.MatrixID IS NULL 
									AND Y.MatrixID IS NULL  
									)	
			LEFT  JOIN	@LinearSystem_Augmented_Matrix	Z	ON	(
																	X.MatrixID = Z.MatrixID		
																OR	(
																		X.MatrixID IS NULL 
																	AND Z.MatrixID IS NULL  
																	)	
																)	
															AND X.RowNumber = Z.RowNumber 
															AND Y.ColumnNumber = Z.ColumnNumber 
			WHERE		Z.[Value] IS NULL 
			;	

	--
	--

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
		--	Also check for zero rows: there should not be any, otherwise 
		--	 the associated system is unsolvable. 
		--
	
	--
	--

		IF math.fcn_Matrix_IntegrityCheck ( @LinearSystem_Augmented_Matrix , 1 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

	--
	--
		
		INSERT INTO @LinearSystem_SolutionVector	
		(
			MatrixID	
		--	
		,	ColumnNumber 
		,	[Value]	
		)	

			SELECT		X.MatrixID		
			--			
			,			X.ColumnNumber	
			,			X.[Value]			
			FROM		math.fcn_LinearSystemSolution ( @LinearSystem_Augmented_Matrix ) X	
			;	

	--
	--

		INSERT INTO @Output_Staging		
		(
			ListID				
		--
		,	Min_X_Value		
		,	Max_X_Value		
		--
		,	A_Coefficient	
		,	B_Coefficient	
		,	C_Coefficient	
		,	D_Coefficient
		)	

			SELECT		P.ListID 
			--
			,			P.X_Value 
			,			Q.X_Value 
			--
			,			SUM(CASE WHEN L.CoefficientLetter = 'A' THEN X.Value ELSE 0 END)
			,			SUM(CASE WHEN L.CoefficientLetter = 'B' THEN X.Value ELSE 0 END)
			,			SUM(CASE WHEN L.CoefficientLetter = 'C' THEN X.Value ELSE 0 END)
			,			SUM(CASE WHEN L.CoefficientLetter = 'D' THEN X.Value ELSE 0 END)
			FROM		@LinearSystem_SolutionVector	 X 
			INNER JOIN	@Internal_Pairs					 P	ON	(
																	X.MatrixID = P.ListID 
																OR	(
																		X.MatrixID IS NULL 
																	AND P.ListID IS NULL 
																	)	
																)	
															AND X.ColumnNumber IN ( P.RankInList * 4 - 3 
																				  , P.RankInList * 4 - 2 
																				  , P.RankInList * 4 - 1 
																				  , P.RankInList * 4 )	
			CROSS APPLY (
							SELECT	CASE P.RankInList * 4 - X.ColumnNumber 
										WHEN 3 THEN 'A' 
										WHEN 2 THEN 'B' 
										WHEN 1 THEN 'C' 
										WHEN 0 THEN 'D' 
									END					as	CoefficientLetter 
						)	
											L	
			INNER JOIN	@Internal_Pairs		Q	ON	(
														P.ListID = Q.ListID 
													OR	(
															P.ListID IS NULL 
														AND Q.ListID IS NULL 
														)	
													)	
												AND P.RankInList = Q.RankInList - 1 
			GROUP BY	P.ListID 
			--
			,			P.X_Value 
			,			Q.X_Value 
			;	

	--
	--

		--
		--	Output final calculations 
		--
	
	--
	--

		INSERT INTO @Output 
		(
			ListID				
		--
		,	Min_X_Value		
		,	Max_X_Value		
		--
		,	A_Coefficient	
		,	B_Coefficient	
		,	C_Coefficient	
		,	D_Coefficient
		)	

			SELECT		S.ListID				
			--
			,			S.Min_X_Value		
			,			S.Max_X_Value		
			--
			,			S.A_Coefficient	
			,			S.B_Coefficient	
			,			S.C_Coefficient	
			,			S.D_Coefficient
			FROM		@Output_Staging		S	
			;	

	--
	--

	RETURN 
END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Sub-routine to calculate Cubic Spline interpolation functions based on input series. Includes ‘Natural’ or ‘Not-A-Knot’ spline types.' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Interpolation_CubicSpline'
--GO

--
--

CREATE FUNCTION [math].[fcn_Interpolation_PiecewiseLinear]   
(
	@Input_Pairs   math.UTT_OrderedPair   READONLY	
)
RETURNS 
@Output TABLE 
(
	ListID			int		null		
--
,	Min_X_Value		float	not null 
,	Max_X_Value		float	not null 
--
,	Slope			float	not null 
,	Y_Intercept		float	not null 
--
,	UNIQUE  (
				ListID		
			--				
			,	Min_X_Value	
			) 
,	UNIQUE  (
				ListID		
			--				
			,	Max_X_Value	
			) 
)
AS
/**************************************************************************************

	Returns a set of intervals and parameters defining 
		components of a piecewise linear function passing through
		 the set of provided input coordinate pairs. 
		
		 
		Example:	

			--
			--

			DECLARE @Test AS math.UTT_OrderedPair ; 
			INSERT INTO @Test 
			(
				X_Value 
			,	Y_Value		
			) 
			VALUES		( 1.00 , 5.00 )		
			,			( 2.00 , 7.00 )		
			,			( 3.00 , 12.00 )	
			,			( 5.00 , 15.00 )	
			,			( 7.00 , 19.00 )	
			;	

			SELECT		X.ListID			
			--
			,			X.Min_X_Value		
			,			X.Max_X_Value		
			--
			,			X.Slope 
			,			X.Y_Intercept 
			FROM		math.fcn_Interpolation_PiecewiseLinear ( @Test ) X 
			ORDER BY	X.ListID		ASC 
			,			X.Min_X_Value	ASC		
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2015-12-15		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--

		DECLARE @Internal_Pairs	TABLE 
		(
			ID			int		not null	identity(1,1)	primary key 
		--
		,	ListID		int		null	
		,	RankInList	int		not null	
		,	X_Value		float	not null	
		,	Y_Value		float	not null	
		--
		,	UNIQUE	(
						ListID		
					,	RankInList		
					)	
		,	UNIQUE	(
						ListID		
					,	X_Value		
					)	
		)	
		;	

		DECLARE @ListStatistics TABLE 
		(
			ID					int		not null	identity(1,1)	primary key 
		--
		,	ListID				int		null		
		,	PairCount			int		not null	
		)	
		;
		
		DECLARE @Output_Staging TABLE 
		(
			ListID			int		null		
		--
		,	Min_X_Value		float	not null 
		,	Max_X_Value		float	not null 
		--
		,	Slope			float	not null 
		,	Y_Intercept		float	not null 
		--
		,	UNIQUE  (
						ListID		
					--				
					,	Min_X_Value	
					) 
		,	UNIQUE  (
						ListID		
					--				
					,	Max_X_Value	
					) 
		)	
		;	

	--
	--
	
		--
		--	Gather input pairs with averaged Y_Value for each X_Value 
		--

	--
	--

		INSERT INTO @Internal_Pairs		
		(
			ListID 
		,	RankInList 
		,	X_Value 
		,	Y_Value		
		)	

			SELECT		X.ListID	
			,			RANK() OVER ( PARTITION BY	X.ListID		
									  ORDER BY		X.X_Value ASC )			
			,			X.X_Value	
			,			X.Y_Value	
			FROM		(
							SELECT		P.ListID		
							,			P.X_Value		
							,			AVG(P.Y_Value)	Y_Value 
							FROM		@Input_Pairs	P			
							GROUP BY	P.ListID		
							,			P.X_Value	
						)	
							X	
			;			
		
		INSERT INTO @ListStatistics 
		(
			ListID 
		,	PairCount 
		)	
			
			SELECT		P.ListID			
			,			MAX(P.RankInList)	
			FROM		@Internal_Pairs		P	
			GROUP BY	P.ListID			
			HAVING		COUNT(*) >= 2 
			;	

		--
		--

		DELETE		P	 
		FROM		@Internal_Pairs		P	
		LEFT  JOIN	@ListStatistics		L	ON	P.ListID = L.ListID		
											OR	(
													P.ListID IS NULL 
												AND L.ListID IS NULL 
												)	
		WHERE		L.ID IS NULL 
		;	

	--
	--

		--
		--	define linear components of output function 
		--

	--
	--

		INSERT INTO @Output_Staging		
		(
			ListID				
		--
		,	Min_X_Value		
		,	Max_X_Value		
		--
		,	Slope 
		,	Y_Intercept 
		)	

			SELECT		P.ListID 
			--
			,			P.X_Value 
			,			Q.X_Value 
			--
			,			X.Slope 
			,			P.Y_Value - X.Slope * P.X_Value 
			FROM		@Internal_Pairs		P	
			INNER JOIN	@ListStatistics		S	ON	(
														P.ListID = S.ListID 
													OR	(
															P.ListID IS NULL 
														AND S.ListID IS NULL 
														)	
													)	
												AND P.RankInList < S.PairCount 
			INNER JOIN	@Internal_Pairs		Q	ON	(
														P.ListID = Q.ListID 
													OR	(
															P.ListID IS NULL 
														AND Q.ListID IS NULL 
														)	
													)	
												AND P.RankInList = Q.RankInList - 1 
			CROSS APPLY (
							SELECT	( Q.Y_Value - P.Y_Value ) / ( Q.X_Value - P.X_Value ) 
								as	Slope	
						)	
							X	
			;	
			
	--
	--

		--
		--	Output final calculations 
		--

	--
	--

		INSERT INTO @Output 
		(
			ListID				
		--
		,	Min_X_Value		
		,	Max_X_Value		
		--
		,	Slope 	
		,	Y_Intercept 
		)	

			SELECT		S.ListID				
			--
			,			S.Min_X_Value		
			,			S.Max_X_Value		
			--
			,			S.Slope 
			,			S.Y_Intercept 
			FROM		@Output_Staging		S	
			;	

	--
	--

	RETURN 
END
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Sub-routine to calculate Piecewise Linear interpolation functions based on input series.' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_Interpolation_PiecewiseLinear'
--GO

--
--

CREATE FUNCTION [math].[fcn_InterpolationEvaluation]  
(
	@Input_Pairs					 math.UTT_OrderedPair   READONLY	
,	@Input_List						 math.UTT_ListElement   READONLY	
,	@InterpolationMethod_ShortName	 varchar(10)			  
,	@ExtrapolationMethod_ShortName	 varchar(10)			  
)
RETURNS 
@Output TABLE 
(
	ListID					int		null		
--
,	X_Value					float	not null	
--
,	Interpolated_Y_Value	float	not null	
--
,	UNIQUE  (
				ListID		
			--				
			,	X_Value	
			) 
)
AS
/**************************************************************************************

	  Returns evaluated interpolation values for a given 
		input pair list, interpolation method, and 
		 list of requested points for evaluation. 

		
		Example:	

			--
			--

			DECLARE @Test_InputPairs AS math.UTT_OrderedPair ; 
			INSERT INTO @Test_InputPairs 
			(
				X_Value 
			,	Y_Value		
			) 
			VALUES		( 1.00 , 5.00 )		
			,			( 2.00 , 7.00 )		
			,			( 3.00 , 12.00 )	
			,			( 5.00 , 15.00 )	
			,			( 7.00 , 19.00 )	
			;	

			DECLARE @Test_InputList AS math.UTT_ListElement ; 
			INSERT INTO @Test_InputList 
			(
				X_Value		
			)	
			VALUES	( 0.50 ) 
			,		( 1.00 ) 
			,		( 1.50 ) 
			,		( 1.75 ) 
			,		( 2.50 ) 
			,		( 4.33 ) 
			,		( 6.19 ) 
			,		( 7.50 ) 
			;	

			SELECT		X.ListID	
			,			X.X_Value 
			,			X.Interpolated_Y_Value	
			FROM		math.fcn_InterpolationEvaluation ( @Test_InputPairs   --  Input_Pairs					
														 , @Test_InputList 	  --  Input_List						
														 , 'PL'				  --  InterpolationMethod_ShortName	
														 , 'F'				  --  ExtrapolationMethod_ShortName	
														 )		X	 
			ORDER BY	X.ListID	ASC		
			,			X.X_Value	ASC		
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2016-01-08		Created initial version. 
	2016-06-22		Using new 'FastNaturalCubicSpline' function for Natural Cubic Spline. 
	2017-08-31		Re-wrote condition query for final "IF EXISTS" check to improve speed. 
	2017-12-21		Added @ExtrapolationMethod_ShortName parameter. 
	2018-03-09		Handling duplicate X values in input pairs for extreme first and last points (respecting extrapolation table unique constraints).

**************************************************************************************/	
BEGIN
	
	--
	--

		DECLARE		@InterpolationMethod_ShortName_PiecewiseLinear		varchar(10)	 =  'PL' 
		,			@InterpolationMethod_ShortName_NaturalCubicSpline	varchar(10)	 =	'CSN'	
		,			@InterpolationMethod_ShortName_NotAKnotCubicSpline	varchar(10)	 =	'CSNAK'	
		--
		,			@CubicSpline_Type				varchar(10)		
		--
		,			@CubicSpline_Type_Natural		varchar(10)		=	'Natural' 
		,			@CubicSpline_Type_NotAKnot		varchar(10)		=	'Not-A-Knot'	
		--
		--
		,			@ExtrapolationMethod_ShortName_Flat			varchar(10)		=	'F'		
		,			@ExtrapolationMethod_ShortName_Linear		varchar(10)		=	'L'		
		--
		--
		; 

		--
		--	set default extrapolation method 
		--
		IF @ExtrapolationMethod_ShortName IS NULL 
		BEGIN 
			SET @ExtrapolationMethod_ShortName = @ExtrapolationMethod_ShortName_Flat ;
		END		
		
	--
	--

		--
		--	do not rely on interpolation sub-routines to perform any extrapolation during this application
		--	 ( adjust output request point list to exclude points before first or after last input interpolation points ) 
		--	
		DECLARE	@Input_List_NoExtrapolation	AS math.UTT_ListElement 
		--
		;	
		
	--
	--

	DECLARE @Output_Staging TABLE 
	(
		ID						int		not null	identity(1,1)	primary key		
	--
	,	ListID					int		null		
	--
	,	X_Value					float	not null	
	--
	,	Interpolated_Y_Value	float	not null	
	--
	,	UNIQUE  (
					ListID		
				--				
				,	X_Value	
				) 
	)

	--
	--

	DECLARE @ExtremaBeforeExtrapolation TABLE 
	(
		ID					int		not null	identity(1,1)	primary key		
	--
	,	ListID				int		null		unique	
	--
	,	Minimum_X_Value		float	not null	
	,	Maximum_X_Value		float	not null	
	--	
	)	
	
	DECLARE @ExtrapolationInput_Early TABLE 
	(
		ID				int		not null	identity(1,1)	primary key		
	--
	,	ListID			int		null		unique	
	--
	,	First_X_1		float 	not null	
	,	First_Y_1		float 	not null	
	,	First_X_2	 	float 	null	
	,	First_Y_2		float	null	
	--	
	)	

	DECLARE @ExtrapolationInput_Late TABLE 
	(
		ID				int		not null	identity(1,1)	primary key		
	--
	,	ListID			int		null		unique	
	--
	,	Last_X_1		float 	not null	
	,	Last_Y_1		float 	not null	
	,	Last_X_2	 	float 	null	
	,	Last_Y_2		float	null	
	--	
	)	

	--
	--

		--
		--	Return an empty table if the input @InterpolationMethod_ShortName is unrecognized 
		--

	--
	--

		IF ( SELECT COUNT(*) FROM math.InterpolationMethod M WHERE M.ShortName = @InterpolationMethod_ShortName ) = 0 
		BEGIN 
			RETURN	
		END		
		
	--
	--

		--	
		--	Return an empty table if the input @ExtrapolationMethod_ShortName is unrecognized 
		--

		IF ( SELECT COUNT(*) FROM math.ExtrapolationMethod M WHERE M.ShortName = @ExtrapolationMethod_ShortName ) = 0 
		BEGIN 
			RETURN	
		END		

	--
	--	
		
		--
		--	Summarize ranges of provided interpolation points 
		--

			INSERT INTO @ExtremaBeforeExtrapolation 
			(
				ListID				
			--						
			,	Minimum_X_Value		
			,	Maximum_X_Value		
			--						
			)	
	
			SELECT	S.ListID	
			--	
			,		MIN(S.X_Value)	 --  Minimum_X_Value
			,		MAX(S.X_Value)	 --  Maximum_X_Value
			--	
			FROM	@Input_Pairs	S	
			--	
			GROUP BY	S.ListID	
			--	
			;	
	
	--
	--	
		
		--
		--	Exclude requested output points before first or after last input interpolation points
		--

			INSERT INTO @Input_List_NoExtrapolation 
			(
				ListID	
			,	X_Value		
			)	

			SELECT		L.ListID	
			,			L.X_Value	
			--	 
			FROM		@Input_List						L	
			INNER JOIN	@ExtremaBeforeExtrapolation		E	
							ON	L.ListID = E.ListID 
							OR	(	
									L.ListID IS NULL 
								AND E.ListID IS NULL 
								)	
			--
			WHERE		L.X_Value >= E.Minimum_X_Value 
			AND			L.X_Value <= E.Maximum_X_Value 
			--	
			;	

	--
	--
	
		--
		--	Compute interpolation functions and evaluate at input points
		--

	--
	--

		--
		--	Piecewise linear interpolation 
		--
		IF @InterpolationMethod_ShortName = @InterpolationMethod_ShortName_PiecewiseLinear 
		BEGIN 
			
			INSERT INTO @Output_Staging  
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

				SELECT		Y.ListID	
				,			Y.X_Value	
				,			MAX ( X.Slope * Y.X_Value + X.Y_Intercept ) 
				FROM		math.fcn_Interpolation_PiecewiseLinear ( @Input_Pairs ) X 
				INNER JOIN	@Input_List_NoExtrapolation		Y	ON	(		
																		X.ListID = Y.ListID		
																	OR	(	
																			X.ListID IS NULL 
																		AND Y.ListID IS NULL 
																		)	
																	)		
																AND Y.X_Value >= X.Min_X_Value 
																AND Y.X_Value <= X.Max_X_Value 
				GROUP BY	Y.ListID	
				,			Y.X_Value
				;

		END		
		--
		--	Cubic spline interpolation 
		--
			--
			--	2016-06-22 : fast algorithm for Natural cubic spline 
			--		
		ELSE IF @InterpolationMethod_ShortName = @InterpolationMethod_ShortName_NaturalCubicSpline 
		BEGIN 
			
			INSERT INTO @Output_Staging  
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

			SELECT	X.ListID 
			,		X.X_Value 
			,		X.Interpolated_Y_Value 
			FROM	math.fcn_InterpolationEvaluation_FastNaturalCubicSpline	( @Input_Pairs 
																			, @Input_List_NoExtrapolation )		X	
			;	

		END		
			--
			--	2016-06-22 : other types of cubic spline will continue to use the old method
			--	
		ELSE IF @InterpolationMethod_ShortName IN ( @InterpolationMethod_ShortName_NaturalCubicSpline 
												  , @InterpolationMethod_ShortName_NotAKnotCubicSpline ) 
		BEGIN 
			
			SET @CubicSpline_Type = CASE @InterpolationMethod_ShortName 
										WHEN @InterpolationMethod_ShortName_NaturalCubicSpline	THEN @CubicSpline_Type_Natural		
										WHEN @InterpolationMethod_ShortName_NotAKnotCubicSpline	THEN @CubicSpline_Type_NotAKnot		
									END 
		
			INSERT INTO @Output_Staging  
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

				SELECT		Y.ListID	
				,			Y.X_Value	
				,			MAX( X.A_Coefficient * (Y.X_Value - X.Min_X_Value)*(Y.X_Value - X.Min_X_Value)*(Y.X_Value - X.Min_X_Value) 
							   + X.B_Coefficient * (Y.X_Value - X.Min_X_Value)*(Y.X_Value - X.Min_X_Value)
							   + X.C_Coefficient * (Y.X_Value - X.Min_X_Value)	
							   + X.D_Coefficient )
				FROM		math.fcn_Interpolation_CubicSpline ( @Input_Pairs , @CubicSpline_Type ) X 
				INNER JOIN	@Input_List_NoExtrapolation		Y	ON	(	
																		X.ListID = Y.ListID		
																	OR	(
																			X.ListID IS NULL 
																		AND Y.ListID IS NULL 
																		)	
																	)		
																AND Y.X_Value >= X.Min_X_Value 
																AND Y.X_Value <= X.Max_X_Value 
				GROUP BY	Y.ListID	
				,			Y.X_Value	
				;	

		END		
		--
		--
		--

	--
	--	/*** OLD ***/	
	--
/*	--	commented 2017-12-21 :: new extrapolation logic follows below 	
	--	
	--	

	--
	--

		--
		--	Compute missing values using piecewise linear extension of smallest/largest two calculated values 
		--
		IF EXISTS ( SELECT		null 
					FROM		(
									SELECT	distinct  L.ListID	
									--	
									FROM		@Input_List		 L	
									LEFT  JOIN	@Output_Staging	 O	ON	(	
																			L.ListID = O.ListID		
																		OR	(
																				L.ListID IS NULL 
																			AND O.ListID IS NULL 
																			)	
																		)		
																	AND L.X_Value = O.X_Value 
									WHERE	O.Interpolated_Y_Value IS NULL 
								)	
									A	
					INNER JOIN	(
									SELECT		O.ListID 
									FROM		@Output_Staging	 O	
									GROUP BY	O.ListID 
									HAVING		COUNT(*) >= 2 
								)	 
									X	ON	A.ListID = X.ListID 
										OR	(
												A.ListID IS NULL 
											AND X.ListID IS NULL 
											)	
				  ) 
		BEGIN		

			--
			--	Augment @Output_Staging using input pair measurements, for the extension calculation below
			--
			--	These values will not be returned in final @Output table 
			--

			INSERT INTO @Output_Staging		
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	
				SELECT		P.ListID 
				,			P.X_Value 
				,			P.Y_Value 
				FROM		@Input_Pairs		P	
				LEFT  JOIN	@Output_Staging		O	ON	(
															P.ListID = O.ListID  
														OR	(
																P.ListID IS NULL 
															AND O.ListID IS NULL 
															)	
														)	
													AND P.X_Value = O.X_Value 
				WHERE		O.Interpolated_Y_Value IS NULL 
				;	


			--
			--	Add missing values 
			--
			
			INSERT INTO @Output_Staging 
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

				SELECT		A.ListID	
				,			A.X_Value	
				,			CASE WHEN A.X_Value < OA1.X_Value  
								 THEN OA1.Interpolated_Y_Value 
								  +   ( OA1.Interpolated_Y_Value - OA2.Interpolated_Y_Value ) 
									/ ( OA1.X_Value - OA2.X_Value ) 
									* ( A.X_Value - OA1.X_Value ) 
								 WHEN A.X_Value > OD1.X_Value 
								 THEN OD1.Interpolated_Y_Value 
								  +   ( OD1.Interpolated_Y_Value - OD2.Interpolated_Y_Value ) 
									/ ( OD1.X_Value - OD2.X_Value ) 
									* ( A.X_Value - OD1.X_Value ) 
							END 
				FROM		(
								SELECT		L.ListID	
								,			L.X_Value	
								FROM		@Input_List		 L	
								LEFT  JOIN	@Output_Staging  O	ON	(	
																		L.ListID = O.ListID		
																	OR	(
																			L.ListID IS NULL 
																		AND O.ListID IS NULL 
																		)	
																	)		
																AND L.X_Value = O.X_Value 
								WHERE		O.Interpolated_Y_Value IS NULL 
							)	
								A	
				INNER JOIN	(
								SELECT	C.ListID 
								--
								,		SUM(CASE WHEN C.AscRank = 1 THEN C.X_Value ELSE 0 END) X_Value_Asc_1 
								,		SUM(CASE WHEN C.AscRank = 2 THEN C.X_Value ELSE 0 END) X_Value_Asc_2  
								,		SUM(CASE WHEN C.DescRank = 1 THEN C.X_Value ELSE 0 END) X_Value_Desc_1 
								,		SUM(CASE WHEN C.DescRank = 2 THEN C.X_Value ELSE 0 END) X_Value_Desc_2 
								FROM	(
											SELECT		O.ListID 
											,			O.X_Value 
											,			DENSE_RANK() OVER ( PARTITION BY O.ListID	
																			ORDER BY O.X_Value ASC ) AscRank 
											,			DENSE_RANK() OVER ( PARTITION BY O.ListID	
																			ORDER BY O.X_Value DESC ) DescRank 
											FROM		@Output_Staging		O	
										)	
											C
								GROUP BY	C.ListID 
								HAVING		COUNT(*) >= 2 
							)	
								B	ON	A.ListID = B.ListID 
									OR	(
											A.ListID IS NULL 
										AND B.ListID IS NULL 
										)	
					--
				INNER JOIN	@Output_Staging	OA1	ON	(
														B.ListID = OA1.ListID 
													OR	(
															B.ListID IS NULL 
														AND OA1.ListID IS NULL 
														)	
													)	
												AND	B.X_Value_Asc_1 = OA1.X_Value 
				INNER JOIN	@Output_Staging	OA2	ON	(
														B.ListID = OA2.ListID 
													OR	(
															B.ListID IS NULL 
														AND OA2.ListID IS NULL 
														)	
													)	
												AND	B.X_Value_Asc_2 = OA2.X_Value 
				INNER JOIN	@Output_Staging	OD1	ON	(
														B.ListID = OD1.ListID 
													OR	(
															B.ListID IS NULL 
														AND OD1.ListID IS NULL 
														)	
													)	
												AND	B.X_Value_Desc_1 = OD1.X_Value 
				INNER JOIN	@Output_Staging	OD2	ON	(
														B.ListID = OD2.ListID 
													OR	(
															B.ListID IS NULL 
														AND OD2.ListID IS NULL 
														)	
													)	
												AND	B.X_Value_Desc_2 = OD2.X_Value 
				;		

		END		

	--
	--
	
	--
	--
*/	--	// commented 2017-12-21 :: new extrapolation logic follows below 	
	--	
	--	/*** OLD ***/	
	--	
			
	--
	--
	
		--
		--	Extrapolation for output points before the first input point 
		--

	IF EXISTS ( SELECT		null 
				FROM		@ExtremaBeforeExtrapolation		E	
				INNER JOIN	@Input_List						L	ON	E.ListID = L.ListID 
																OR	(
																		E.ListID IS NULL 
																	AND L.ListID IS NULL 
																	)	 
				WHERE		L.X_Value < E.Minimum_X_Value ) 
	BEGIN	
	
		INSERT INTO @ExtrapolationInput_Early 
		(
			ListID			
		--
		,	First_X_1		
		,	First_Y_1		
		--	
		)	

			SELECT		P.ListID 
			--
			,			MIN(P.X_Value)	 -- First_X_1
			,			AVG(P.Y_Value)	 -- First_Y_1
			--
			FROM		@ExtremaBeforeExtrapolation		E	
			INNER JOIN	@Input_Pairs					P	ON	(
																	E.ListID = P.ListID 
																OR	(
																		E.ListID IS NULL 
																	AND P.ListID IS NULL 
																	)	
																) 
															AND E.Minimum_X_Value >= P.X_Value 
			--
			GROUP BY	P.ListID 
			--	
			;	

		--
		--

		IF @ExtrapolationMethod_ShortName = @ExtrapolationMethod_ShortName_Flat 
		BEGIN 
			
			INSERT INTO @Output_Staging		
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

			SELECT		L.ListID 
			,			L.X_Value 
			,			E.First_Y_1 
			--	
			FROM		@ExtrapolationInput_Early	E	
			INNER JOIN	@Input_List					L	ON	(
																E.ListID = L.ListID 
															OR	(
																	E.ListID IS NULL 
																AND L.ListID IS NULL 
																)	
															)	
														AND E.First_X_1 > L.X_Value 
			--
			;	

		END		
		ELSE IF @ExtrapolationMethod_ShortName = @ExtrapolationMethod_ShortName_Linear 
		BEGIN 

			UPDATE		E	
			SET			E.First_X_2 = CASE WHEN P.X_Value < Q.X_Value 
										   THEN P.X_Value 
										   ELSE Q.X_Value 
									  END	
			,			E.First_Y_2 = CASE WHEN P.X_Value < Q.X_Value 
										   THEN P.Y_Value 
										   ELSE Q.Interpolated_Y_Value 
									  END	
			FROM		@ExtrapolationInput_Early	E	
			--	
			OUTER APPLY (
							SELECT	C.X_Value 
							,		AVG(C.Y_Value)	Y_Value 
							--
							FROM	(
										SELECT	MIN(X.X_Value)	Min_X_Value		
										FROM	@Input_Pairs	X
										WHERE	X.X_Value > E.First_X_1 	
										AND		(
													E.ListID = X.ListID 
												OR	(	
														E.ListID IS NULL 
													AND X.ListID IS NULL	
													)	
												)	
									)	
														A	
							INNER JOIN	@Input_Pairs	C	ON	A.Min_X_Value = C.X_Value
															AND (
																	E.ListID = C.ListID		
																OR	(
																		E.ListID IS NULL 
																	AND C.ListID IS NULL	
																	)	
																)	
							GROUP BY  C.X_Value 
						)	
							P	
			--
			OUTER APPLY (
							SELECT	D.X_Value 
							,		D.Interpolated_Y_Value	
							--
							FROM	(
										SELECT	MIN(Z.X_Value)	Min_X_Value			
										FROM	@Output_Staging	 Z	
										WHERE	Z.X_Value > E.First_X_1 
										AND		(
													E.ListID = Z.ListID 
												OR	(	
														E.ListID IS NULL 
													AND Z.ListID IS NULL	
													)	
												)	
									)	
														 B	
							INNER JOIN	@Output_Staging	 D	ON	B.Min_X_Value = D.X_Value
															AND (
																	E.ListID = D.ListID		
																OR	(
																		E.ListID IS NULL 
																	AND D.ListID IS NULL	
																	)	
																)	
						)	
							Q	
			--
			;	

			--
			--
			
			INSERT INTO @Output_Staging		
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

			SELECT		L.ListID 
			,			L.X_Value 
			,			E.First_Y_1 + ( E.First_Y_2 - E.First_Y_1 )
									  / ( E.First_X_2 - E.First_X_1 ) * ( L.X_Value - E.First_X_1 )		
			--	
			FROM		@ExtrapolationInput_Early	E	
			INNER JOIN	@Input_List					L	ON	(
																E.ListID = L.ListID 
															OR	(
																	E.ListID IS NULL 
																AND L.ListID IS NULL 
																)	
															)	
														--	
														AND E.First_X_1 > L.X_Value 
														--	
			--
			WHERE		E.First_X_2 > E.First_X_1 
			-- 
			;	

		END		

	END		

	--
	--

		--
		--	Extrapolation for output points after the last input point 
		--

	IF EXISTS ( SELECT		null 
				FROM		@ExtremaBeforeExtrapolation		E	
				INNER JOIN	@Input_List						L	ON	E.ListID = L.ListID 
																OR	(
																		E.ListID IS NULL 
																	AND L.ListID IS NULL 
																	)	 
				WHERE		L.X_Value > E.Maximum_X_Value ) 
	BEGIN	
	
		INSERT INTO @ExtrapolationInput_Late 
		(
			ListID			
		--
		,	Last_X_1		
		,	Last_Y_1		
		--	
		)	

			SELECT		P.ListID 
			--
			,			MAX(P.X_Value)	
			,			AVG(P.Y_Value)	
			--
			FROM		@ExtremaBeforeExtrapolation		E	
			INNER JOIN	@Input_Pairs					P	ON	(
																	E.ListID = P.ListID 
																OR	(
																		E.ListID IS NULL 
																	AND P.ListID IS NULL 
																	)	
																) 
															AND E.Maximum_X_Value <= P.X_Value 
			--
			GROUP BY	P.ListID 
			--	
			;	

		--
		--

		IF @ExtrapolationMethod_ShortName = @ExtrapolationMethod_ShortName_Flat 
		BEGIN 
			
			INSERT INTO @Output_Staging		
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

			SELECT		L.ListID 
			,			L.X_Value 
			,			E.Last_Y_1 
			--	
			FROM		@ExtrapolationInput_Late	E	
			INNER JOIN	@Input_List					L	ON	(
																E.ListID = L.ListID 
															OR	(
																	E.ListID IS NULL 
																AND L.ListID IS NULL 
																)	
															)	
														AND E.Last_X_1 < L.X_Value 
			--
			;	

		END		
		ELSE IF @ExtrapolationMethod_ShortName = @ExtrapolationMethod_ShortName_Linear 
		BEGIN 

			UPDATE		E	
			SET			E.Last_X_2 = CASE WHEN P.X_Value > Q.X_Value 
										  THEN P.X_Value 
										  ELSE Q.X_Value 
									  END	
			,			E.Last_Y_2 = CASE WHEN P.X_Value > Q.X_Value 
										  THEN P.Y_Value 
										  ELSE Q.Interpolated_Y_Value 
									  END	
			FROM		@ExtrapolationInput_Late	E	
			--	
			OUTER APPLY (
							SELECT	C.X_Value 
							,		AVG(C.Y_Value)	Y_Value		
							--
							FROM	(
										SELECT	MAX(X.X_Value)	Max_X_Value		
										FROM	@Input_Pairs	X
										WHERE	X.X_Value < E.Last_X_1 	
										AND		(
													E.ListID = X.ListID 
												OR	(	
														E.ListID IS NULL 
													AND X.ListID IS NULL	
													)	
												)	
									)	
														A	
							INNER JOIN	@Input_Pairs	C	ON	A.Max_X_Value = C.X_Value
															AND (
																	E.ListID = C.ListID		
																OR	(
																		E.ListID IS NULL 
																	AND C.ListID IS NULL	
																	)	
																)	
							GROUP BY  C.X_Value 
						)	
							P	
			--
			OUTER APPLY (
							SELECT	D.X_Value 
							,		D.Interpolated_Y_Value	
							--
							FROM	(
										SELECT	MAX(Z.X_Value)	Max_X_Value			
										FROM	@Output_Staging	 Z	
										WHERE	Z.X_Value < E.Last_X_1 
										AND		(
													E.ListID = Z.ListID 
												OR	(	
														E.ListID IS NULL 
													AND Z.ListID IS NULL	
													)	
												)	
									)	
														 B	
							INNER JOIN	@Output_Staging	 D	ON	B.Max_X_Value = D.X_Value
															AND (
																	E.ListID = D.ListID		
																OR	(
																		E.ListID IS NULL 
																	AND D.ListID IS NULL	
																	)	
																)	
						)	
							Q	
			--
			;	

			--
			--
			
			INSERT INTO @Output_Staging		
			(
				ListID 
			,	X_Value 
			,	Interpolated_Y_Value 
			)	

			SELECT		L.ListID 
			,			L.X_Value 
			,			E.Last_Y_1 + ( E.Last_Y_1 - E.Last_Y_2 )
								   / ( E.Last_X_1 - E.Last_X_2 ) * ( L.X_Value - E.Last_X_1 )		
			--	
			FROM		@ExtrapolationInput_Late	E	
			INNER JOIN	@Input_List					L	ON	(
																E.ListID = L.ListID 
															OR	(
																	E.ListID IS NULL 
																AND L.ListID IS NULL 
																)	
															)	
														--	
														AND E.Last_X_1 < L.X_Value 
														--	
			--
			WHERE		E.Last_X_2 < E.Last_X_1
			-- 
			;	

		END		

	END		

	--
	--
	--
	--

	--
	--

		--
		--	Prepare final output 
		--

		INSERT INTO @Output		
		(
			ListID 
		,	X_Value 
		,	Interpolated_Y_Value 
		)	
			SELECT		S.ListID 
			,			S.X_Value 
			,			S.Interpolated_Y_Value 
			FROM		@Output_Staging		S	
		/*	--
			--	2017-12-21 :: no longer need this join; not adding extra records to @Output_Staging		
			--	
			INNER JOIN	@Input_List			L	ON	(
														S.ListID = L.ListID 
													OR	(
															S.ListID IS NULL 
														AND L.ListID IS NULL 
														)	
													) 
												AND S.X_Value = L.X_Value	
		*/	--
			--	// 2017-12-21	
			--	
			;	

	--
	--

	RETURN 
END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Takes as input a list of ordered pairs and requested output points, as well as both an interpolation method and extrapolation method. Returns interpolated values for requested output points based on input series.' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_InterpolationEvaluation'
--GO

--
--

CREATE FUNCTION [math].[fcn_InterpolationEvaluation_FastNaturalCubicSpline]  
(
	@Input_Pairs		math.UTT_OrderedPair   READONLY	
,	@Input_List			math.UTT_ListElement   READONLY	
)
RETURNS 
@Output TABLE 
(
	ListID					int		null		
--
,	X_Value					float	not null	
--
,	Interpolated_Y_Value	float	not null	
--
,	UNIQUE  (
				ListID		
			--				
			,	X_Value	
			) 
)
AS
/**************************************************************************************

	  Returns evaluated 'natural cubic spline' interpolation values for a given 
		input pair list and list of requested points for evaluation. 

	  Uses a faster algorithm than the general one used by fcn_Interpolation_CubicSpline:  
		instead of seeking cubic polynomial functions in standard form A + Bx + Cx^2 + Dx^3, 
		we use the 'symmetrical form' A(1-t) + Bt + t(1-t)(C(1-t) + Dt). 
		This way, the linear system to be solved is 'tridiagonal', which implies it can be  
		handled quickly without the usual Gaussian elimination process. 

		
		Example:	

			--
			--

			DECLARE @Test_InputPairs AS math.UTT_OrderedPair ; 
			INSERT INTO @Test_InputPairs 
			(
				X_Value 
			,	Y_Value		
			) 
			VALUES		( 1.00 , 5.00 )		
			,			( 2.00 , 7.00 )		
			,			( 3.00 , 12.00 )	
			,			( 5.00 , 15.00 )	
			,			( 7.00 , 19.00 )	
			;	

			DECLARE @Test_InputList AS math.UTT_ListElement ; 
			INSERT INTO @Test_InputList 
			(
				X_Value		
			)	
			VALUES	( 0.50 ) 
			,		( 1.00 ) 
			,		( 1.50 ) 
			,		( 1.75 ) 
			,		( 2.50 ) 
			,		( 4.33 ) 
			,		( 6.19 ) 
			,		( 7.50 ) 
			;	

			SELECT		X.ListID	
			,			X.X_Value 
			,			X.Interpolated_Y_Value	
			FROM		math.fcn_InterpolationEvaluation_FastNaturalCubicSpline ( @Test_InputPairs 
																				, @Test_InputList )		X	
			ORDER BY	X.ListID	ASC		
			,			X.X_Value	ASC		
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2016-06-22		Created initial version. 
	2017-08-31		Improve speed for @Input_List_internal population by adding @t_DistinctXValues and @t_ConsecutivePairs tables.	

**************************************************************************************/	
BEGIN
	
	--
	--
	
	DECLARE		@Iterator			int 
	,			@MaxIterations		int		
	--
	;	

	--
	--

	DECLARE @Output_Staging TABLE 
	(
		ID						int		not null	identity(1,1)	primary key		
	--
	,	ListID_Internal			int		not null		
	--
	,	X_Value					float	not null	
	--
	,	Interpolated_Y_Value	float	not null	
	--
	,	UNIQUE  (
					ListID_Internal		
				--				
				,	X_Value	
				) 
	)
	;

	--
	--

	DECLARE @ListID_Translation TABLE 
	(
		ListID_Internal		int		not null	identity(1,1)	primary key		
	,	ListID				int		null		unique	
	)	
	;

	DECLARE @Input_Pairs_internal TABLE 
	(
		ID					int			not null	identity(1,1)	primary key		
	--
	,	ListID_Internal		int			not null	
	--
	,	AscendingRank		int			not null	
	--
	,	X_Value				float		not null	
	,	Y_Value				float		not null	
	--
	,	UNIQUE	(
					ListID_Internal		
				-- 
				,	X_Value		
				)	
	,	UNIQUE	(
					ListID_Internal		
				-- 
				,	AscendingRank		
				)	
	)	
	;
	
	--
	--
	
	DECLARE @t_DistinctXValues TABLE	
	(
	/*	ID					int			not null	identity(1,1)	primary key		
	--
	,*/	ListID_Internal		int			not null	
	--	
	,	X_Value				float		not null	
	--	
	--,	UNIQUE	(
	,  PRIMARY KEY	( 
						ListID_Internal			
					,	X_Value		
					)	
	)	
	;

	DECLARE @t_ConsecutivePairs TABLE	
	(
		ID					int			not null	identity(1,1)	primary key		
	--
	,	ListID_Internal		int			not null	
	--	
	,	ComponentNumber		int			not null	
	--
	,	LowerBound			float		null	
	,	UpperBound			float		null	
	--
	--
	,  UNIQUE  (	
			 	  ListID_Internal			
			   ,  ComponentNumber		
			   )	
	--
	,  UNIQUE  (	
				  ListID_Internal	
			   ,  LowerBound
			   )	
	--
	,  UNIQUE  (	
				  ListID_Internal	
			   ,  UpperBound
			   )	
	--	
	)	
	;

	--
	--

	DECLARE @Input_List_internal TABLE 
	(
		ID					int			not null	identity(1,1)	primary key		
	--
	,	ListID_Internal		int			not null	
	--
	,	X_Value				float		not null	
	--
	,	ComponentNumber		int			not null	
	--
	,	UNIQUE	(
					ListID_Internal		
				-- 
				,	X_Value		
				)	
	)	
	;

	DECLARE @TridiagonalSystem TABLE 
	(
		ListID_Internal		int		not	null	
	--
	,	RowNumber			int		not null	
	--
	,	Coefficient_A		float	not null 
	,	Coefficient_B		float	not null 
	,	Coefficient_C		float	not null	
	--
	,	Result_D			float	not null	
	--	
	,	Adjusted_C			float	null	
	,	Adjusted_D			float	null		
	--
	,	Solution_X			float	null	
	--	
	,	PRIMARY KEY  (
						 ListID_Internal		
					 --	
					 ,	 RowNumber	
					 --		
					 )	
	)	
	;

	--
	--

		--
		--	Import input pairs	
		--	

		INSERT INTO @ListID_Translation 
		(
			ListID	
		)	

		SELECT		P.ListID	
		FROM		@Input_Pairs	P	
		GROUP BY	P.ListID	
		HAVING		COUNT(DISTINCT(P.X_Value)) >= 3	 --	 need at least 3 input points for natural cubic spline interpolation 
		;	

		--
		--

		INSERT INTO @Input_Pairs_internal 
		(
			ListID_Internal	
		--
		,	AscendingRank 
		--
		,	X_Value			
		,	Y_Value	
		)	

		SELECT	A.ListID_Internal	
		--
		,		RANK() OVER ( PARTITION BY	A.ListID_Internal 
							  ORDER BY		A.X_Value	ASC	  )		as	AscendingRank		
		--	
		,		A.X_Value	
		,		A.Y_Value	
		--	
		FROM	(
					SELECT		T.ListID_Internal	
					--
					,			P.X_Value	
					,			AVG(P.Y_Value)	Y_Value	 --  if multiple Y values are given for a single X value, take the average 
					--	
					FROM		@Input_Pairs			P	
					INNER JOIN	@ListID_Translation		T	ON	P.ListID = T.ListID		
															OR	(
																	P.ListID IS NULL 
																AND T.ListID IS NULL	
																)	
					GROUP BY	T.ListID_Internal	
					--
					,			P.X_Value	
				)	
					A	
		--	
		;	

	--
	--
	
		--
		--	Import input list 	
		--	

	--
	--

		INSERT INTO @t_DistinctXValues 
		(
			ListID_Internal		
		,	X_Value		
		)	

			SELECT	DISTINCT  T.ListID_Internal	
			--
			,				  L.X_Value	
			--	
			FROM		@Input_List				L		
			INNER JOIN	@ListID_Translation		T	ON	L.ListID = T.ListID		
													OR	(
															L.ListID IS NULL 
														AND T.ListID IS NULL	
														)	
			--
			;		

		INSERT INTO @t_ConsecutivePairs 	
		(
			ListID_Internal		
		--	
		,	ComponentNumber		
		--
		,	LowerBound			
		,	UpperBound			
		--	
		)	

			SELECT		I.ListID_Internal	
			,			I.AscendingRank		ComponentNumber		
			--	
			,			I.X_Value			LowerBound	 
			,			J.X_Value			UpperBound	
			--			
			FROM		@Input_Pairs_internal	I	
			LEFT  JOIN	@Input_Pairs_internal	J	ON	I.ListID_Internal = J.ListID_Internal 
													AND I.AscendingRank + 1 = J.AscendingRank 
			--
			;	

	--
	--	

		INSERT INTO @Input_List_internal 
		(
			ListID_Internal	
		--
		,	X_Value		 
		--
		,	ComponentNumber			
		)	

		SELECT	A.ListID_Internal	
		--
		,		A.X_Value 
		--
		,		CASE WHEN A.X_Value >= B.LowerBound 
					 AND  A.X_Value < B.UpperBound 
					 THEN B.ComponentNumber 
					 WHEN B.ComponentNumber = 1 
					 AND  A.X_Value < B.LowerBound 
					 THEN 0 
					 WHEN B.UpperBound IS NULL 
					 AND  A.X_Value >= B.LowerBound 
					 THEN - B.ComponentNumber 
				END 
		--	
		FROM		@t_DistinctXValues   A	
		INNER JOIN	@t_ConsecutivePairs	 B	
							--	
							ON	A.ListID_Internal = B.ListID_Internal	
							AND (
									(
										A.X_Value >= B.LowerBound 
									AND A.X_Value < B.UpperBound 
									)	
								OR	(
										B.ComponentNumber = 1 
									AND A.X_Value < B.LowerBound 
									)	
								OR	(
										B.UpperBound IS NULL 
									AND A.X_Value >= B.LowerBound 
									)	
								)	
		--	
		;	

	--
	--

		--
		--	Define tridiagonal system to be solved 
		--

			--
			--	all rows except for the first and the last 
			--	

		INSERT INTO @TridiagonalSystem 
		(
			ListID_Internal		
		--
		,	RowNumber			
		--
		,	Coefficient_A		
		,	Coefficient_B		
		,	Coefficient_C		
		--
		,	Result_D	
		)	

			SELECT		A.ListID_Internal	
			--
			,			A.AscendingRank								RowNumber
			--	
			,			A.Inv1										Coefficient_A
			,			convert(float,2.0)*(A.Inv1 + A.Inv2)		Coefficient_B
			,			A.Inv2										Coefficient_C
			--
			,			convert(float,3.0)*(A.Res1*A.Inv1*A.Inv1 + A.Res2*A.Inv2*A.Inv2)	Result_D	
			--	
			FROM		(
							SELECT		I.ListID_Internal	
							--
							,			J.AscendingRank		
							--	
							,			convert(float,1.0)/(J.X_Value - I.X_Value)	Inv1	
							,			convert(float,1.0)/(K.X_Value - J.X_Value)	Inv2	
							--
							,			J.Y_Value - I.Y_Value	Res1	
							,			K.Y_Value - J.Y_Value	Res2	
							--			
							FROM		@Input_Pairs_internal	I	
							INNER JOIN	@Input_Pairs_internal	J	ON	I.ListID_Internal = J.ListID_Internal 
																	AND I.AscendingRank + 1 = J.AscendingRank 
							INNER JOIN	@Input_Pairs_internal	K	ON	J.ListID_Internal = K.ListID_Internal 
																	AND J.AscendingRank + 1 = K.AscendingRank 
							--	
						)	
							A	
			--	
			;	
		
		--
		--

			--
			--	first row	
			--	

		INSERT INTO @TridiagonalSystem 
		(
			ListID_Internal		
		--
		,	RowNumber			
		--
		,	Coefficient_A		
		,	Coefficient_B		
		,	Coefficient_C		
		--
		,	Result_D	
		--
		,	Adjusted_C	
		,	Adjusted_D 
		)	

			SELECT	X.ListID_Internal	
			--
			,		X.RowNumber		
			--
			,		X.Coefficient_A		
			,		X.Coefficient_B		
			,		X.Coefficient_C		
			--
			,		X.Result_D	
			--
			,		X.Coefficient_C / X.Coefficient_B 
			,		X.Result_D / X.Coefficient_B 
			--	
			FROM	(
						SELECT		A.ListID_Internal	
						--
						,			1							RowNumber	
						--
						,			0							Coefficient_A	--	does not really exist ... should not be referenced		
						,			convert(float,2.0)*A.Inv1	Coefficient_B	
						,			A.Inv1						Coefficient_C		
						--
						,			convert(float,3.0)*A.Res1*A.Inv1*A.Inv1		Result_D	
						--	
						FROM		(
										SELECT		I.ListID_Internal	
										--	
										,			convert(float,1.0)/(J.X_Value - I.X_Value)	Inv1	
										--
										,			J.Y_Value - I.Y_Value	Res1	
										--			
										FROM		@Input_Pairs_internal	I	
										INNER JOIN	@Input_Pairs_internal	J	ON	I.ListID_Internal = J.ListID_Internal 
																				AND I.AscendingRank = 1 
																				AND J.AscendingRank = 2 
										--	
									)	
										A	
					) 
						X	
			--
			;	

		--
		--

			--
			--	last row 
			--	

		INSERT INTO @TridiagonalSystem 
		(
			ListID_Internal		
		--
		,	RowNumber			
		--
		,	Coefficient_A		
		,	Coefficient_B		
		,	Coefficient_C		
		--
		,	Result_D	
		)	

			SELECT		A.ListID_Internal	
			--
			,			A.AscendingRank	
			--
			,			A.Inv1 
			,			convert(float,2.0)*A.Inv1 
			,			0							--	does not really exist ... should not be referenced		
			--
			,			convert(float,3.0)*A.Res1*A.Inv1*A.Inv1			
			--
			FROM		(
							SELECT		I.ListID_Internal	
							--
							,			I.AscendingRank		
							--	
							,			convert(float,1.0)/(I.X_Value - J.X_Value)	Inv1	
							--
							,			I.Y_Value - J.Y_Value	Res1	
							--			
							FROM		@Input_Pairs_internal	I	
							INNER JOIN	(
											SELECT		Ix.ListID_Internal	
											,			MAX(Ix.AscendingRank)	MaxAscendingRank	
											FROM		@Input_Pairs_internal	Ix	
											GROUP BY	Ix.ListID_Internal	
										)	
																M	ON	I.ListID_Internal = M.ListID_Internal	
																	AND I.AscendingRank = M.MaxAscendingRank 
							INNER JOIN	@Input_Pairs_internal	J	ON	I.ListID_Internal = J.ListID_Internal 
																	AND I.AscendingRank - 1 = J.AscendingRank 
							--	
						)	
							A	
			--
			;	

		--
		--

	--
	--

		--
		--	Perform the "Thomas algorithm" (or Tridiagonal matrix algorithm) to solve for our interpolant first derivatives
		--	

		SELECT	@MaxIterations = MAX(X.RowNumber)
		FROM	@TridiagonalSystem	X	
		--
		;	

		SET @Iterator = 1 ; 

		WHILE @Iterator < @MaxIterations 
		BEGIN 
		
			SET @Iterator += 1 ; 

			UPDATE		T	
			SET			T.Adjusted_C = T.Coefficient_C / X.Denominator 
			,			T.Adjusted_D = ( T.Result_D - T.Coefficient_A * S.Adjusted_D ) / X.Denominator 
			FROM		@TridiagonalSystem	T	
			INNER JOIN	@TridiagonalSystem	S	ON	T.ListID_Internal = S.ListID_Internal 
												AND T.RowNumber = @Iterator 
												AND S.RowNumber = @Iterator - 1 
			OUTER APPLY ( 
							SELECT ( T.Coefficient_B - T.Coefficient_A * S.Adjusted_C ) 
								as Denominator 
						)	
							X	
			;	

		END		

		--
		--

		SET @Iterator = 1 ; 

		WHILE @Iterator <= @MaxIterations 
		BEGIN 
			
			;	
			WITH	cte_ValidLists	AS	(
											SELECT		T.ListID_Internal	
											,			MAX(T.RowNumber)	MaxRowNumber	
											FROM		@TridiagonalSystem	T	
											GROUP BY	T.ListID_Internal	
											HAVING		@Iterator <= MAX(T.RowNumber)	
										)	
			,		cte_LowestCalculated	AS	(
													SELECT		T.ListID_Internal 
													,			MIN(T.RowNumber)	MinRowNumber	
													FROM		@TridiagonalSystem	T	
													INNER JOIN	cte_ValidLists		V	ON	T.ListID_Internal = V.ListID_Internal	
													WHERE		T.Solution_X IS NOT NULL	
													GROUP BY	T.ListID_Internal	
												)	
			--	
			
			UPDATE		T	
			SET			T.Solution_X = CASE WHEN L.MinRowNumber IS NULL 
											THEN T.Adjusted_D 
											ELSE T.Adjusted_D - T.Adjusted_C * S.Solution_X 
									   END	
			FROM		cte_ValidLists			V	
			LEFT  JOIN	cte_LowestCalculated	L	ON	V.ListID_Internal = L.ListID_Internal	
			INNER JOIN	@TridiagonalSystem		T	ON	V.ListID_Internal = T.ListID_Internal 
													AND (
															(
																V.MaxRowNumber = T.RowNumber 
															AND L.MinRowNumber IS NULL 
															)	
														OR	L.MinRowNumber = T.RowNumber + 1 
														)	
			LEFT  JOIN	@TridiagonalSystem		S	ON	V.ListID_Internal = S.ListID_Internal 
													AND L.MinRowNumber = S.RowNumber 
			--
			;	
						
			SET @Iterator += 1 ; 

		END		

		--
		--	'Solution_X' is the first derivative of the interpolating function at each input point 
		-- 

	--
	--

		--
		--	Ready to calculate interpolated values	
		--

	--
	--

		INSERT INTO @Output_Staging 
		(
			ListID_Internal 
		--
		,	X_Value					
		--
		,	Interpolated_Y_Value
		)	
	
			SELECT		I.ListID_Internal 
			--
			,			I.X_Value	
			--
			,			U.invT_Value * P.Y_Value 
					  + T.T_Value * Q.Y_Value 
					  + T.T_Value * U.invT_Value * ( T.A_Value * U.invT_Value + T.B_Value * T.T_Value ) 
			--	
			FROM		@Input_List_internal	I	
			INNER JOIN	@Input_Pairs_internal	P	ON	I.ListID_Internal = P.ListID_Internal	
													AND I.ComponentNumber = P.AscendingRank 
													--
													AND	I.ComponentNumber >= 1	--  ignore out-of-range values for now 
													--
			INNER JOIN	@Input_Pairs_internal	Q	ON	I.ListID_Internal = Q.ListID_Internal	
													AND I.ComponentNumber + 1 = Q.AscendingRank 
			INNER JOIN	@TridiagonalSystem		L	ON	I.ListID_Internal = L.ListID_Internal 
													AND I.ComponentNumber = L.RowNumber 
			INNER JOIN	@TridiagonalSystem		M	ON	I.ListID_Internal = M.ListID_Internal 
													AND I.ComponentNumber + 1 = M.RowNumber 
			OUTER APPLY (
							SELECT	( I.X_Value - P.X_Value ) / ( Q.X_Value - P.X_Value )	
								as	T_Value		

							,	L.Solution_X * ( Q.X_Value - P.X_Value ) - ( Q.Y_Value - P.Y_Value ) 
								as	A_Value		

							,	- M.Solution_X * ( Q.X_Value - P.X_Value ) + ( Q.Y_Value - P.Y_Value )	
								as	B_Value		
						)	
							T	
			OUTER APPLY (
							SELECT	convert(float,1.0) - T.T_Value	
								as	invT_Value	
						)	
							U	
			--
			;	

	--
	--

		--
		--	fill in out-of-range values using first derivatives and linear approximation at end-points 
		--	

			--
			--	requested point lower than smallest knot point 
			--	
		
		INSERT INTO @Output_Staging 
		(
			ListID_Internal 
		--
		,	X_Value					
		--
		,	Interpolated_Y_Value
		)	
	
			SELECT		I.ListID_Internal 
			--
			,			I.X_Value	
			--
			,			L.Solution_X * ( I.X_Value - P.X_Value ) + P.Y_Value 
			--	
			FROM		@Input_List_internal	I	
			INNER JOIN	@Input_Pairs_internal	P	ON	I.ListID_Internal = P.ListID_Internal	
													AND I.ComponentNumber = 0 
													AND P.AscendingRank = 1 
													--
			INNER JOIN	@TridiagonalSystem		L	ON	P.ListID_Internal = L.ListID_Internal 
													AND P.AscendingRank = L.RowNumber 
													--	
			;	
			
			--
			--	requested point higher than greatest knot point 
			--	

		INSERT INTO @Output_Staging 
		(
			ListID_Internal 
		--
		,	X_Value					
		--
		,	Interpolated_Y_Value
		)	
	
			SELECT		I.ListID_Internal 
			--
			,			I.X_Value	
			--
			,			L.Solution_X * ( I.X_Value - P.X_Value ) + P.Y_Value 
			--	
			FROM		@Input_List_internal	I	
			INNER JOIN	@Input_Pairs_internal	P	ON	I.ListID_Internal = P.ListID_Internal	
													AND I.ComponentNumber < 0 
													AND P.AscendingRank = -I.ComponentNumber 
													--
			INNER JOIN	@TridiagonalSystem		L	ON	P.ListID_Internal = L.ListID_Internal 
													AND P.AscendingRank = L.RowNumber 
													--	
			;	

	--
	--

		--
		--	Return results	
		--

		INSERT INTO @Output		
		(
			ListID	
		--
		,	X_Value		
		--
		,	Interpolated_Y_Value	
		)	

		SELECT		T.ListID	
		--
		,			S.X_Value	
		--
		,			S.Interpolated_Y_Value	
		--	
		FROM		@Output_Staging			S	
		INNER JOIN	@ListID_Translation		T	ON	S.ListID_Internal = T.ListID_Internal	
		--	
		;	

	--
	--	

	RETURN 
END
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Faster sub-routine to calculate Cubic Spline interpolation functions of the "Natural" type, exploiting the "tridiagonal" structure of the linear system of equations to be solved.' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_InterpolationEvaluation_FastNaturalCubicSpline'
--GO

--
--

CREATE FUNCTION [math].[fcn_LocalPolynomialRegression]	 
(
	@InputPairs						math.UTT_OrderedPair	READONLY				
--	
,	@KernelFunction_ShortName		varchar(20)		
,	@KernelSupportRadius			float			
--
,	@OrderNumber					int				
--	
)
RETURNS 
@Output TABLE 
(
	ListID			int		null		
--
,	X_Value			float	not null	
,	Y_Value			float	null		
--
,	UNIQUE  (
				ListID	
			-- 
			,	X_Value		
			) 
)
AS
/**************************************************************************************

	Returns a set of smoothed 'Local Polynomial Regression' function values 
		generated from a provided list of ordered pairs. 

		
		Example:	

			--
			--
			
			DECLARE	@Test AS math.UTT_OrderedPair ; 

			INSERT INTO @Test 
			(	
				X_Value 
			,	Y_Value		
			)	

				VALUES		( 1 , 1 )	
				,			( 2 , 3 )	
				,			( 3 , 5 )	
				,			( 4 , 6 )	
				,			( 5 , 5 )	
				,			( 6 , 3 )	
				,			( 7 , 2 )	
				,			( 8 , 1 )	
				,			( 9 , 3 )	
				--
				;	
			
			SELECT		S.X_Value	
			--
			,			X.Y_Value		Y_Input		
			,			S.Y_Value		Y_Result	
			--
			FROM		math.fcn_LocalPolynomialRegression
							 ( 
								@Test 
							 --
							 ,	'Parabolic' 
							 ,	4
							 --
							 ,	2
							 --		
							 ) 
								S		 
			--
			LEFT  JOIN	@Test	X	ON	S.X_Value = X.X_Value	
			--	
			ORDER BY	S.X_Value	ASC		
			--	
			;		

			--
			--

	Date			Action	
	----------		----------------------------
	2017-08-31		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--
		
		--
		--	Check input parameters	
		--
				 
		IF ( SELECT COUNT(*) FROM math.KernelFunction X WHERE X.ShortName = @KernelFunction_ShortName ) = 0		
		BEGIN 
			RETURN ;	
		END		

		IF @KernelSupportRadius IS NULL 
		OR @KernelSupportRadius <= 0 
		BEGIN 
			RETURN ;	
		END		

		IF @OrderNumber IS NULL 
		OR @OrderNumber < 0 
		BEGIN 
			RETURN ;	
		END 

		IF EXISTS ( SELECT null FROM @InputPairs X GROUP BY X.ListID , X.X_Value HAVING COUNT(*) > 1 ) 
		BEGIN 
			--
			--	Combinations of ListID and X_Value in @InputList must be unique		
			--	
			RETURN ;	
		END		

	--
	--

		--
		--	Declare table variables		
		--

	--
	--

	DECLARE @InternalList TABLE 
	(
		ID			int			not null	identity(1,1)	primary key		
	--
	,	ListID		int			null		unique	
	--	
	)	

	DECLARE @InternalPair TABLE 
	(
		ID					int			not null	identity(1,1)	primary key		
	--
	,	InternalListID		int			not null	
	,	X_Value				float		not null	
	--	
	,	AscendingRank		int			not null	
	--
	,	Y_Value				float		not null	
	--
	,	MatchedRank_Min		int			null 
	,	MatchedRank_Max		int			null 
	--	
	,	UNIQUE	(
					InternalListID	
				,	X_Value		
				)	
	--	
	,	UNIQUE	(
					InternalListID	
				,	AscendingRank		
				)	
	--	
	)	

	--
	--

	DECLARE @PairToMatrixMapping TABLE 
	(	
		ID					int				not null	identity(1,1)	primary key		
	--
	,	InternalPairID		int				not null		
	,	MatrixName			varchar(20)		not null	
	--	
	,	UNIQUE	(
					InternalPairID		
				,	MatrixName			
				)	
	--	
	)	

	--
	--

	DECLARE @IntegerList TABLE 
	(
		IntegerValue	int		not null	primary key		
	)	
	--	
	;		DECLARE @IntegerList_Iterator int = 0 ; 
			WHILE ( @IntegerList_Iterator <= @OrderNumber ) 
			BEGIN 
				INSERT INTO @IntegerList ( IntegerValue ) VALUES ( @IntegerList_Iterator ) ; 
				SET @IntegerList_Iterator += 1 ;	
			END		

	--
	--

	--	
	DECLARE @c_Matrix	AS math.UTT_MatrixCoordinate ; 
	--	
	DECLARE @t1_Matrix	AS math.UTT_MatrixCoordinate ; 
	DECLARE @t2_Matrix	AS math.UTT_MatrixCoordinate ; 
	--

	--
	--	

	DECLARE @Output_Staging	TABLE 
	(
		ID				int		not null	identity(1,1)	primary key		
	--
	,	ListID			int		null		
	--
	,	X_Value			float	not null	
	,	Y_Value			float	null		
	--
	,	UNIQUE  (
					ListID	
				-- 
				,	X_Value		
				) 
	--	
	)
	;	

	--
	--
	
		--
		--	Cache provided lists of ordered pairs  
		--	

	--
	--

	INSERT INTO @InternalList	
	(
		ListID	
	)	
	
		SELECT	distinct	 X.ListID	
		FROM	@InputPairs	 X	
		--
		;	

	--
	--

	INSERT INTO @InternalPair 
	(
		InternalListID	
	,	X_Value		
	--
	,	AscendingRank 
	--
	,	Y_Value		
	--	
	)	
		
		SELECT		I.ID	
		,			P.X_Value	
		--
		,			RANK() OVER ( PARTITION BY P.ListID ORDER BY P.X_Value ASC )	--	AscendingRank	
		--
		,			P.Y_Value		
		--
		FROM		@InternalList	I	
		INNER JOIN	@InputPairs		P 	ON	I.ListID = P.ListID		
										OR	(
												I.ListID IS NULL 
											AND P.ListID IS NULL	
											)	
		--
		;	

		--
		--

		UPDATE		P	
		SET			P.MatchedRank_Min = X.MatchedRank_Min
		,			P.MatchedRank_Max = X.MatchedRank_Max 
		FROM		@InternalPair	P	
		INNER JOIN	(
						SELECT		Ps.ID	
						,			MIN( Q.AscendingRank )	MatchedRank_Min
						,			MAX( Q.AscendingRank )	MatchedRank_Max
						FROM		@InternalPair	Ps	
						INNER JOIN	@InternalPair	Q	ON	Ps.InternalListID = Q.InternalListID 
														AND ABS ( Q.X_Value - Ps.X_Value ) < @KernelSupportRadius 
						GROUP BY	Ps.ID	
					)	
						X	ON	P.ID = X.ID		
		--
		;	

	--
	--

	INSERT INTO @PairToMatrixMapping	
	(
		InternalPairID	
	--	
	,	MatrixName	
	--	
	)	

		SELECT		X.ID	
		--
		,			Y.MatrixName 
		--
		FROM		@InternalPair	X	
		CROSS JOIN	(
						VALUES	( 'X' )
						,		( 'W' ) 
						,		( 'Y' ) 
						--,		( 'e1_T' ) 
						,		( 'X_T' ) 
						,		( 'W * X' ) 
						,		( 'X_T * W * X' ) 
						,		( '(X_T * W * X)_inv' ) 
						,		( 'W * Y' ) 
						,		( 'X_T * W * Y' ) 
						,		( 'P' ) 
					)	
						Y	( MatrixName )	
		--
		;	

	--
	--

		--
		--	Define starting matrices
		--	

	--
	--	

	/*		--
			--	e1_T	
			--	
		INSERT INTO @c_Matrix 
		(
			MatrixID	
		--	
		,	RowNumber 
		,	ColumnNumber	
		--	
		,	[Value]		
		--	
		)	

			SELECT		M.ID	
			--	
			,			1	
			,			L.IntegerValue + 1 
			--	
			,			CASE WHEN L.IntegerValue = 0 
							 THEN convert(float,1.0)	 
							 ELSE convert(float,0.0)	 
						END		
			--	
			FROM		@PairToMatrixMapping	M	
			INNER JOIN	@IntegerList			L	ON	M.MatrixName = 'e1_T'	
			--
			;		
					*/	
	--				
	--
	
			--
			--	X , X_T 
			--	
		INSERT INTO @c_Matrix 
		(
			MatrixID	
		--	
		,	RowNumber 
		,	ColumnNumber	
		--	
		,	[Value]		
		--	
		)	

			SELECT		M.ID	
			--	
			,			CASE WHEN M.MatrixName = 'X' THEN P.AscendingRank - Q.MatchedRank_Min + 1  ELSE L.IntegerValue + 1  END	
			,			CASE WHEN M.MatrixName = 'X' THEN L.IntegerValue + 1  ELSE P.AscendingRank - Q.MatchedRank_Min + 1  END	
			--	
			,			CASE L.IntegerValue 
							WHEN 0 THEN convert(float,1.0)	
							WHEN 1 THEN P.X_Value - Q.X_Value 
							WHEN 2 THEN ( P.X_Value - Q.X_Value ) * ( P.X_Value - Q.X_Value )
							WHEN 3 THEN ( P.X_Value - Q.X_Value ) * ( P.X_Value - Q.X_Value ) * ( P.X_Value - Q.X_Value )
							--
							ELSE POWER( P.X_Value - Q.X_Value , convert(float,L.IntegerValue) )		
							--
						END		
			--	
			FROM		@PairToMatrixMapping	M	
			INNER JOIN	@InternalPair			Q	ON	M.InternalPairID = Q.ID		
													AND M.MatrixName IN ( 'X' , 'X_T' )			
			INNER JOIN	@InternalPair			P	ON	Q.InternalListID = P.InternalListID 
													--
													AND P.AscendingRank BETWEEN Q.MatchedRank_Min AND Q.MatchedRank_Max 
													--
			CROSS JOIN	@IntegerList			L	
			--
			;	
		
	--
	--
		
			--
			--	W 	
			--	
		INSERT INTO @c_Matrix 
		(
			MatrixID	
		--	
		,	RowNumber 
		,	ColumnNumber	
		--	
		,	[Value]		
		--	
		)	

			SELECT		M.ID	
			--	
			,			P.AscendingRank - Q.MatchedRank_Min + 1 	
			,			R.AscendingRank - Q.MatchedRank_Min + 1  
			--	
			,			CASE WHEN P.AscendingRank = R.AscendingRank 
							 THEN math.fcn_KernelFunction ( ( P.X_Value - Q.X_Value ) / @KernelSupportRadius 
														  , @KernelFunction_ShortName )	
							 ELSE convert(float,0.0)	
						END		
			--	
			FROM		@PairToMatrixMapping	M	
			INNER JOIN	@InternalPair			Q	ON	M.InternalPairID = Q.ID		
													AND M.MatrixName = 'W'	
			INNER JOIN	@InternalPair			P	ON	Q.InternalListID = P.InternalListID 
													AND P.AscendingRank BETWEEN Q.MatchedRank_Min AND Q.MatchedRank_Max 
			INNER JOIN	@InternalPair			R	ON	Q.InternalListID = R.InternalListID 
													AND R.AscendingRank BETWEEN Q.MatchedRank_Min AND Q.MatchedRank_Max 
			--
			;	
		
	--
	--
	
			--
			--	Y 	
			--	
		INSERT INTO @c_Matrix 
		(
			MatrixID	
		--	
		,	RowNumber 
		,	ColumnNumber	
		--	
		,	[Value]		
		--	
		)	

			SELECT		M.ID	
			--	
			,			P.AscendingRank - Q.MatchedRank_Min + 1 		
			,			1
			--	
			,			P.Y_Value 
			--	
			FROM		@PairToMatrixMapping	M	
			INNER JOIN	@InternalPair			Q	ON	M.InternalPairID = Q.ID		
													AND M.MatrixName = 'Y'	
			INNER JOIN	@InternalPair			P	ON	Q.InternalListID = P.InternalListID 
													AND P.AscendingRank BETWEEN Q.MatchedRank_Min AND Q.MatchedRank_Max 
			--
			;	
		
	--
	--

		--
		--	Perform matrix multiplications 
		--	

	--
	--	
	
			--
			--	W * X	
			--	

		INSERT INTO @t1_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'W * X' 
													AND M.MatrixName = 'W'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;		

		INSERT INTO @t2_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'W * X' 
													AND M.MatrixName = 'X'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;	

		INSERT INTO @c_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT	X.MatrixID 
			--
			,		X.ColumnNumber 
			,		X.RowNumber		
			--
			,		X.[Value]	
			--
			FROM	math.fcn_Matrix_Product ( @t1_Matrix , @t2_Matrix )		X	
			--
			;	

		DELETE FROM @t1_Matrix ; 
		DELETE FROM @t2_Matrix ;	

	--
	--
	
			--
			--	W * Y 	
			--	

		INSERT INTO @t1_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'W * Y' 
													AND M.MatrixName = 'W'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;		

		INSERT INTO @t2_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'W * Y' 
													AND M.MatrixName = 'Y'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;	

		INSERT INTO @c_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT	X.MatrixID 
			--
			,		X.ColumnNumber 
			,		X.RowNumber		
			--
			,		X.[Value]	
			--
			FROM	math.fcn_Matrix_Product ( @t1_Matrix , @t2_Matrix )		X	
			--
			;	

		DELETE FROM @t1_Matrix ; 
		DELETE FROM @t2_Matrix ;	
		
	--
	--
	
			--
			--	X_T * W * X	
			--	

		INSERT INTO @t1_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'X_T * W * X' 
													AND M.MatrixName = 'X_T'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;		

		INSERT INTO @t2_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'X_T * W * X' 
													AND M.MatrixName = 'W * X'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;	

		INSERT INTO @c_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT	X.MatrixID 
			--
			,		X.ColumnNumber 
			,		X.RowNumber		
			--
			,		X.[Value]	
			--
			FROM	math.fcn_Matrix_Product ( @t1_Matrix , @t2_Matrix )		X	
			--
			;	

		DELETE FROM @t1_Matrix ; 
		DELETE FROM @t2_Matrix ;	

	--
	--
	
			--
			--	X_T * W * Y 	
			--	

		INSERT INTO @t1_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'X_T * W * Y' 
													AND M.MatrixName = 'X_T'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;		

		INSERT INTO @t2_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'X_T * W * Y' 
													AND M.MatrixName = 'W * Y'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;	

		INSERT INTO @c_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT	X.MatrixID 
			--
			,		X.ColumnNumber 
			,		X.RowNumber		
			--
			,		X.[Value]	
			--
			FROM	math.fcn_Matrix_Product ( @t1_Matrix , @t2_Matrix )		X	
			--
			;	

		DELETE FROM @t1_Matrix ; 
		DELETE FROM @t2_Matrix ;	

	--
	--	

		--
		--	Invert matrices on left side of main product 
		--	

	--		
	--
	
			--
			--	(X_T * W * X)_inv		
			--
			
		INSERT INTO @t1_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = '(X_T * W * X)_inv' 
													AND M.MatrixName = 'X_T * W * X'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;	

		INSERT INTO @c_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	

			SELECT	X.MatrixID 
			--
			,		X.ColumnNumber 
			,		X.RowNumber		
			--
			,		X.[Value]	
			--
			FROM	math.fcn_Matrix_Inverse ( @t1_Matrix )	X	
			--
			;	

		DELETE FROM @t1_Matrix ; 

	--
	--

		--
		--	Perform final multiplications	
		--	

	--
	--
	
			--
			--	P		
			--	

		INSERT INTO @t1_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'P' 
													AND M.MatrixName = '(X_T * W * X)_inv'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;		

		INSERT INTO @t2_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT		P.ID 
			--
			,			X.ColumnNumber 
			,			X.RowNumber		
			--
			,			X.[Value]	
			--	
			FROM		@PairToMatrixMapping	P	
			INNER JOIN	@PairToMatrixMapping	M	ON	P.InternalPairID = M.InternalPairID		
													AND P.MatrixName = 'P' 
													AND M.MatrixName = 'X_T * W * Y'	
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
			--
			;	

		INSERT INTO @c_Matrix 
		(
			MatrixID 
		--
		,	ColumnNumber 
		,	RowNumber 
		--
		,	[Value]			
		--	
		)	
			SELECT	X.MatrixID 
			--
			,		X.ColumnNumber 
			,		X.RowNumber		
			--
			,		X.[Value]	
			--
			FROM	math.fcn_Matrix_Product ( @t1_Matrix , @t2_Matrix )		X	
			--
			;	

		DELETE FROM @t1_Matrix ; 
		DELETE FROM @t2_Matrix ;	
		
	--
	--
	
		--
		--	Stage results	
		--	

	--
	--

		INSERT INTO @Output_Staging		
		(
			ListID	
		--
		,	X_Value		
		,	Y_Value		
		--	
		)	

			SELECT		L.ListID	
			--
			,			P.X_Value	
			,			SUM( X.[Value] )	
			--	
			FROM		@PairToMatrixMapping	M		
			INNER JOIN	@InternalPair			P	ON	M.InternalPairID = P.ID		
													AND M.MatrixName = 'P'	
			INNER JOIN	@InternalList			L	ON	P.InternalListID = L.ID		
			INNER JOIN	@c_Matrix				X	ON	M.ID = X.MatrixID 
													AND X.ColumnNumber = 1	
			--	
			GROUP BY	L.ListID	
			--
			,			P.X_Value	
			--
			;	

	--
	--

		--
		--	Output final calculations 
		--

		INSERT INTO @Output 
		(
			ListID		
		--
		,	X_Value		
		,	Y_Value	
		--	 
		)	

			SELECT		S.ListID		
			--
			,			S.X_Value		
			,			S.Y_Value	
			--	
			FROM		@Output_Staging		S	
			--	
			;	

	--
	--

	RETURN 
END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns a “smoothed” set of “Local Polynomial Regression” function values generated from a provided list of ordered pairs, a kernel function, and a polynomial order number. For order 0 this is equivalent to “kernel smoothing”.' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_LocalPolynomialRegression'
--GO

--
--

CREATE FUNCTION [math].[fcn_PolynomialDerivative]
(	
	@Input_Polynomials		math.UTT_PolynomialTerm   READONLY	
)
RETURNS TABLE 
AS
/**************************************************************************************

	  Returns coefficients and exponents describing 
	   the derivatives of each polynomial in a provided input set. 

		
		Example:	

			--
			--

			DECLARE @t_Polynomial AS math.UTT_PolynomialTerm ; 

			INSERT INTO @t_Polynomial 
			(
				Coefficient
			,	Exponent	
			)	
			VALUES	( 1 , 0 ) 
			,		( 2 , 1 ) 
			,		( 3 , 2 ) 
			--	
			;	

			SELECT		*	
			FROM		math.fcn_PolynomialDerivative ( @t_Polynomial ) X 
			ORDER BY	X.PolynomialID	ASC		
			,			X.Exponent		ASC		
			--	
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2016-05-29		Created initial version. 

**************************************************************************************/	
RETURN 
(
	
	SELECT		A.PolynomialID	
	--
	,			coalesce(X.Coefficient,0)	Coefficient		
	,			coalesce(X.Exponent,0)		Exponent		
	--
	FROM		(
					SELECT	distinct	Q.PolynomialID 
					FROM	@Input_Polynomials	Q	
				)	
					A	
	LEFT  JOIN	(
					SELECT		P.PolynomialID 
					--	
					,			P.Coefficient * P.Exponent			Coefficient		
					,			P.Exponent - convert(float,1.0)		Exponent		
					--	
					FROM		@Input_Polynomials		P	
					--
					WHERE		P.Coefficient != 0 
					AND			P.Exponent != 0 
					--	
				)	
					X	ON	A.PolynomialID = X.PolynomialID		
						OR	(
								A.PolynomialID IS NULL 
							AND X.PolynomialID IS NULL	
							)	

)

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the "power-rule" derivative for an input “polynomial”' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_PolynomialDerivative'
--GO

--
--

CREATE FUNCTION [math].[fcn_PolynomialEvaluation]
(	
	@Input_Polynomials		math.UTT_PolynomialTerm   READONLY	
,	@Input_VariableValues	math.UTT_ListElement	  READONLY	
)
RETURNS TABLE 
AS
/**************************************************************************************

	  Returns the values of each input polynomial function 
	   evaluated at each input variable value. 

		
		Example:	

			--
			--

			DECLARE @t_Polynomial AS math.UTT_PolynomialTerm ; 
			DECLARE @t_VariableValues AS math.UTT_ListElement ; 

			INSERT INTO @t_Polynomial 
			(
				Coefficient
			,	Exponent	
			)	
			VALUES	( 1 , 0 ) 
			,		( 2 , 1 ) 
			,		( 3 , 2 ) 
			--	
			;	

			INSERT INTO @t_VariableValues	
			( 
				X_Value		
			)	
			VALUES	( 0 ) 
			,		( 1 ) 
			,		( 2 ) 
			--	
			;	

			SELECT		*	
			FROM		math.fcn_PolynomialEvaluation ( @t_Polynomial , @t_VariableValues ) X 
			ORDER BY	X.PolynomialID		ASC		
			,			X.VariableValue		ASC		
			--	
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2016-05-29		Created initial version. 
	2016-06-13		Added exception for negative variable values and non-integer exponents. 

**************************************************************************************/	
RETURN 
(
	
	SELECT		P.PolynomialID 
	--	
	,			V.X_Value													VariableValue	
	--
	,			SUM ( CASE WHEN P.Coefficient = 0 
						   THEN 0
						   WHEN P.Exponent = 0 
						   THEN P.Coefficient 
						   WHEN convert(float,convert(int,P.Exponent)) != P.Exponent 
						   AND  V.X_Value < 0  
						   THEN 0	
						   ELSE CASE WHEN V.X_Value = 0 
									 THEN 0 
									 ELSE P.Coefficient * POWER ( V.X_Value , P.Exponent ) 
								END 
					  END )	FunctionValue	
	--	
	FROM		@Input_Polynomials		P	
	INNER JOIN	@Input_VariableValues	V	ON	P.PolynomialID = V.ListID 
											OR	(
													P.PolynomialID IS NULL 
												AND V.ListID IS NULL	
												)	
	GROUP BY	P.PolynomialID 
	--	
	,			V.X_Value
	--	
	HAVING		(
					V.X_Value != 0 
				OR	SUM( CASE WHEN P.Exponent < 0 THEN 1 ELSE 0 END ) = 0 
				)	--
					--	if a 'polynomial' (allowed to have negative and fractional exponents here) 
					--	 has a negative exponent, it can't be evaluated at zero 
					--	
	AND			(
					V.X_Value >= 0 
				OR	SUM( CASE WHEN convert(float,convert(int,P.Exponent)) != P.Exponent THEN 1 ELSE 0 END ) = 0 
				)	--
					--	if a 'polynomial' (allowed to have negative and fractional exponents here) 
					--	 has a fractional exponent, it can't be evaluated at negative numbers 
					--	

)

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the function values of an input “polynomial” at a series of requested points' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'FUNCTION',@level1name=N'fcn_PolynomialEvaluation'
--GO

--
--

CREATE FUNCTION [math].[fcn_MinkowskiDistance]  
(	
	@OrderValue		float	
--	
,	@RowVectors_1	math.UTT_MatrixCoordinate  READONLY		
,	@RowVectors_2	math.UTT_MatrixCoordinate  READONLY		
--	
)	
RETURNS 
@Output TABLE 
(
	OrderValue		float	null 
--	
,	MatrixID		int		null		
--
,	RowNumber_1		int		not null	
,	RowNumber_2		int		not null	
--
,	Distance		float	null	
--
,	UNIQUE  (
				MatrixID	
			-- 
			,	RowNumber_1	
			,	RowNumber_2
			--
			) 
)
AS
/**************************************************************************************

	Returns Minkowski Distances of a requested Order 
	 between ordered pairs of row vectors from two sets of input matrices. 
	 
	 	The @OrderValue parameter must be positive or null. 

			A null value is interpreted as +infinity (Chebyshev distance, max coordinate-wise absolute difference). 
			A value of 1 corresponds to the Manhattan / taxi-cab / rectilinear distance (defining the L1 norm). 
			A value of 2 corresponds to the Euclidean distance (defining the L2 norm). 


			
									Sum
					D(X,Y) =   [   over i    | X_i - Y_i | ^ p   ]  ^ ( 1/p )	
								  between 
								  1 and N 


		Example:	

			--
			--
			
			DECLARE	@Test_RowVectors_1 AS math.UTT_MatrixCoordinate ; 
			DECLARE	@Test_RowVectors_2 AS math.UTT_MatrixCoordinate ; 

			INSERT INTO @Test_RowVectors_1 
			(	
				RowNumber
			,	ColumnNumber 
			,	Value 
			)	

				VALUES		( 1 , 1 , 5.00 )	,	( 1 , 2 , 3.00 )	,	( 1 , 3 , 8.00 )	
				,			( 2 , 1 , 2.00 )	,	( 2 , 2 , 7.00 )	,	( 2 , 3 , 4.00 )	
				;	

			INSERT INTO @Test_RowVectors_2 
			(	
				RowNumber
			,	ColumnNumber 
			,	Value 
			)	

				VALUES		( 1 , 1 , 7.00 )	,	( 1 , 2 , 7.00 )	,	( 1 , 3 , 7.00 )	
				,			( 2 , 1 , 3.00 )	,	( 2 , 2 , 3.00 )	,	( 2 , 3 , 3.00 )	
				,			( 3 , 1 , 2.00 )	,	( 3 , 2 , 0.00 )	,	( 3 , 3 , 4.00 )	
				;	
			
			--
			--

			DECLARE		@Test_OrderValue	float		=	2.000		-- 1.000	-- null	  
			--
			;

			--
			--
			
			SELECT		X.*	
			--	
			FROM		math.fcn_MinkowskiDistance ( 
														@Test_OrderValue
												   ,	@Test_RowVectors_1
												   ,	@Test_RowVectors_2		
												   --	
												   ) 
														X 
			--	
			ORDER BY	X.RowNumber_1 
			,			X.RowNumber_2 	
			--	
			;		

			--
			--

	Date			Action	
	----------		----------------------------
	2018-11-01		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--
	
		--
		--	Check @OrderValue parameter value. 
		--

		IF @OrderValue <= 0.000000001 
		BEGIN 
			RETURN ;	
		END 

		--
		--	Check configuration of input matrices, and return an empty record-set 
		--	 if there are any problems. 
		--
	
	--
	--
		 
		IF math.fcn_Matrix_IntegrityCheck ( @RowVectors_1 , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		
		
		IF math.fcn_Matrix_IntegrityCheck ( @RowVectors_2 , 0 , 0 ) = 0 
		BEGIN 

			RETURN ; 

		END		

	--
	--

		IF EXISTS ( SELECT	null
					FROM	(
								SELECT		X.MatrixID 
								,			MAX(X.ColumnNumber)		MaxColumnNumber 
								FROM		@RowVectors_1  X	
								GROUP BY	X.MatrixID 
							)	
								RV_1	
					--	
					FULL JOIN   (
									SELECT		Y.MatrixID 
									,			MAX(Y.ColumnNumber)		MaxColumnNumber 
									FROM		@RowVectors_2  Y
									GROUP BY	Y.MatrixID 
								)	
									RV_2	ON	RV_1.MatrixID = RV_2.MatrixID 
											OR	(
													RV_1.MatrixID IS NULL 
												AND RV_2.MatrixID IS NULL
												)	
					--
					WHERE	RV_1.MaxColumnNumber IS NULL 
					OR		RV_2.MaxColumnNumber IS NULL 
					OR		RV_1.MaxColumnNumber != RV_2.MaxColumnNumber 
					--
				  )		
		BEGIN	

			RETURN ;	

		END		

	--
	--

		--
		--	Calculate distances		
		--

		IF @OrderValue IS NULL 
		BEGIN	
		
			INSERT INTO @Output 
			(
				OrderValue			
			--						
			,	MatrixID			
			--						
			,	RowNumber_1			
			,	RowNumber_2			
			--						
			,	Distance			
			--	
			)	

				SELECT		@OrderValue		--	OrderValue	
				--						
				,			R.MatrixID			
				--								
				,			R.RowNumber					
				,			S.RowNumber			
				--								
				,			MAX ( ABS( R.[Value] - S.[Value] ) )	--	Distance			
				--	
				FROM		@RowVectors_1	R	
				INNER JOIN	@RowVectors_2	S	ON	(
														R.MatrixID = S.MatrixID  	
													OR	(
															R.MatrixID IS NULL 
														AND S.MatrixID IS NULL 
														)	
													)	
												AND R.ColumnNumber = S.ColumnNumber		
				--
				GROUP BY	R.MatrixID			
				--								
				,			R.RowNumber					
				,			S.RowNumber			
				--	
				;		
				
		END		
		ELSE BEGIN	
			
			INSERT INTO @Output 
			(
				OrderValue			
			--						
			,	MatrixID			
			--						
			,	RowNumber_1			
			,	RowNumber_2			
			--						
			,	Distance			
			--	
			)	

				SELECT		@OrderValue		--	OrderValue	
				--						
				,			R.MatrixID			
				--								
				,			R.RowNumber					
				,			S.RowNumber			
				--								
				,			POWER
							( 
								SUM ( 
										POWER 
										(	
											ABS( R.[Value] - S.[Value] ) 
										--
										,	@OrderValue 
										--
										)	
									)	
							--	
							,	convert(float,1.00) / @OrderValue		
							--	
							)				--	Distance			
				--	
				FROM		@RowVectors_1	R	
				INNER JOIN	@RowVectors_2	S	ON	(
														R.MatrixID = S.MatrixID  	
													OR	(
															R.MatrixID IS NULL 
														AND S.MatrixID IS NULL 
														)	
													)	
												AND R.ColumnNumber = S.ColumnNumber		
				--
				GROUP BY	R.MatrixID			
				--								
				,			R.RowNumber					
				,			S.RowNumber			
				--	
				;		
				
		END		

	--
	--

	RETURN 
END

GO

--
--

--
--
--
--

-- 
-- END FILE :: m002_TableValuedFunctions.sql 
-- 
