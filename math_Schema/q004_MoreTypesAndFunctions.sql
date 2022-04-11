--
-- BEGIN FILE :: q004_MoreTypesAndFunctions.sql 
--
--	
/***

  CONTENTS: 
  
  - create "quant" and "quant_history" schemas  
  - create user-defined table-types: 
    - UTT_CashflowSeriesComponent 
	- UTT_CashflowSeriesPrice 
  - create scalar functions  
	- fcn_BlackVolatilityConversion_LognormalToNormal 
	- fcn_BlackVolatilityConversion_NormalToLognormal 
  - create table-valued functions 
	- fcn_StockOptionPrice_BlackScholesModel 
	- fcn_BondOptionPrice_LognormalModel 
	- fcn_InterestRateOptionPrice_LognormalModel 
	- fcn_InterestRateOptionPrice_NormalModel 
	- fcn_CashflowSeries_YieldToMaturity 
	- fcn_CashflowSeries_YieldToMaturity_SmallBatches 

***/
--
--
CREATE SCHEMA quant AUTHORIZATION dbo -- the "core" schema to store finance-related computational math functions 
GO 
CREATE SCHEMA quant_history AUTHORIZATION dbo -- necessary to deploy "history" tables (but there are no tables in [quant], for now) 
GO 
--
--
--
--
-- 

--
--

CREATE TYPE [quant].[UTT_CashflowSeriesComponent] AS TABLE(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[CashflowSeriesID] [int] NULL,
	[CashflowDate] [date] NOT NULL,
	[Amount] [float] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (IGNORE_DUP_KEY = OFF),
	UNIQUE NONCLUSTERED 
(
	[CashflowSeriesID] ASC,
	[CashflowDate] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [quant].[UTT_CashflowSeriesPrice] AS TABLE(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[CashflowSeriesID] [int] NULL,
	[EffectiveDate] [date] NOT NULL,
	[Price] [float] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (IGNORE_DUP_KEY = OFF),
	UNIQUE NONCLUSTERED 
(
	[CashflowSeriesID] ASC,
	[EffectiveDate] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

--
--

--
--
--
--

CREATE FUNCTION [quant].[fcn_BlackVolatilityConversion_LognormalToNormal]  	
(
	@LognormalVolatility	float	
,	@ForwardRate			float	
,	@StrikeRate				float		
,	@Tenor_Decimal_Years	float	
)	
RETURNS float  
AS
/**************************************************************************************

	Converts a provided lognormal Black volatility assumption to a normal volatility. 


		Example:	


			PRINT	quant.fcn_BlackVolatilityConversion_LognormalToNormal  
						(	
							0.75 	 --	 LognormalVolatility 
						,	0.009 	 --	 ForwardRate 
						,	0.0087	 --	 StrikeRate 
						,	0.249	 --	 Tenor_Decimal_Years	
						)	
			--
			;	


	Date			Action	
	----------		----------------------------
	2016-10-04		Created initial version.	

**************************************************************************************/	
BEGIN
	
	RETURN	CASE WHEN coalesce(@LognormalVolatility,-1) < 0		
				 OR	  coalesce(@ForwardRate,0) <= 0 
				 OR	  coalesce(@StrikeRate,0) <= 0 
				 OR	  coalesce(@Tenor_Decimal_Years,0) <= 0 
				 THEN NULL 
			--
			--  formulas taken from paper "Risk Measures with Normal Distributed 
			--							  Black Options Pricing Model" (2013-06-05)	
			--								by Wenqing Huang
			--	
			--	
			WHEN abs( ( @ForwardRate - @StrikeRate ) / @StrikeRate ) >= 0.001 
			THEN	

	--
	--	V_n = V_b * ( F - K )  *									1	
	--				---------	  ---------------------------------------------------------------------------
	--			  log( F / K )	  1 + (1/24)*(1-(1/120)*((log( F / K ))^2)*T*(V_b)^2 + (1/5760)*(T^2)*(V_b)^4 
	--	
			
	@LognormalVolatility * ( @ForwardRate - @StrikeRate )
						 / log ( @ForwardRate / @StrikeRate ) 
		* ( convert(float,1.0) / ( convert(float,1.0) 
								 + ( convert(float,1.0)/convert(float,24.0) ) * ( convert(float,1.0) 
																				- ( convert(float,1.0)/convert(float,120.0) )
																				  * ( log ( @ForwardRate / @StrikeRate ) ) * ( log ( @ForwardRate / @StrikeRate ) ) )
																				  * @Tenor_Decimal_Years 
																				  * @LognormalVolatility * @LognormalVolatility 
								+ ( convert(float,1.0)/convert(float,5760.0) ) * @Tenor_Decimal_Years * @Tenor_Decimal_Years 
									* @LognormalVolatility * @LognormalVolatility * @LognormalVolatility * @LognormalVolatility ) 
				)	
	
			WHEN abs( ( @ForwardRate - @StrikeRate ) / @StrikeRate ) < 0.001 
			THEN	

	--
	--	V_n = V_b *	sqrt( F * K ) *		 1  +  ( 1/24 ) ( log( F / K ) )^2 				
	--								-------------------------------------------------		
	--								1 + (1/24)*((V_b)^2)*T + (1/5760)*((V_b)^4)*(T^2)		
	--	
																				  
	@LognormalVolatility * POWER( @ForwardRate * @StrikeRate , convert(float,0.5) ) 
						 * ( convert(float,1.0) + ( convert(float,1.0) / convert(float,24.0) ) 
												  * ( log ( @ForwardRate / @StrikeRate ) ) * ( log ( @ForwardRate / @StrikeRate ) ) )	
		/ ( convert(float,1.0) + ( convert(float,1.0) / convert(float,24.0) ) 
									* @LognormalVolatility * @LognormalVolatility * @Tenor_Decimal_Years 
					+ ( convert(float,1.0) / convert(float,5760.0) ) 
					  * @LognormalVolatility * @LognormalVolatility * @LognormalVolatility * @LognormalVolatility 
					  * @Tenor_Decimal_Years * @Tenor_Decimal_Years 
			 )	
			 
		--
		--
		--
		-- 
		ELSE	null	
	--
	--
	END					 												   
	;	

END

GO

--
--
--
--

CREATE FUNCTION [quant].[fcn_BlackVolatilityConversion_NormalToLognormal]  	
(
	@NormalVolatility		float	
,	@ForwardRate			float	
,	@StrikeRate				float	
,	@Tenor_Decimal_Years	float	
)	
RETURNS float  
AS
/**************************************************************************************

	Converts a provided normal Black volatility assumption to lognormal volatility. 


		Example:	


			PRINT	quant.fcn_BlackVolatilityConversion_NormalToLognormal 
						(	
							0.00659833 	--	 NormalVolatility		
						,	0.009 		--	 ForwardRate			
						,	0.0087		--	 StrikeRate				
						,	0.249		--	 Tenor_Decimal_Years	
						)	
			--
			;	


	Date			Action	
	----------		----------------------------
	2016-10-04		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--
		
		IF	coalesce(@NormalVolatility,-1) < 0		
		OR	coalesce(@ForwardRate,0) <= 0 
		OR	coalesce(@StrikeRate,0) <= 0 
		OR	coalesce(@Tenor_Decimal_Years,0) <= 0 
		BEGIN 
			RETURN null ;	
		END		

	--
	-- 

	DECLARE		@InitialGuess				float		=	0.10	
	--
	,			@PreviousGuess				float		
	,			@PreviousGuess_Conversion	float		
	,			@CurrentGuess				float		
	,			@CurrentGuess_Conversion	float		
	--	
	,			@InitialVariation			float		=	0.05	
	--
	,			@CurrentVariation			float		
	--
	,			@VariationMultiplier		float		=	0.50	
	--
	--
	,			@PrecisionThreshold			float		=	0.0000001	
	--
	--
	,			@CurrentIteration			int				
	,			@MaxIterations				int			=	10000	
	--
	--		
	;	

		--
		--	prepare for initial iteration	
		--	
	
		SELECT	@CurrentGuess = @InitialGuess
		,		@CurrentIteration = 1
		,		@CurrentVariation = @InitialVariation 	
		--
		;	

			SET @CurrentGuess_Conversion = quant.fcn_BlackVolatilityConversion_LognormalToNormal
												(
													@CurrentGuess 
												,	@ForwardRate 
												,	@StrikeRate		
												,	@Tenor_Decimal_Years 
												)	
			--
			;	
	
		--
		--	perform iterations	
		--	
		
		WHILE @CurrentIteration <= @MaxIterations 
		AND	  ABS( @CurrentGuess_Conversion - @NormalVolatility ) >= @PrecisionThreshold 
		BEGIN 
		
			--
			--

			SET @PreviousGuess = @CurrentGuess ; 
			SET @PreviousGuess_Conversion = @CurrentGuess_Conversion 
				
			--
			--

			IF @CurrentGuess_Conversion < @NormalVolatility 
			BEGIN 
			
				SET @CurrentGuess = @CurrentGuess + @CurrentVariation ; 

			END		
			ELSE BEGIN 

				SET @CurrentGuess = @CurrentGuess - @CurrentVariation ; 

			END		
			
			--
			--

				SET @CurrentGuess_Conversion = quant.fcn_BlackVolatilityConversion_LognormalToNormal
													(
														@CurrentGuess 
													,	@ForwardRate 
													,	@StrikeRate		
													,	@Tenor_Decimal_Years 
													)	
				--	
				;	

			--	
			--	
				
				IF ABS( @CurrentGuess_Conversion - @NormalVolatility ) 
				 >= ABS( @PreviousGuess_Conversion - @NormalVolatility ) 
				BEGIN 
					
					SET @CurrentGuess = @PreviousGuess ; 
					SET @CurrentVariation = @CurrentVariation * @VariationMultiplier ; 

				END		
			
			--
			--
			
			SET @CurrentIteration += 1 ; 

			--
			--

		END		
		--
		;	

		--
		--	

		IF ABS( @CurrentGuess_Conversion - @NormalVolatility ) < @PrecisionThreshold 
		BEGIN 
			RETURN @CurrentGuess ; 
		END		
		--
		;	

		RETURN	null 
		--
		;	

END

GO

--
--

CREATE FUNCTION [quant].[fcn_StockOptionPrice_BlackScholesModel]
(
	@CallOrPut					varchar(4)	
--
,	@TimeToExpiry				float	
--	
,	@CurrentPrice 				float		
,	@StrikePrice  				float		
--	
,	@Volatility					float		
,	@RiskFreeRate 				float		
--
,	@ContinuousDividendYield	float				
--
)
RETURNS TABLE  
AS 
/**************************************************************************************

	Returns the "Black Scholes" Stock Option Price for given input parameters:	

		c = S*N(d1) - K*exp(-rT)*N(d2) 

		p = K*exp(-rT)*N(-d2) - S*N(-d1)
	 

			d1 = [ ln(S/K) + ( r + (v^2)/2)*T ) ] / v*T^(1/2) 

			d2 = d1 - v*T^(1/2) 


				c - call price
				p - put price 
				S - current stock price 
				K - strike price 
				T - time to expiry (years, trading days) 
				v - volatility 
				r - risk free rate, continuously compounded 
				N - standard normal cumulative distribution function 
		
		
		Assumptions:	
			- European options 
			- No dividends paid (unless simple @ContinuousDividendYield is provided, in which case the option value is estimated without regard to exact payment dates) 
			- market is frictionless (no bid/ask spread, transaction costs)
			- investments can be made of any size at any time
			- Price process is log-normal  
			- No arbitrage 


		Example:	

			
			SELECT	A.OptionType	
			,		X.Volatility	
			,		Y.*		
			FROM	(
						VALUES	( 'Call' ) 
						,		( 'Put'	 )	
					)	
						A	( OptionType )	
			CROSS JOIN  (
							VALUES 	( 0.15 ) 
							,		( 0.16 ) 
							,	   	( 0.17 ) 
							,	   	( 0.18 ) 
							,		( 0.19 ) 
							,		( 0.20 ) 
						)	
							X	( Volatility ) 
			OUTER APPLY quant.fcn_StockOptionPrice_BlackScholesModel  	
							( 
								A.OptionType	-- CallOrPut 
							--
							,	2.000			-- TimeToExpiry		
							--
							,	55.50			-- CurrentPrice 
							,	60.00 			-- StrikePrice 	
							--	
							,	X.Volatility	-- Volatility	
							,	0.005			-- RiskFreeRate  
							--
							,	null	
							)	
								Y	
			--	
			;	


	Date			Action							
	----------		----------------------------	
	2017-01-30		Created initial version.		
	2017-03-13		Added DiscountFactor_RiskFreeRate as output column. 

**************************************************************************************/	
RETURN  (
				SELECT		CASE WHEN coalesce(@Volatility,0) <= 0 
								 OR	  coalesce(@TimeToExpiry,0) <= 0 
								 OR	  coalesce(@CurrentPrice,0) <= 0 
								 OR	  coalesce(@StrikePrice,0) <= 0		
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' ) 
								 THEN @CurrentPrice * Y.DividendMultiplier * math.fcn_NormalCumulativeDistribution ( Y.d1, 0, 1 ) 
								 - @StrikePrice * Y.DF * math.fcn_NormalCumulativeDistribution ( Y.d2, 0, 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' ) 
								 THEN @StrikePrice * Y.DF * math.fcn_NormalCumulativeDistribution ( -Y.d2, 0, 1 ) 
								 - @CurrentPrice * Y.DividendMultiplier * math.fcn_NormalCumulativeDistribution ( -Y.d1, 0, 1 )	
							END					OptionFairValue		
				--	
				,			CASE WHEN coalesce(@Volatility,0) <= 0 
								 OR	  coalesce(@TimeToExpiry,0) <= 0 
								 OR	  coalesce(@CurrentPrice,0) <= 0 
								 OR	  coalesce(@StrikePrice,0) <= 0	
								 THEN NULL 
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN Y.DividendMultiplier * math.fcn_NormalCumulativeDistribution ( Y.d1 , 0 , 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN Y.DividendMultiplier * math.fcn_NormalCumulativeDistribution ( - Y.d1 , 0 , 1 )		
							END					Delta  		
				--	
				,			CASE WHEN coalesce(@Volatility,0) <= 0 
								 OR	  coalesce(@TimeToExpiry,0) <= 0 
								 OR	  coalesce(@CurrentPrice,0) <= 0 
								 OR	  coalesce(@StrikePrice,0) <= 0		
								 THEN NULL 
								 ELSE Y.DividendMultiplier 
								    * POWER( convert(float,1.0) / @TimeToExpiry / convert(float,2.0) / Pi() , convert(float,0.5) )
									* exp( - Y.d1 * Y.d1 / convert(float,2.0) )	
									/ @Volatility / @CurrentPrice	
							END					Gamma	
				--
				,			CASE WHEN coalesce(@Volatility,0) <= 0 
								 OR	  coalesce(@TimeToExpiry,0) <= 0 
								 OR	  coalesce(@CurrentPrice,0) <= 0 
								 OR	  coalesce(@StrikePrice,0) <= 0	
								 THEN NULL 
								 ELSE Y.DividendMultiplier
								    * @CurrentPrice * POWER( @TimeToExpiry / convert(float,2.0) / Pi() , convert(float,0.5) )
									* exp( - Y.d1 * Y.d1 / convert(float,2.0) )		
							END					Vega 	
				--
				,			CASE WHEN coalesce(@Volatility,0) <= 0 
								 OR	  coalesce(@TimeToExpiry,0) <= 0 
								 OR	  coalesce(@CurrentPrice,0) <= 0 
								 OR	  coalesce(@StrikePrice,0) <= 0	
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN - Y.DividendMultiplier
								    * @CurrentPrice * @Volatility  
									/ convert(float,2.0) / POWER( @TimeToExpiry , convert(float,0.5) ) 
									* exp( - Y.d1 * Y.d1 / convert(float,2.0) )	
									/ POWER( convert(float,2.0) * Pi() , convert(float,0.5) ) 

								 +  coalesce(@ContinuousDividendYield,0) * @CurrentPrice * math.fcn_NormalCumulativeDistribution ( Y.d1 , 0 , 1 ) 
									* Y.DividendMultiplier 

								 -	@RiskFreeRate * @StrikePrice * Y.DF 
									* math.fcn_NormalCumulativeDistribution ( Y.d2 , 0 , 1 ) 

								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN - Y.DividendMultiplier
								    * @CurrentPrice * @Volatility  
									/ convert(float,2.0) / POWER( @TimeToExpiry , convert(float,0.5) ) 
									* exp( - Y.d1 * Y.d1 / convert(float,2.0) )	
									/ POWER( convert(float,2.0) * Pi() , convert(float,0.5) ) 

								 -  coalesce(@ContinuousDividendYield,0) * @CurrentPrice * math.fcn_NormalCumulativeDistribution ( - Y.d1 , 0 , 1 ) 
									* Y.DividendMultiplier 

								 +	@RiskFreeRate * @StrikePrice * Y.DF 
									* math.fcn_NormalCumulativeDistribution ( - Y.d2 , 0 , 1 ) 
										
							END					Theta		
				--
				,			CASE WHEN coalesce(@Volatility,0) <= 0 
								 OR	  coalesce(@TimeToExpiry,0) <= 0 
								 OR	  coalesce(@CurrentPrice,0) <= 0 
								 OR	  coalesce(@StrikePrice,0) <= 0	
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN @StrikePrice * @TimeToExpiry * Y.DF * math.fcn_NormalCumulativeDistribution ( Y.d2, 0, 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN - @StrikePrice * @TimeToExpiry * Y.DF * math.fcn_NormalCumulativeDistribution ( - Y.d2, 0, 1 )	
							END					Rho			
				--
				--	
				,			Y.DF		DiscountFactor_RiskFreeRate			
				--
				--	
				FROM	(
							SELECT	convert(float,X.d1Numerator) / convert(float,X.d1Denominator)	as	d1 
							,		convert(float,X.d1Numerator) / convert(float,X.d1Denominator) 
																- convert(float,X.d1Denominator)	as	d2 		
							--	
							,		exp( -@RiskFreeRate * @TimeToExpiry )							as	DF	 	
							--
							,		CASE WHEN coalesce(@ContinuousDividendYield,0) < 0 
										 THEN NULL 
										 WHEN @ContinuousDividendYield >= 0 
										 THEN exp( -@ContinuousDividendYield * @TimeToExpiry )	
										 ELSE convert(float,1.0)	
									END																as	DividendMultiplier	
							--
							FROM	(
										VALUES	
										(
											log(convert(float,@CurrentPrice/@StrikePrice))
										+	( @RiskFreeRate	+ CASE WHEN coalesce(@ContinuousDividendYield,0) < 0 
																   THEN NULL 
																   WHEN @ContinuousDividendYield >= 0 
																   THEN - @ContinuousDividendYield 
																   ELSE convert(float,0.0)	
															  END	
											+ @Volatility*@Volatility*convert(float,0.5) ) * @TimeToExpiry	
											
										,	@Volatility * POWER(@TimeToExpiry,convert(float,0.5))	
											
										)	
									)	
										X	( d1Numerator , d1Denominator )		
						)		
							Y	
				--	
				--	
		)
GO

--
--

CREATE FUNCTION [quant].[fcn_BondOptionPrice_LognormalModel]
(
	@CallOrPut			varchar(4)	
--
,	@Notional			float	
,	@ValuationDate		date	
,	@ExpirationDate		date	
,	@SettlementDate		date	
--	
,	@ForwardPrice 		float		
,	@StrikePrice 		float		
--	
,	@PriceVolatility	float		
,	@RiskFreeRate 		float		
--	
)
RETURNS TABLE  
AS 
/**************************************************************************************

	Returns the "Black's Model for Bond Options" Price for given input parameters:	

		c = DF * ( F*N(d1) - K*N(d2) )		

		p = DF * ( K*N(-d2) - F*N(-d1) )	
	 

			d1 = [ ln(F/K) + (v^2)/2)*T ] / v*T^(1/2)	

			d2 = d1 - v*T^(1/2) 


				c - call price
				p - put price 
				F - current forward rate 
				K - strike rate 
				T - time to expiry (time between valuation date and expiration date, in years) 
				v - price volatility 
				DF - e^(-R*T) where R is the Risk-Free Rate, continuously compounded 
				N - standard normal cumulative distribution function 
		
		
		Assumptions:	
			- European options 
			- market is frictionless (no bid/ask spread, transaction costs)
			- investments can be made of any size at any time
			- Price process is log-normal  
			- No arbitrage 


		Example:	

			
			SELECT	A.OptionType	
			,		X.Volatility	
			,		Y.*		
			FROM	(
						VALUES	( 'Call' ) 
						,		( 'Put'	 )	
					)	
						A	( OptionType )	
			CROSS JOIN  (
							VALUES  ( 0.010 ) 
							,		( 0.015 ) 
							,		( 0.020 )
							,		( 0.025 ) 
							,	    ( 0.0274894405515683 ) 
							,		( 0.030 ) 
							,		( 0.035 ) 
						)	
							X	( Volatility ) 
			OUTER APPLY quant.fcn_BondOptionPrice_LognormalModel 	
							( 
								A.OptionType		-- Call or Put 
							--
							,	100					-- Notional		
							,	'Sep 13, 2016'		-- ValuationDate	
							,	'Oct 13, 2016'		-- ExpirationDate 	
							,	'Oct 18, 2016'		-- SettlementDate 
							--
							,	99.9780831465262	-- ForwardPrice  
							,	100.00 				-- StrikePrice 	
							--	
							,	X.Volatility		-- PriceVolatility	
							,	0.005				-- RiskFreeRate  
							)	
								Y	
			--	
			;	


	Date			Action	
	----------		----------------------------
	2016-10-24		Created initial version.	

**************************************************************************************/	
RETURN  (
				SELECT		@Notional / convert(float,100.0) * 
							CASE WHEN coalesce(X.TimeToExpiry,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* ( @ForwardPrice * math.fcn_NormalCumulativeDistribution ( X.d1, 0, 1 ) 
									  - @StrikePrice * math.fcn_NormalCumulativeDistribution ( X.d2, 0, 1 ) ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* ( @StrikePrice * math.fcn_NormalCumulativeDistribution ( -X.d2, 0, 1 ) 
									  - @ForwardPrice * math.fcn_NormalCumulativeDistribution ( -X.d1, 0, 1 ) ) 
								 ELSE NULL 
							END					OptionFairValue 		
				--
				,			CASE WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToSettlement ) * math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN - exp( -@RiskFreeRate * X.TimeToSettlement ) * math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
								 ELSE NULL 
							END					Delta  		
				--	
				,			CASE WHEN coalesce(@PriceVolatility,0) = 0 
								 OR	  coalesce(X.TimeToExpiry,0) <= 0 
								 OR	  coalesce(@ForwardPrice,0) = 0 
								 THEN NULL 
								 ELSE exp( -@RiskFreeRate * X.TimeToSettlement ) 
									/ @ForwardPrice / @PriceVolatility  
									/ POWER( X.TimeToExpiry * convert(float,2.0) * Pi() , convert(float,0.5) )
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
							END					Gamma	
				--	
				,			CASE WHEN coalesce(X.TimeToExpiry,0) <= 0 
								 THEN NULL 
								 ELSE exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* @ForwardPrice 
									* POWER( X.TimeToExpiry / convert(float,2.0) / Pi() , convert(float,0.5) )
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
							END					Vega 	
				-- 
				,			CASE WHEN coalesce(X.TimeToExpiry,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN - @ForwardPrice * @PriceVolatility 
									* exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* POWER( convert(float,1.0) / X.TimeToExpiry / convert(float,8.0) / Pi() , convert(float,0.5) ) 
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
								 +	@RiskFreeRate * @ForwardPrice * exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
								 -  @RiskFreeRate * @StrikePrice * exp( -@RiskFreeRate * X.TimeToSettlement )  
									* math.fcn_NormalCumulativeDistribution ( X.d2 , 0 , 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN - @ForwardPrice * @PriceVolatility 
									* exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* POWER( convert(float,1.0) / X.TimeToExpiry / convert(float,8.0) / Pi() , convert(float,0.5) ) 
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
								 -	@RiskFreeRate * @ForwardPrice * exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
								 +  @RiskFreeRate * @StrikePrice * exp( -@RiskFreeRate * X.TimeToSettlement )  
									* math.fcn_NormalCumulativeDistribution ( - X.d2 , 0 , 1 ) 
								 ELSE NULL 
							END					Theta		  		
				--
				,		-	X.TimeToExpiry * 
							CASE WHEN coalesce(X.TimeToExpiry,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* ( @ForwardPrice * math.fcn_NormalCumulativeDistribution ( X.d1, 0, 1 ) 
									  - @StrikePrice * math.fcn_NormalCumulativeDistribution ( X.d2, 0, 1 ) ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN exp( -@RiskFreeRate * X.TimeToSettlement ) 
									* ( @StrikePrice * math.fcn_NormalCumulativeDistribution ( -X.d2, 0, 1 ) 
									  - @ForwardPrice * math.fcn_NormalCumulativeDistribution ( -X.d1, 0, 1 ) ) 
								 ELSE NULL 
							END							Rho		
				--	
				FROM		(
								SELECT	CASE WHEN coalesce(@PriceVolatility,0) = 0 
											 OR	  coalesce(Y.TimeToExpiry,0) <= 0 
											 THEN NULL 
											 ELSE ( log( @ForwardPrice / @StrikePrice ) 
												+ @PriceVolatility * @PriceVolatility / convert(float,2.0) * Y.TimeToExpiry ) 
												/ ( @PriceVolatility * POWER(Y.TimeToExpiry,convert(float,0.5)) ) 
										END		
										as	d1	
								,		CASE WHEN coalesce(@PriceVolatility,0) = 0 
											 OR	  coalesce(Y.TimeToExpiry,0) <= 0 
											 THEN NULL 
											 ELSE ( log( @ForwardPrice / @StrikePrice ) 
												- @PriceVolatility * @PriceVolatility / convert(float,2.0) * Y.TimeToExpiry ) 
												/ ( @PriceVolatility * POWER(Y.TimeToExpiry,convert(float,0.5)) ) 
										END		
										as	d2 	
								--	
								,		Y.TimeToExpiry	
								,		CASE WHEN Y.TimeToSettlement >= Y.TimeToExpiry 
											 THEN Y.TimeToSettlement 
											 ELSE Y.TimeToExpiry 
										END		TimeToSettlement	
								--	
								FROM	(
											VALUES	( convert(float, datediff(day,@ValuationDate,@ExpirationDate)) / convert(float,365.0) 
													, convert(float, datediff(day,@ValuationDate,@SettlementDate)) / convert(float,365.0) )
										)	
											Y	( TimeToExpiry , TimeToSettlement )	
							)	
								X	
				--
				--	
		)
GO

--
--

CREATE FUNCTION [quant].[fcn_InterestRateOptionPrice_LognormalModel]
(
	@CallOrPut			varchar(4)	
--
,	@Notional			float	
,	@StartDate			date	
,	@EndDate			date	
,	@ValuationDate		date	
--	
,	@ForwardRate 		float		
,	@StrikeRate 		float		
--	
,	@YieldVolatility	float		
,	@RiskFreeRate 		float		
--	
)
RETURNS TABLE  
AS 
/**************************************************************************************

	Returns the "Black '76 Model" Option Price for given input parameters:	

		c = DF * ( F*N(d1) - K*N(d2) ) 

		p = DF * ( K*N(-d2) - F*N(-d1) ) 
	 

			d1 = [ ln(F/K) + ((v^2)/2)*T ] / v*T^(1/2) 

			d2 = d1 - v*T^(1/2) 


				c - call price
				p - put price 
				F - current forward rate 
				K - strike rate 
				T - time to expiry (time between valuation date and start date, in years) 
				v - yield volatility 
				DF - e^(-R*T') where R is the Risk-Free Rate and T' is the time between the valuation date and end date, in years 
				N - standard normal cumulative distribution function 
		
		
		Assumptions:	
			- European options 
			- market is frictionless (no bid/ask spread, transaction costs)
			- investments can be made of any size at any time
			- Price process is log-normal  
			- No arbitrage 


		Example:	

			
			SELECT	A.OptionType	
			,		X.Volatility	
			,		Y.*		
			FROM	(
						VALUES	( 'Call' ) 
						,		( 'Put'	 )	
					)	
						A	( OptionType )	
			CROSS JOIN  (
							VALUES  ( 0.25 ) 
							,		( 0.50 ) 
							,	    ( 0.75 ) 
							,	    ( 1.00 ) 
							,		( 1.25 ) 
						)	
							X	( Volatility ) 
			OUTER APPLY quant.fcn_InterestRateOptionPrice_LognormalModel 	
							( 
								A.OptionType	-- CallOrPut 
							--
							,	100				-- Notional		
							,	'Dec 13, 2016'	-- StartDate	
							,	'Mar 12, 2017'	-- EndDate	
							,	'Sep 13, 2016'	-- ValuationDate	
							--
							,	0.0085			-- ForwardRate	 
							,	0.0087 			-- StrikeRate	
							--	
							,	X.Volatility	-- YieldVolatility	
							,	0.005			-- RiskFreeRate  
							)	
								Y	
			--
			;	


	Date			Action	
	----------		----------------------------
	2016-10-03		Created initial version.	
	2016-10-06		Changed sign of Theta.
	2017-03-13		Added DiscountFactor_RiskFreeRate as output column. 

**************************************************************************************/	
RETURN  (
				SELECT		@Notional * ( X.TimeToEndDate - X.TimeToStartDate ) * 
							CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* ( @ForwardRate * math.fcn_NormalCumulativeDistribution ( X.d1, 0, 1 ) 
									  - @StrikeRate * math.fcn_NormalCumulativeDistribution ( X.d2, 0, 1 ) ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* ( @StrikeRate * math.fcn_NormalCumulativeDistribution ( -X.d2, 0, 1 ) 
									  - @ForwardRate * math.fcn_NormalCumulativeDistribution ( -X.d1, 0, 1 ) ) 
								 ELSE NULL 
							END					OptionFairValue 		
				--
				,			CASE WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) * math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN - exp( -@RiskFreeRate * X.TimeToEndDate ) * math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
								 ELSE NULL 
							END					Delta  		
				--	
				,			CASE WHEN coalesce(@YieldVolatility,0) = 0 
								 OR	  coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 OR	  coalesce(@ForwardRate,0) = 0 
								 THEN NULL 
								 ELSE exp( -@RiskFreeRate * X.TimeToEndDate ) 
									/ @ForwardRate / @YieldVolatility  
									/ POWER( X.TimeToStartDate * convert(float,2.0) * Pi() , convert(float,0.5) )
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
							END					Gamma	
				--	
				,			CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL 
								 ELSE exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* @ForwardRate 
									* POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) )
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
							END					Vega 	
				-- 
				,			CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN - @ForwardRate * @YieldVolatility 
									* exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* POWER( convert(float,1.0) / X.TimeToStartDate / convert(float,8.0) / Pi() , convert(float,0.5) ) 
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
								 +	@RiskFreeRate * @ForwardRate * exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
								 -  @RiskFreeRate * @StrikeRate * exp( -@RiskFreeRate * X.TimeToEndDate )  
									* math.fcn_NormalCumulativeDistribution ( X.d2 , 0 , 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN - @ForwardRate * @YieldVolatility 
									* exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* POWER( convert(float,1.0) / X.TimeToStartDate / convert(float,8.0) / Pi() , convert(float,0.5) ) 
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
								 -	@RiskFreeRate * @ForwardRate * exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
								 +  @RiskFreeRate * @StrikeRate * exp( -@RiskFreeRate * X.TimeToEndDate )  
									* math.fcn_NormalCumulativeDistribution ( - X.d2 , 0 , 1 ) 
								 ELSE NULL 
							END					Theta		  		
				--
				,		-	X.TimeToStartDate * 
							CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* ( @ForwardRate * math.fcn_NormalCumulativeDistribution ( X.d1, 0, 1 ) 
									  - @StrikeRate * math.fcn_NormalCumulativeDistribution ( X.d2, 0, 1 ) ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* ( @StrikeRate * math.fcn_NormalCumulativeDistribution ( -X.d2, 0, 1 ) 
									  - @ForwardRate * math.fcn_NormalCumulativeDistribution ( -X.d1, 0, 1 ) ) 
								 ELSE NULL 
							END							Rho		
				--		
				--	
				,			exp( -@RiskFreeRate * X.TimeToEndDate )		DiscountFactor_RiskFreeRate			
				--
				--	
				FROM		(
								SELECT	CASE WHEN coalesce(@YieldVolatility,0) = 0 
											 OR	  coalesce(Y.TimeToStartDate,0) <= 0 
											 THEN NULL 
											 ELSE ( log( @ForwardRate / @StrikeRate ) 
												+ @YieldVolatility * @YieldVolatility / convert(float,2.0) * Y.TimeToStartDate ) 
												/ ( @YieldVolatility * POWER(Y.TimeToStartDate,convert(float,0.5)) ) 
										END		
										as	d1	
								,		CASE WHEN coalesce(@YieldVolatility,0) = 0 
											 OR	  coalesce(Y.TimeToStartDate,0) <= 0 
											 THEN NULL 
											 ELSE ( log( @ForwardRate / @StrikeRate ) 
												+ @YieldVolatility * @YieldVolatility / convert(float,2.0) * Y.TimeToStartDate ) 
												/ ( @YieldVolatility * POWER(Y.TimeToStartDate,convert(float,0.5)) )
										
												- ( @YieldVolatility * POWER(Y.TimeToStartDate,convert(float,0.5)) ) 
										
										END		
										as	d2 	
								--	
								,		Y.TimeToStartDate 
								,		Y.TimeToEndDate		
								--	
								FROM	(
											VALUES	( convert(float, datediff(day,@ValuationDate,@StartDate)) / convert(float,365.0) 
													, convert(float, datediff(day,@ValuationDate,@EndDate) + 1) / convert(float,365.0) )
										)	
											Y	( TimeToStartDate , TimeToEndDate )	
							)	
								X	
				--
				--	
		)
GO

--
--

CREATE FUNCTION [quant].[fcn_InterestRateOptionPrice_NormalModel]
(
	@CallOrPut			varchar(4)	
--
,	@Notional			float	
,	@StartDate			date	
,	@EndDate			date	
,	@ValuationDate		date	
--	
,	@ForwardRate 		float		
,	@StrikeRate 		float		
--	
,	@YieldVolatility	float		
,	@RiskFreeRate 		float		
--	
)
RETURNS TABLE  
AS 
/**************************************************************************************

	Returns the "Normal Black Scholes Model" Option Price for given input parameters:	

		c = DF * [ (F-K)*N(d1) + v*((T/(2Pi))^(1/2))*e^(-((d1)^2)/2) ] 

		p = DF * [ (K-F)*N(-d1) + v*((T/(2Pi))^(1/2))*e^(-((d1)^2)/2) ] 
	 

			d1 = ( F - K ) / ( v * T^(1/2) ) 
			

				c - call price
				p - put price 
				F - current forward rate 
				K - strike rate 
				T - time to expiry (time between valuation date and start date, in years) 
				v - yield volatility 
				DF - e^(-R*T') where R is the Risk-Free Rate and T' is the time between the valuation date and end date, in years 
				N - standard normal cumulative distribution function 
		
		
		Assumptions:	
			- European options 
			- market is frictionless (no bid/ask spread, transaction costs)
			- investments can be made of any size at any time
			- Price process is normal  
			- No arbitrage


		Example:	

			
			SELECT	A.OptionType	
			,		X.Volatility	
			,		Y.*		
			FROM	(
						VALUES	( 'Call' ) 
						,		( 'Put'	 )	
					)	
						A	( OptionType )	
			CROSS JOIN  (
							VALUES  ( 0.001 )  
							,		( 0.005 )  
							,	    ( 0.01  )  
							,	    ( 0.02  )  
							,		( 0.03  )  
						)	                   
							X	( Volatility ) 
			OUTER APPLY quant.fcn_InterestRateOptionPrice_NormalModel 	
							( 
								A.OptionType	-- CallOrPut 
							--
							,	100				-- Notional		
							,	'Dec 13, 2016'	-- StartDate	
							,	'Mar 12, 2017'	-- EndDate	
							,	'Sep 13, 2016'	-- ValuationDate	
							--
							,	0.009			-- ForwardRate	 
							,	0.0087 			-- StrikeRate	
							--	
							,	X.Volatility	-- YieldVolatility	
							,	0.005			-- RiskFreeRate  
							)	
								Y	
			--
			;	


	Date			Action	
	----------		----------------------------
	2016-10-03		Created initial version.	
	2016-10-06		Changed sign of Theta.
	2017-03-13		Added DiscountFactor_RiskFreeRate as output column. 

**************************************************************************************/	
RETURN  (
				SELECT		@Notional * ( X.TimeToEndDate - X.TimeToStartDate ) * 
							CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* (		
										 ( @ForwardRate - @StrikeRate ) * math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
										 + @YieldVolatility * POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) ) 
													   * exp( - X.d1 * X.d1 / convert(float,2.0) )	
									  )		
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* (		
										 ( @StrikeRate - @ForwardRate ) * math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
										 + @YieldVolatility * POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) ) 
													   * exp( - X.d1 * X.d1 / convert(float,2.0) )	
									  )		
								 ELSE NULL 
							END					OptionFairValue 		
				--
				,			CASE WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) * math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN - exp( -@RiskFreeRate * X.TimeToEndDate ) * math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
								 ELSE NULL 
							END					Delta  		
				--	
				,			CASE WHEN coalesce(@YieldVolatility,0) = 0 
								 OR	  coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL 
								 ELSE exp( -@RiskFreeRate * X.TimeToEndDate ) 
									/ @YieldVolatility  
									/ POWER( X.TimeToStartDate * convert(float,2.0) * Pi() , convert(float,0.5) )
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
							END					Gamma	
				--	
				,			CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL 
								 ELSE exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) )
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
							END					Vega 	
				-- 
				,		-	CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN -@RiskFreeRate 
									* exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* (		
										 ( @ForwardRate - @StrikeRate ) * math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
										 + @YieldVolatility * POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) ) 
													   * exp( - X.d1 * X.d1 / convert(float,2.0) )	
									  )		
								 +	exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* @YieldVolatility / convert(float,2.0) / POWER( X.TimeToStartDate * convert(float,2.0) * Pi() , convert(float,0.5) ) 
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN -@RiskFreeRate 
									* exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* (		
										 ( @StrikeRate - @ForwardRate ) * math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
										 + @YieldVolatility * POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) ) 
													   * exp( - X.d1 * X.d1 / convert(float,2.0) )	
									  )	
								 +	exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* @YieldVolatility / convert(float,2.0) / POWER( X.TimeToStartDate * convert(float,2.0) * Pi() , convert(float,0.5) ) 
									* exp( - X.d1 * X.d1 / convert(float,2.0) )	
								 ELSE NULL 
							END					Theta		  		
				--
				,		-	X.TimeToStartDate * 
							CASE WHEN coalesce(X.TimeToStartDate,0) <= 0 
								 OR	  coalesce(X.TimeToEndDate,0) <= 0 
								 THEN NULL	
								 WHEN @CallOrPut IN ( 'Call' , 'C' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* (		
										 ( @ForwardRate - @StrikeRate ) * math.fcn_NormalCumulativeDistribution ( X.d1 , 0 , 1 ) 
										 + @YieldVolatility * POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) ) 
													   * exp( - X.d1 * X.d1 / convert(float,2.0) )	
									  )		
								 WHEN @CallOrPut IN ( 'Put' , 'P' )	
								 THEN exp( -@RiskFreeRate * X.TimeToEndDate ) 
									* (		
										 ( @StrikeRate - @ForwardRate ) * math.fcn_NormalCumulativeDistribution ( - X.d1 , 0 , 1 ) 
										 + @YieldVolatility * POWER( X.TimeToStartDate / convert(float,2.0) / Pi() , convert(float,0.5) ) 
													   * exp( - X.d1 * X.d1 / convert(float,2.0) )	
									  )		
								 ELSE NULL 
							END					Rho		
				--
				--	
				,			exp( -@RiskFreeRate * X.TimeToEndDate )		DiscountFactor_RiskFreeRate			
				--
				--	
				FROM		(
								SELECT	CASE WHEN coalesce(@YieldVolatility,0) = 0 
											 OR	  coalesce(Y.TimeToStartDate,0) <= 0 
											 THEN NULL 
											 ELSE ( @ForwardRate - @StrikeRate ) 
												/ @YieldVolatility / POWER(Y.TimeToStartDate, convert(float,0.5)) 
										END		
										as	d1	
								--	
								,		Y.TimeToStartDate 
								,		Y.TimeToEndDate		
								--	
								FROM	(
											VALUES	( convert(float, datediff(day,@ValuationDate,@StartDate)) / convert(float,365.0) 
													, convert(float, datediff(day,@ValuationDate,@EndDate) + 1) / convert(float,365.0) )
										)	
											Y	( TimeToStartDate , TimeToEndDate )	
							)	
								X	
				--
				--	
		)
GO

--
--

CREATE FUNCTION [quant].[fcn_CashflowSeries_YieldToMaturity] 
(
	@Input_Cashflows	quant.UTT_CashflowSeriesComponent   READONLY	
,	@Input_Prices		quant.UTT_CashflowSeriesPrice		READONLY	
--	
--,	@DayCountConvention_ShortName		varchar(20)		
--
,	@MaxIterations						int				
--
)
RETURNS 
@Output TABLE 
(
	CashflowSeriesPriceID	int		not null	
--
,	CashflowSeriesID		int		null 
,	EffectiveDate			date	not null	
--	
,	Price					float	not null	
,	YieldToMaturity			float	not null	
--
,	Iterations				int		null	
,	FinalError				float	null	
--
,	UNIQUE  (
				CashflowSeriesPriceID	
			)	
,	UNIQUE  (
				CashflowSeriesID
			,	EffectiveDate	
			)	
--	
)
AS
/**************************************************************************************

	  Uses a root-finding algorithm (Newton's method) to find the yield-to-maturity 
	   for a series of cashflows with a corresponding price. 


		Currently cashflows are assumed to be only positive amounts  
		 with at least one cashflow occuring after the given price effective date. 
		

		
		Example:	

			--
			--

			DECLARE @t_Cashflows AS quant.UTT_CashflowSeriesComponent ; 
			DECLARE @t_Prices AS quant.UTT_CashflowSeriesPrice ; 

			INSERT INTO @t_Cashflows 
			(
				CashflowDate	
			,	Amount	
			)	
				VALUES	( 'Sep 1, 2016' , 100  ) 
				,		( 'Dec 1, 2016' , 100  ) 
				,		( 'Mar 1, 2017' , 4100 ) 
				--	
				;	

			INSERT INTO @t_Prices 
			(
				EffectiveDate 
			,	Price	
			)	
				VALUES	( 'May 29, 2016' , 4000 )
				--	
				;	

			--
			--

			SELECT		Y.* 
			FROM		quant.fcn_CashflowSeries_YieldToMaturity
							(	
								@t_Cashflows 	--	Input_Cashflows		
							,	@t_Prices 		--	Input_Prices	
					    --  ,	'30/360'		--	DayCountConvention_ShortName		
							,	null			--	MaxIterations
							)			
								Y
			--	
			ORDER BY	Y.CashflowSeriesPriceID	ASC		
			--	
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2016-05-29		Created initial version. 
	2016-06-01		Added FinalError column to output. 
	2016-06-05		Inflating polynomial coefficients before searching for a root. 
	2016-06-13		Logic changes for cases where subsequent guesses diverge further from root. 
	2016-07-11		End loop for a single request if past four iterations haven't improved estimate. 
	2017-03-29		Appropriately handling input cashflows on the associated pricing date. 
					Not returning a result if input cashflows are before the associated pricing date. 
	2022-04-10		Removed (commented) @DayCountConvention_ShortName parameter. 

**************************************************************************************/	
BEGIN
	
	--
	--

		--
		--

 --------  DECLARE		@Default_DayCountConvention_ShortName		varchar(20)		=	'30/360'	
 --------  --	
 --------  ,			@Default_Compound_Frequency_Name			varchar(20)		=	'Annual'	
 --------  --	
 --------  ;	
		DECLARE		@Loop_InitialGuess							float			=	0.0250 
		,			@Loop_ZeroDerivativeIncrement				float			=	0.00066
		--
		,			@CoefficientInflationFactor					float			=	1000000 
		--
		,			@Precision_Threshold						float			=	0.0000000000001 
		--
		,			@Iteration									int		
		,			@Default_MaxIterations						int				=	500
		--
		;	

	--
	--

	IF @MaxIterations IS NULL 
	OR @MaxIterations <= 0 
	BEGIN 
		SET @MaxIterations = @Default_MaxIterations 
	END		

---- IF @DayCountConvention_ShortName IS NULL 
---- BEGIN 
---- 	SET @DayCountConvention_ShortName = @Default_DayCountConvention_ShortName 
---- END		

---- IF ( SELECT COUNT(*) FROM quant.DayCountConvention X WHERE X.ShortName = @DayCountConvention_ShortName ) = 0 
---- BEGIN	
---- 	RETURN ; 
---- END		

	--
	--

	DECLARE	@Input_Cashflows_Cache TABLE	
	(
		ID						int			not null		primary key		
	--
	,	CashflowSeriesID		int			null	
	,	CashflowDate			date		not null 
	,	Amount					float		not null	
	--	
	,	UNIQUE	(
					CashflowSeriesID	
				,	CashflowDate	
				)	
	)	
	--	
	;	
	
	DECLARE	@Input_Prices_Cache	TABLE	
	(
		ID						int			not null		primary key		
	--	
	,	CashflowSeriesID		int			null		
	,	EffectiveDate			date		not null	
	,	Price					float		not null	
	--	
	,	UNIQUE	(	
					CashflowSeriesID		
				,	EffectiveDate			
				)	
	)	
	--	
	;	

	--
	--	

		DECLARE @Output_Staging TABLE 
		(
			CashflowSeriesPriceID	int		not null	
		,	YieldToMaturity			float	not null	
		--
		,	Iterations				int		null	
		,	FinalError				float	null	
		--
		,	UNIQUE  (
						CashflowSeriesPriceID	
					)	
		)
		;	

		DECLARE @t_Polynomial AS math.UTT_PolynomialTerm ; 
		
		DECLARE @t_PolynomialIDMap TABLE 
		(
			PolynomialID			int		not null	identity(1,1)	primary key		
		--
		,	CashflowSeriesPriceID	int		not null	
		,	DerivativeNumber		int		not null	
		)	
		;	

		DECLARE @t_VariableValue AS math.UTT_ListElement ; 

		DECLARE @t_FunctionValue TABLE 
		(
			PolynomialID	int		not null	
		,	VariableValue	float	not null 
		,	FunctionValue	float	not null 
		--
		,	PRIMARY KEY (
							PolynomialID	
						)	
		)	
		; 
		

		DECLARE @t_PreviousFunctionValue TABLE 
		(
			PolynomialID	int		not null	
		,	VariableValue	float	not null 
		,	FunctionValue	float	not null	
		--
		,	PRIMARY KEY (
							PolynomialID	
						)	
		)	
		;	
		DECLARE @t_Previous4FunctionValues TABLE 
		(
			CashflowSeriesPriceID	int		not null	
		,	LatestValue				float	not null	
		,	SecondLatestValue		float	null	
		,	ThirdLatestValue		float	null 
		,	FourthLatestValue		float	null	
		--
		,	PRIMARY KEY (
							CashflowSeriesPriceID	
						)	
		)	
		;	


	--
	--
	
		--
		--	cache input cashflow/price records and eliminate invalid requests 
		--	

		INSERT INTO @Input_Prices_Cache		
		(
			ID	
		--	
		,	CashflowSeriesID	
		,	EffectiveDate 
		--
		,	Price	
		)	

			SELECT		P.ID	
			--	
			,			P.CashflowSeriesID	
			,			P.EffectiveDate		
			--	
			,			P.Price - X.PricingDateCashflowTotal	
			--	
			FROM		@Input_Prices	P	
			INNER JOIN	(
							SELECT	Ps.ID	CashflowSeriesPriceID	
							--
							--,		COUNT(*)	CashflowCount	
							--	
							,		SUM(CASE WHEN C.CashflowDate = Ps.EffectiveDate	
											 THEN C.Amount 
											 ELSE 0 
										END)			PricingDateCashflowTotal	
							--	
							FROM		@Input_Prices		Ps	
							INNER JOIN	@Input_Cashflows	C	ON	Ps.CashflowSeriesID = C.CashflowSeriesID		
																OR	(
																		Ps.CashflowSeriesID IS NULL 
																	AND C.CashflowSeriesID IS NULL	
																	)	
							--
							WHERE	C.CashflowDate >= Ps.EffectiveDate 
							--
							GROUP BY	Ps.ID	
							HAVING		SUM(CASE WHEN C.CashflowDate > Ps.EffectiveDate 
												 THEN 1 
												 ELSE 0 
											END) > 0 
							--	
						)	
							X	ON	P.ID = X.CashflowSeriesPriceID 
			--	
			;	
				
		INSERT INTO @Input_Cashflows_Cache	
		(
			ID					
		--	
		,	CashflowSeriesID	
		,	CashflowDate		
		,	Amount				
		--
		)	
			
			SELECT		Y.ID					
			--	
			,			Y.CashflowSeriesID		
			,			Y.CashflowDate			
			,			Y.Amount				
			--	
			FROM		@Input_Prices_Cache		X	
			INNER JOIN	@Input_Cashflows		Y	ON	X.CashflowSeriesID = Y.CashflowSeriesID		
													OR	(
															X.CashflowSeriesID IS NULL 
														AND Y.CashflowSeriesID IS NULL	
														)	
			--
			WHERE		Y.CashflowDate > X.EffectiveDate	
			--
			;	

	--
	--	

		INSERT INTO @t_PolynomialIDMap 
		(
			CashflowSeriesPriceID 
		,	DerivativeNumber 
		)	

			SELECT		X.ID	 
			,			Y.DerivativeNumber	
			--	
			FROM		@Input_Prices_Cache	 X	
			CROSS JOIN	(
							VALUES	( 0 ) 
							,		( 1 )	
						)		
							Y	( DerivativeNumber )	
			;		

	--
	--	

		--	
		--	define polynomials for which we seek a root 
		--	

		INSERT INTO @t_Polynomial 
		(
			PolynomialID
		,	Coefficient 
		,	Exponent 
		)	

		SELECT		coalesce(X.PolynomialID,Y.PolynomialID)		
		,			( coalesce(X.Coefficient,0) + coalesce(Y.Coefficient,0) ) * @CoefficientInflationFactor 
		,			coalesce(X.Exponent,Y.Exponent)		
		FROM		(
						SELECT	X.PolynomialID 
						,		X.DayCountFraction_Negated		Exponent	
						,		SUM(X.Amount)					Coefficient		
						FROM	
						(
							SELECT		M.PolynomialID 
							,			C.Amount	
							--	
							--	
							,	----- -	 quant.fcn_DayCountFraction ( P.EffectiveDate	
								----- 								, dateadd(day,-1,C.CashflowDate)	
								----- 								, @DayCountConvention_ShortName
								----- 								) 
								
								      - ( convert(float, datediff(day, P.EffectiveDate, dateadd(day,-1,C.CashflowDate)) )
									      / convert(float, 365.25 ) ) 
								
											DayCountFraction_Negated	
							--
							--	
							FROM		@Input_Prices_Cache		P	
							INNER JOIN	@t_PolynomialIDMap		M	ON	P.ID = M.CashflowSeriesPriceID 
																	-- 
																	AND M.DerivativeNumber = 0 
																	--	
							INNER JOIN	@Input_Cashflows_Cache	C	ON	P.CashflowSeriesID = C.CashflowSeriesID		
																	OR	(
																			P.CashflowSeriesID IS NULL 
																		AND C.CashflowSeriesID IS NULL	
																		)	
							--	
							--	
						)	
							X	
						GROUP BY	X.PolynomialID 
						,			X.DayCountFraction_Negated 
					) 
						X	
		FULL JOIN	
					( 
						SELECT		M.PolynomialID	
						,			0						Exponent	
						,			- P.Price				Coefficient		
						FROM		@t_PolynomialIDMap		M	
						INNER JOIN	@Input_Prices_Cache		P	ON	M.CashflowSeriesPriceID = P.ID	
						--	
						WHERE		M.DerivativeNumber = 0  
						--	
					)	
						Y	ON	X.PolynomialID = Y.PolynomialID 
							AND X.Exponent = Y.Exponent 
		;	

	--
	--

		--	
		--	calculate first derivatives of polynomials 
		--	

		INSERT INTO @t_Polynomial	
		(
			PolynomialID	
		,	Coefficient 
		,	Exponent 
		)	

			SELECT		D.PolynomialID 
			,			X.Coefficient 
			,			X.Exponent
			--
			FROM		math.fcn_PolynomialDerivative ( @t_Polynomial )		X	
			INNER JOIN	@t_PolynomialIDMap	I	ON	X.PolynomialID = I.PolynomialID 
			INNER JOIN	@t_PolynomialIDMap	D	ON	I.CashflowSeriesPriceID = D.CashflowSeriesPriceID 
												AND I.DerivativeNumber = 0 
												AND D.DerivativeNumber = 1 
			;	

	--
	--

		--	
		--	define initial guesses for each root-finding loop 
		--	
		
		INSERT INTO @t_VariableValue	
		(
			ListID	
		,	X_Value		
		)	

		SELECT		M.PolynomialID		
		,			convert(float,1.0) + @Loop_InitialGuess	
		FROM		@t_PolynomialIDMap		M	
		;	

		INSERT INTO @t_FunctionValue 
		(	
			PolynomialID 
		,	VariableValue 
		,	FunctionValue	
		)	

		SELECT	X.PolynomialID 
		,		X.VariableValue 
		,		X.FunctionValue 
		FROM	math.fcn_PolynomialEvaluation ( @t_Polynomial	
											  , @t_VariableValue )	X	
		;

		DELETE 
		FROM	@t_VariableValue	
		;	

	--
	--

		--
		--	if current guess is close enough, stage output value for the requested yield 
		--	

		INSERT INTO @Output_Staging 
		(
			CashflowSeriesPriceID 
		--
		,	YieldToMaturity		
		)	

		SELECT		M.CashflowSeriesPriceID 
		--
		,			F.VariableValue - convert(float,1.0)	
		--	
		FROM		@t_FunctionValue	F	
		INNER JOIN	@t_PolynomialIDMap	M	ON	F.PolynomialID = M.PolynomialID		
		WHERE		M.DerivativeNumber = 0 
		AND			ABS(F.FunctionValue) < @Precision_Threshold  
		;	

	--
	--
	
		SET @Iteration = 1 ; 

	--
	--

		WHILE @Iteration <= @MaxIterations 
		AND   EXISTS (	SELECT		null 
						FROM		@Input_Prices_Cache	 P	
						LEFT  JOIN	@Output_Staging		 O	ON	P.ID = O.CashflowSeriesPriceID 
						WHERE		O.YieldToMaturity IS NULL  ) 
		BEGIN 	
		
			DELETE		P 
			FROM		@Output_Staging		S	
			INNER JOIN	@t_PolynomialIDMap	M	ON	S.CashflowSeriesPriceID = M.CashflowSeriesPriceID	
			INNER JOIN	@t_Polynomial		P	ON	M.PolynomialID = P.PolynomialID		
			;	 

			DELETE		M  
			FROM		@Output_Staging		S	
			INNER JOIN	@t_PolynomialIDMap	M	ON	S.CashflowSeriesPriceID = M.CashflowSeriesPriceID	
			;	 

			--
			--	Newton's method : next guess is current guess X minus Q(X)/Q'(X) where Q is the cashflow polynomial 
			--

			INSERT INTO @t_VariableValue	
			(
				ListID	
			,	X_Value		
			)	

			SELECT		M.PolynomialID 
			,			CASE WHEN X.New_VariableValue = X.Old_VariableValue 
							 OR	  X.New_VariableValue = 0 
							 THEN X.New_VariableValue + @Loop_ZeroDerivativeIncrement / convert(float,2*@Iteration)  
							 ELSE X.New_VariableValue 
						END 
			FROM		(
							SELECT		M.CashflowSeriesPriceID 
							--
							,			CASE --
											 --	 if the derivative at the current point is 0, 
											 --		adjust the variable value by a fixed increment 
											 --		
											 WHEN G.FunctionValue = 0 
											 THEN F.VariableValue + @Loop_ZeroDerivativeIncrement / convert(float,2*@Iteration)  
											 --
											 --	 if the previous variable value was 'better' than the current one, 
											 --		go back to the previous one and try to ensure that the next guess 
											 --		 is an improvement
											 --		
											 WHEN ABS( P.FunctionValue ) < ABS( F.FunctionValue)	
											 AND  Q.FunctionValue != 0 
											 THEN P.VariableValue - P.FunctionValue / Q.FunctionValue / convert(float,2.0)	
											 --
											 --	 otherwise, define the next variable value by Newton's method 
											 --		
											 ELSE F.VariableValue - F.FunctionValue / G.FunctionValue 
										END					New_VariableValue 
							,			F.VariableValue		Old_VariableValue	
							--
							FROM		@t_PolynomialIDMap			M	
							INNER JOIN	@t_PolynomialIDMap			N	ON	M.CashflowSeriesPriceID = N.CashflowSeriesPriceID	
																		AND M.DerivativeNumber = 0 
																		AND N.DerivativeNumber = 1 
							INNER JOIN	@t_FunctionValue			F	ON	M.PolynomialID = F.PolynomialID		
							INNER JOIN	@t_FunctionValue			G	ON	N.PolynomialID = G.PolynomialID	
							--	
							LEFT  JOIN	@t_PreviousFunctionValue	P	ON	F.PolynomialID = P.PolynomialID 
							LEFT  JOIN	@t_PreviousFunctionValue	Q	ON	G.PolynomialID = Q.PolynomialID 
							--	
						)	
											 X	
			INNER JOIN	@t_PolynomialIDMap	 M	 ON	  X.CashflowSeriesPriceID = M.CashflowSeriesPriceID 
			;	

		--
		--
		
			DELETE		P	
			FROM		@t_PreviousFunctionValue	P	
			;	 

			INSERT INTO @t_PreviousFunctionValue	
			(
				PolynomialID 
			,	VariableValue	
			,	FunctionValue	
			)	
				SELECT	F.PolynomialID	
				,		F.VariableValue 
				,		F.FunctionValue 
				FROM	@t_FunctionValue	F	
				;	

			DELETE		F   
			FROM		@t_FunctionValue	F	
			;	 

		--
		--

			INSERT INTO @t_FunctionValue 
			(	
				PolynomialID 
			,	VariableValue 
			,	FunctionValue	
			)	

			SELECT	X.PolynomialID 
			,		X.VariableValue 
			,		X.FunctionValue 
			FROM	math.fcn_PolynomialEvaluation ( @t_Polynomial	
												  , @t_VariableValue )	X	
			;

			DELETE 
			FROM	@t_VariableValue	
			;	
			
		--
		--

			--
			--	2016-07-11 :: prevent circular iterations 
			--

			IF @Iteration = 1 
			BEGIN 

				INSERT INTO @t_Previous4FunctionValues	
				(
					CashflowSeriesPriceID	
				,	LatestValue		
				)	

				SELECT		M.CashflowSeriesPriceID		
				,			V.FunctionValue		
				FROM		@t_FunctionValue	V	
				INNER JOIN	@t_PolynomialIDMap	M	ON	V.PolynomialID = M.PolynomialID		
				WHERE		M.DerivativeNumber = 0 
				;	
					
			END		
			ELSE BEGIN 

				UPDATE		X	
				SET			X.LatestValue = V.FunctionValue 
				,			X.SecondLatestValue = X.LatestValue 
				,			X.ThirdLatestValue = X.SecondLatestValue 
				,			X.FourthLatestValue = X.ThirdLatestValue 
				--	
				FROM		@t_Previous4FunctionValues	X	
				INNER JOIN	@t_PolynomialIDMap			M	ON	X.CashflowSeriesPriceID = M.CashflowSeriesPriceID 
															AND M.DerivativeNumber = 0 
				INNER JOIN	@t_FunctionValue			V	ON	M.PolynomialID = V.PolynomialID		
				;	

			END		

		--
		--

		INSERT INTO @Output_Staging 
		(
			CashflowSeriesPriceID 
		--
		,	YieldToMaturity		
		--	
		,	Iterations 
		,	FinalError	
		)	

		SELECT		M.CashflowSeriesPriceID 
		--
		,			F.VariableValue - convert(float,1.0)	
		--
		,			@Iteration 	
		,			F.FunctionValue	/ @CoefficientInflationFactor 
		--
		FROM		@t_FunctionValue		F	
		INNER JOIN	@t_PolynomialIDMap		M	ON	F.PolynomialID = M.PolynomialID		
												AND M.DerivativeNumber = 0 
		--
		LEFT  JOIN	(
						SELECT	Y.CashflowSeriesPriceID		
						--
						,		CASE WHEN ABS(Y.MinFunctionValue) = ABS(P.LatestValue) 
									 AND  (
											 ABS(Y.MinFunctionValue) = ABS(P.ThirdLatestValue)  
										  OR ABS(Y.MinFunctionValue) = ABS(P.FourthLatestValue) 
										  ) 
									 THEN 1 
									 ELSE 0 
								END	 EndLoop	
						--
						FROM	(
									SELECT		P4s.CashflowSeriesPriceID 
									,			MIN(ABS(X.FunctionValue))	MinFunctionValue		
									FROM		@t_Previous4FunctionValues	P4s		
									CROSS APPLY (
													VALUES	( 1 , P4s.LatestValue ) 
													,		( 2 , P4s.SecondLatestValue ) 
													,		( 3 , P4s.ThirdLatestValue ) 
													,		( 4 , P4s.FourthLatestValue )	
												)	
													X	( PrevNumber , FunctionValue )	
									GROUP BY	P4s.CashflowSeriesPriceID 
								)	
									Y	
						INNER JOIN	@t_Previous4FunctionValues	P	ON	Y.CashflowSeriesPriceID = P.CashflowSeriesPriceID 
					)	
						X	ON	M.CashflowSeriesPriceID = X.CashflowSeriesPriceID 			
		--
		WHERE		ABS(F.FunctionValue / @CoefficientInflationFactor) < @Precision_Threshold  
		--		
		OR			X.EndLoop = 1 	
		--	
		;	

		--
		--

			--
			--

			SET @Iteration += 1 ; 

			--
			--

		END		

	--
	--

	
		INSERT INTO @Output_Staging 
		(
			CashflowSeriesPriceID 
		--
		,	YieldToMaturity		
		--	
		,	Iterations 
		,	FinalError	
		)	

		SELECT		M.CashflowSeriesPriceID 
		--
		,			CASE WHEN ABS(P.FunctionValue) < ABS(F.FunctionValue)	
						 THEN P.VariableValue - convert(float,1.0)	
						 ELSE F.VariableValue - convert(float,1.0)	
					END		-- YieldToMaturity	
		--
		,			@Iteration - 1 
		,			CASE WHEN ABS(P.FunctionValue) < ABS(F.FunctionValue)	
						 THEN P.FunctionValue / @CoefficientInflationFactor 
						 ELSE F.FunctionValue / @CoefficientInflationFactor 
					END		-- FinalError
		--
		FROM		@t_FunctionValue			F	
		INNER JOIN	@t_PolynomialIDMap			M	ON	F.PolynomialID = M.PolynomialID		
		LEFT  JOIN	@t_PreviousFunctionValue	P	ON	M.PolynomialID = P.PolynomialID 
			--	
			--	between the current and the previous variable values, return the one with smaller error 
			--
		LEFT  JOIN	@Output_Staging				O	ON	M.CashflowSeriesPriceID = O.CashflowSeriesPriceID 
													OR	(
															M.CashflowSeriesPriceID	IS NULL 
														AND O.CashflowSeriesPriceID IS NULL 
														)	
		WHERE		M.DerivativeNumber = 0 
		AND			O.YieldToMaturity IS NULL	
		;	

	--
	--

	INSERT INTO @Output 
	(
		CashflowSeriesPriceID 
	--
	,	CashflowSeriesID 
	,	EffectiveDate	
	--
	,	Price 
	,	YieldToMaturity		
	--
	,	Iterations 
	,	FinalError	
	)	

	SELECT		S.CashflowSeriesPriceID 
	--
	,			C.CashflowSeriesID 
	,			C.EffectiveDate		
	--
	,			C.Price		
	,			S.YieldToMaturity	
	--
	,			S.Iterations		
	,			S.FinalError 
	--
	FROM		@Output_Staging			S	
	INNER JOIN	@Input_Prices_Cache		C	ON	S.CashflowSeriesPriceID = C.ID	
	--	
	;	

	--
	--

	RETURN 

END

GO

--
--

CREATE FUNCTION [quant].[fcn_CashflowSeries_YieldToMaturity_SmallBatches] 
(
	@Input_Cashflows	quant.UTT_CashflowSeriesComponent   READONLY	
,	@Input_Prices		quant.UTT_CashflowSeriesPrice		READONLY	
--	
--,	@DayCountConvention_ShortName			varchar(20)		
--
,	@MaxIterations							int				
--
,	@MaxBatchSize							int		
--
)
RETURNS 
@Output TABLE 
(
	CashflowSeriesPriceID	int		not null	
--
,	CashflowSeriesID		int		null 
,	EffectiveDate			date	not null	
--	
,	Price					float	not null	
,	YieldToMaturity			float	not null	
--
,	Iterations				int		null	
,	FinalError				float	null	
--
,	UNIQUE  (
				CashflowSeriesPriceID	
			)	
,	UNIQUE  (
				CashflowSeriesID
			,	EffectiveDate	
			)	
--	
)
AS
/**************************************************************************************

	  Runs the function fcn_CashflowSeries_YieldToMaturity repeatedly with smaller batch sizes,  
	   aiming to improve calculation speed by reducing the number of simultaneous calculations. 

		
		Example:	

			--
			--

			DECLARE @t_Cashflows AS quant.UTT_CashflowSeriesComponent ; 
			DECLARE @t_Prices AS quant.UTT_CashflowSeriesPrice ; 

			INSERT INTO @t_Cashflows 
			(
				CashflowDate	
			,	Amount	
			)	
				VALUES	( 'Sep 1, 2016' , 100  ) 
				,		( 'Dec 1, 2016' , 100  ) 
				,		( 'Mar 1, 2017' , 4100 ) 
				;	

			INSERT INTO @t_Prices 
			(
				EffectiveDate 
			,	Price	
			)	
				VALUES	( 'May 29, 2016' , 4000 )
				;	

			--
			--

			SELECT		Y.* 
			FROM		quant.fcn_CashflowSeries_YieldToMaturity_SmallBatches
							(	
								@t_Cashflows 	--	Input_Cashflows		
							,	@t_Prices 		--	Input_Prices	
					    --  ,	'30/360'		--	DayCountConvention_ShortName		
							,	null			--	MaxIterations
							,	1				--  MaxBatchSize 
							)			
								Y
			--	
			ORDER BY	Y.CashflowSeriesPriceID	ASC		
			--	
			;	

			--
			--

	Date			Action	
	----------		----------------------------
	2016-07-12		Created initial version.	 
	2022-04-10		Removed (commented) @DayCountConvention_ShortName parameter. 

**************************************************************************************/	
BEGIN
	
	--
	--

		DECLARE		@CurrentBatch			int		
		,			@Default_MaxBatchSize	int		=	1500	
		--
		;	

	--
	--

	IF @MaxBatchSize IS NULL 
	OR @MaxBatchSize <= 0 
	BEGIN 
		SET @MaxBatchSize = @Default_MaxBatchSize 
	END		
	
----  IF @DayCountConvention_ShortName IS NOT NULL 
----  AND ( SELECT COUNT(*) FROM quant.DayCountConvention X WHERE X.ShortName = @DayCountConvention_ShortName ) = 0 
----  BEGIN	
----  	RETURN ; 
----  END		

	--
	--

		DECLARE @rec_Input_Cashflows AS quant.UTT_CashflowSeriesComponent ;  
		DECLARE @rec_Input_Prices AS quant.UTT_CashflowSeriesPrice ; 

	--
	--

		DECLARE	@BatchCategorization TABLE 
		(
			CashflowSeriesPriceID		int		not null	primary key	
		--
		,	CashflowSeriesID			int		null	
		,	EffectiveDate				date	not null	
		--
		,	RankNumber					int		not null	
		--	
		,	UNIQUE	(
						CashflowSeriesID	
					,	EffectiveDate		
					)	
		)	
		;	

	--
	--	

		DECLARE @Output_Staging TABLE 
		(
			CashflowSeriesPriceID	int		not null	
		--
		,	CashflowSeriesID		int		null 
		,	EffectiveDate			date	not null	
		--	
		,	Price					float	not null	
		,	YieldToMaturity			float	not null	
		--
		,	Iterations				int		null	
		,	FinalError				float	null	
		--
		,	UNIQUE  (
						CashflowSeriesPriceID	
					)	
		,	UNIQUE	(
						CashflowSeriesID	
					,	EffectiveDate	
					)	
		--	
		)
		;	

	--
	--
	
		--
		--	rank each cashflow request by Price ID value	
		--	

		INSERT INTO @BatchCategorization 
		(
			CashflowSeriesPriceID	
		--	
		,	CashflowSeriesID		
		,	EffectiveDate	
		--	
		,	RankNumber	
		)	

			SELECT	P.ID	
			--
			,		P.CashflowSeriesID 
			,		P.EffectiveDate		
			--
			,		RANK() OVER ( ORDER BY P.ID ASC )	RankNumber	
			--
			FROM	@Input_Prices	P	
			--
			;	

	--
	--

		--
		--	loop through batches	
		--	

		SET @CurrentBatch = 1 ; 

		WHILE EXISTS ( SELECT	null	
					   FROM		@BatchCategorization	B	
					   WHERE	B.RankNumber >= ( @CurrentBatch - 1 ) * @MaxBatchSize + 1 
					   AND		B.RankNumber <= ( @CurrentBatch ) * @MaxBatchSize ) 
		BEGIN 

			--
			--	clear recursize input tables	
			--	

			DELETE FROM @rec_Input_Cashflows ; 
			DELETE FROM @rec_Input_Prices ;		
			
			--
			--	populate recursize input tables with current batch records	
			--	

			INSERT INTO @rec_Input_Prices	
			(
				CashflowSeriesID	
			,	EffectiveDate	
			,	Price	
			)	

				SELECT		P.CashflowSeriesID	
				,			P.EffectiveDate 
				,			P.Price		
				FROM		@Input_Prices			P	
				INNER JOIN	@BatchCategorization	B	ON	P.ID = B.CashflowSeriesPriceID 
				WHERE		B.RankNumber >= ( @CurrentBatch - 1 ) * @MaxBatchSize + 1 
				AND			B.RankNumber <= ( @CurrentBatch ) * @MaxBatchSize  
				;	
			 

			INSERT INTO @rec_Input_Cashflows 
			(
				CashflowSeriesID	
			,	CashflowDate	
			,	Amount 	
			)	

				SELECT		Y.CashflowSeriesID	
				,			Y.CashflowDate	
				,			Y.Amount		
				FROM		(
								SELECT	distinct	Xs.CashflowSeriesID		
								FROM	@rec_Input_Prices	Xs	
							)	
								X	
				INNER JOIN	@Input_Cashflows	Y	ON	X.CashflowSeriesID = Y.CashflowSeriesID		
													OR	(
															X.CashflowSeriesID IS NULL 
														AND Y.CashflowSeriesID IS NULL 
														)	
				--	
				;	
			 
			--
			--
			--	

				--
				--	call main function to calculate internal rates of return 
				--

			INSERT INTO @Output_Staging 
			(
				CashflowSeriesPriceID	
			--
			,	CashflowSeriesID	
			,	EffectiveDate		
			--	
			,	Price			
			,	YieldToMaturity			
			--
			,	Iterations				
			,	FinalError	 
			)	

				SELECT	C.CashflowSeriesPriceID 
				--
				,		C.CashflowSeriesID	
				,		C.EffectiveDate		
				--	
				,		X.Price				
				,		X.YieldToMaturity 
				--
				,		X.Iterations	
				,		X.FinalError	
				--	
				FROM	quant.fcn_CashflowSeries_YieldToMaturity ( 
																	@rec_Input_Cashflows			   --	Input_Cashflows		
																 ,  @rec_Input_Prices 				   --	Input_Prices	
														 ------  ,  @DayCountConvention_ShortName 	   --	DayCountConvention_ShortName		
																 ,  @MaxIterations 					   --	MaxIterations
																 )	
																		X	
				INNER JOIN	@BatchCategorization	C	ON	(
																X.CashflowSeriesID = C.CashflowSeriesID 
															OR	(
																	X.CashflowSeriesID IS NULL 
																AND C.CashflowSeriesID IS NULL 
																)	
															)	
														AND X.EffectiveDate = C.EffectiveDate	
				-- 
				;	 

			--
			--
			--	

			SET @CurrentBatch += 1 ;	

			--
			--
			--

		END	 -- END of batch calculation WHILE loop		

	--
	--

		--
		--	return output values	
		--

	INSERT INTO @Output		
	(
		CashflowSeriesPriceID	
	--
	,	CashflowSeriesID	
	,	EffectiveDate		
	--	
	,	Price			
	,	YieldToMaturity			
	--
	,	Iterations				
	,	FinalError	
	)	

		SELECT	O.CashflowSeriesPriceID		
		--
		,		O.CashflowSeriesID	
		,		O.EffectiveDate		
		--		
		,		O.Price			
		,		O.YieldToMaturity			
		--
		,		O.Iterations	
		,		O.FinalError	
		--	
		FROM	@Output_Staging		O	
		--
		;	

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
	-- // END of quant-schema Type & Function CREATION statements 
	--
---- --	
---- --  CHECK STRUCTURAL INTEGRITY -- naming conventions, history tables & triggers, etc. 
---- --	
---- EXEC  utility.usp_Check_StructuralIntegrity 
----   @DEBUG  =  1	
---- ;
---- GO
---- --
---- -- END FILE :: q004_MoreTypesAndFunctions.sql 
---- --
