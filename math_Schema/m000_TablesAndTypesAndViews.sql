--
-- BEGIN FILE :: m000_TablesAndTypesAndViews.sql 
--
----
----CREATE SCHEMA [utility] AUTHORIZATION dbo 
----GO 
----CREATE SCHEMA [utility_history] AUTHORIZATION dbo 
----GO 
---- 
--  NOT SCRIPTED HERE: first, create the following objects (all available @ GITHUB [lance7777]): 
--	 -- (0) (scalar-valued function) [dbo].fcn_DebugInfo 
--   -- (1) (stored procedure) [utility].usp_Check_StructuralIntegrity 
--	 -- (2) (stored procedure) [utility].usp_Create_HistoryTable 
--	
--
--
/***

  CONTENTS: 
  
  - create "math" and "math_history" schemas  
  - create tables and views: 
    - KernelFunction      | vw_KernelFunction 
    - InterpolationMethod | vw_InterpolationMethod 
    - ExtrapolationMethod | vw_ExtrapolationMethod 
  - create user-defined table-types: 
    - UTT_ListElement 
	- UTT_OrderedPair 
	- UTT_MatrixCoordinate 
	- UTT_PolynomialTerm 

***/
--
--
CREATE SCHEMA math AUTHORIZATION dbo -- the "core" schema to store mathematical definitions and algorithms (functions/procedures, created in separate script files) 
GO 
CREATE SCHEMA math_history AUTHORIZATION dbo -- necessary to deploy "history" tables, once for each table in this script 
GO 
--
--
--
--
-- 
CREATE TABLE [math].[KernelFunction](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ShortName] [varchar](20) NOT NULL,
	[Note] [varchar](200) NULL,
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [varchar](200) NOT NULL,
	[UpdateBy] [varchar](200) NOT NULL,
 CONSTRAINT [PK_KernelFunction] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 

CREATE UNIQUE NONCLUSTERED INDEX [UIX_KernelFunction] ON [math].[KernelFunction]
(
	[ShortName] ASC
)

ALTER TABLE [math].[KernelFunction] ADD  CONSTRAINT [DF_KernelFunction_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE [math].[KernelFunction] ADD  CONSTRAINT [DF_KernelFunction_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE [math].[KernelFunction] ADD  CONSTRAINT [DF_KernelFunction_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE [math].[KernelFunction] ADD  CONSTRAINT [DF_KernelFunction_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]

EXEC utility.usp_Create_HistoryTable @Schema_Name =	'math' , @Table_Name = 'KernelFunction' , @IncludeContextInfoChecks = 0 , @Mode = 'RUN' , @DEBUG = 1;
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'List of kernel functions supported on [-1,1]' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'TABLE',@level1name=N'KernelFunction'
--GO

-- 
-- 

GO
CREATE VIEW math.vw_KernelFunction 
AS  
/**************************************************************************************

	Displays KernelFunction records. 

		
		Example:	
		

			SELECT  X.*
			FROM  math.vw_KernelFunction  X  
			ORDER BY  X.ShortName  ASC  
			--
			;	

			
	Date			Action	
	----------		----------------------------
	2022-04-09		Created initial version.	

**************************************************************************************/	


	SELECT	X.[ID] 
	--	
	,		X.ShortName 	
	--
	,		X.Note  	
	--
	FROM	math.KernelFunction  X  WITH(NOLOCK)  
	--
	;	
	

GO	

--
--

insert into [math].[KernelFunction] 
(
	ShortName
,	Note
) 
SELECT	X.ShortName
,		X.Note
FROM 
( VALUES 
  ( 1 , 'Uniform'		, 'K(u) = 1/2 for |u| <= 1'											) 
, ( 2 , 'Triangular'	, 'K(u) = (1-|u|) for |u| <= 1'										) 
, ( 3 , 'Parabolic'		, 'K(u) = (3/4)*(1-u^2) for |u| <= 1  (also called Epanechnikov)'	) 
, ( 4 , 'Quartic'		, 'K(u) = (15/16)*(1-u^2)^2 for |u| <= 1'							) 
, ( 5 , 'Triweight'		, 'K(u) = (35/32)*(1-u^2)^3 for |u| <= 1'							) 
, ( 6 , 'Tricube'		, 'K(u) = (70/81)*(1-|u|^3)^3 for |u| <= 1'							) 
, ( 7 , 'Cosine'	    , 'K(u) = (Pi/4)*cos(u(Pi/2)) for |u| <= 1'							) 
) X ( ID , ShortName , Note ) 
ORDER BY X.ID ASC 
--
--
--
--

CREATE TABLE [math].[InterpolationMethod](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ShortName] [varchar](10) NOT NULL,
	[LongName] [varchar](50) NOT NULL,
	[Description] [varchar](300) NOT NULL,
	[MinimumInputPairCount] [int] NOT NULL,
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [varchar](200) NOT NULL,
	[UpdateBy] [varchar](200) NOT NULL,
 CONSTRAINT [PK_InterpolationMethod] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 

CREATE UNIQUE NONCLUSTERED INDEX [UIX_InterpolationMethod_LongName] ON [math].[InterpolationMethod]
(
	[LongName] ASC
)

CREATE UNIQUE NONCLUSTERED INDEX [UIX_InterpolationMethod_ShortName] ON [math].[InterpolationMethod]
(
	[ShortName] ASC
)

ALTER TABLE [math].[InterpolationMethod] ADD  CONSTRAINT [DF_InterpolationMethod_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE [math].[InterpolationMethod] ADD  CONSTRAINT [DF_InterpolationMethod_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE [math].[InterpolationMethod] ADD  CONSTRAINT [DF_InterpolationMethod_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE [math].[InterpolationMethod] ADD  CONSTRAINT [DF_InterpolationMethod_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]

ALTER TABLE [math].[InterpolationMethod]  WITH CHECK ADD  CONSTRAINT [CK_InterpolationMethod_MinimumInputPairCount] CHECK  (([MinimumInputPairCount]>(1)))
GO

ALTER TABLE [math].[InterpolationMethod] CHECK CONSTRAINT [CK_InterpolationMethod_MinimumInputPairCount]
GO

EXEC utility.usp_Create_HistoryTable @Schema_Name =	'math' , @Table_Name = 'InterpolationMethod' , @IncludeContextInfoChecks = 0 , @Mode = 'RUN' , @DEBUG = 1;
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'List of programmed methods for interpolation' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'TABLE',@level1name=N'InterpolationMethod'
--GO

-- 
-- 

GO
CREATE VIEW math.vw_InterpolationMethod 
AS  
/**************************************************************************************

	Displays InterpolationMethod records. 

		
		Example:	
		

			SELECT  X.*
			FROM  math.vw_InterpolationMethod  X  
			ORDER BY  X.ShortName  DESC  
			--
			;	

			
	Date			Action	
	----------		----------------------------
	2022-04-09		Created initial version.	

**************************************************************************************/	


	SELECT	X.[ID] 
	--	
	,		X.ShortName 	
	,		X.LongName 	
	--
	,		X.[Description]  	
	--
	,		X.MinimumInputPairCount
	--
	FROM	math.InterpolationMethod  X  WITH(NOLOCK)  
	--
	;	
	

GO	

--
--

insert into [math].[InterpolationMethod] 
(
	ShortName 
,	LongName 
,	[Description] 
,	MinimumInputPairCount 
) 
SELECT	X.ShortName 
,		X.LongName 
,		X.[Description] 
,		X.MinInputPairCount 
FROM 
( VALUES 
  ( 1 , 'PL'	 , 'Piecewise Linear'			, 2 , 'Continuous function composed of linear pieces between input points.'		) 
, ( 2 , 'CSN'	 , 'Natural Cubic Spline'		, 3 , 'Continuous, twice-differentiable function with continous second derivative, composed of cubic polynomial pieces between input points, with zero second derivative at first and last input points.'								) 
, ( 3 , 'CSNAK'	 , 'Not-A-Knot Cubic Spline'	, 4 , 'Continuous, twice-differentiable function with continous second derivative, composed of cubic polynomial pieces between input points, with matching left-and-right third derivatives at second and second-last input points.'	) 
) X ( ID , ShortName , LongName , MinInputPairCount , [Description] ) 
ORDER BY X.ID ASC 
--
--
--
--

CREATE TABLE [math].[ExtrapolationMethod](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ShortName] [varchar](10) NOT NULL,
	[LongName] [varchar](50) NOT NULL,
	[Description] [varchar](300) NOT NULL,
	[MinimumInputPairCount] [int] NOT NULL,
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [varchar](200) NOT NULL,
	[UpdateBy] [varchar](200) NOT NULL,
 CONSTRAINT [PK_ExtrapolationMethod] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 

CREATE UNIQUE NONCLUSTERED INDEX [UIX_ExtrapolationMethod_LongName] ON [math].[ExtrapolationMethod]
(
	[LongName] ASC
)

CREATE UNIQUE NONCLUSTERED INDEX [UIX_ExtrapolationMethod_ShortName] ON [math].[ExtrapolationMethod]
(
	[ShortName] ASC
)

ALTER TABLE [math].[ExtrapolationMethod] ADD  CONSTRAINT [DF_ExtrapolationMethod_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE [math].[ExtrapolationMethod] ADD  CONSTRAINT [DF_ExtrapolationMethod_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE [math].[ExtrapolationMethod] ADD  CONSTRAINT [DF_ExtrapolationMethod_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE [math].[ExtrapolationMethod] ADD  CONSTRAINT [DF_ExtrapolationMethod_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]

ALTER TABLE [math].[ExtrapolationMethod]  WITH CHECK ADD  CONSTRAINT [CK_ExtrapolationMethod_MinimumInputPairCount] CHECK  (([MinimumInputPairCount]>(0)))
GO

ALTER TABLE [math].[ExtrapolationMethod] CHECK CONSTRAINT [CK_ExtrapolationMethod_MinimumInputPairCount]
GO

EXEC utility.usp_Create_HistoryTable @Schema_Name =	'math' , @Table_Name = 'ExtrapolationMethod' , @IncludeContextInfoChecks = 0 , @Mode = 'RUN' , @DEBUG = 1;
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'List of programmed methods for extrapolation' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'TABLE',@level1name=N'ExtrapolationMethod'
--GO

-- 
-- 

GO
CREATE VIEW math.vw_ExtrapolationMethod 
AS  
/**************************************************************************************

	Displays ExtrapolationMethod records. 

		
		Example:	
		

			SELECT  X.*
			FROM  math.vw_ExtrapolationMethod  X  
			ORDER BY  X.ShortName  DESC  
			--
			;	

			
	Date			Action	
	----------		----------------------------
	2022-04-09		Created initial version.	

**************************************************************************************/	


	SELECT	X.[ID] 
	--	
	,		X.ShortName 	
	,		X.LongName 	
	--
	,		X.[Description]  	
	--
	,		X.MinimumInputPairCount
	--
	FROM	math.ExtrapolationMethod  X  WITH(NOLOCK)  
	--
	;	
	

GO	

--
--

insert into [math].[ExtrapolationMethod] 
(
	ShortName 
,	LongName 
,	[Description] 
,   MinimumInputPairCount
) 
SELECT	X.ShortName 
,		X.LongName 
,		X.[Description] 
,		X.MinInputPairCount 
FROM 
( VALUES 
  ( 1 , 'L'	 , 'Linear'	 , 2 , 'Linear extrapolation from first and last pairs of input points.'	) 
, ( 2 , 'F'	 , 'Flat'	 , 1 , 'Constant extrapolation of first and last input points.'				) 
) X ( ID , ShortName , LongName , MinInputPairCount , [Description] ) 
ORDER BY X.ID ASC 
--
--
--
--

--
--

CREATE TYPE [math].[UTT_ListElement] AS TABLE(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ListID] [int] NULL,
	[X_Value] [float] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (IGNORE_DUP_KEY = OFF),
	UNIQUE NONCLUSTERED 
(
	[ListID] ASC,
	[X_Value] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Table-type used to store lists of numbers/points, for example, requested output points for an interpolation evaluation' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'TYPE',@level1name=N'UTT_ListElement'
--GO

CREATE TYPE [math].[UTT_OrderedPair] AS TABLE(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ListID] [int] NULL,
	[X_Value] [float] NOT NULL,
	[Y_Value] [float] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Table-type used to store lists of ordered pairs to use, for example, as inputs for an interpolation evaluation' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'TYPE',@level1name=N'UTT_OrderedPair'
--GO

CREATE TYPE [math].[UTT_MatrixCoordinate] AS TABLE(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[MatrixID] [int] NULL,
	[RowNumber] [int] NOT NULL,
	[ColumnNumber] [int] NOT NULL,
	[Value] [float] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (IGNORE_DUP_KEY = OFF),
	UNIQUE NONCLUSTERED 
(
	[MatrixID] ASC,
	[RowNumber] ASC,
	[ColumnNumber] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Table-type used to store matrices (with real number coordinates)' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'TYPE',@level1name=N'UTT_MatrixCoordinate'
--GO

CREATE TYPE [math].[UTT_PolynomialTerm] AS TABLE(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[PolynomialID] [int] NULL,
	[Coefficient] [float] NOT NULL,
	[Exponent] [float] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (IGNORE_DUP_KEY = OFF),
	UNIQUE NONCLUSTERED 
(
	[PolynomialID] ASC,
	[Exponent] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Table-type used to store pairs of a real-valued coefficient and real-valued exponent' , @level0type=N'SCHEMA',@level0name=N'math', @level1type=N'TYPE',@level1name=N'UTT_PolynomialTerm'
--GO

--
--

--	
--	
--	
	--
	-- // END of math-schema Table & View CREATION statements 
	--
--	
--  CHECK STRUCTURAL INTEGRITY -- naming conventions, history tables & triggers, etc. 
--	
EXEC  utility.usp_Check_StructuralIntegrity 
  @DEBUG  =  1	
;
GO
--
-- END FILE :: m000_TablesAndTypesAndViews.sql 
--
