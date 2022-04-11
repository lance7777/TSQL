--
-- BEGIN FILE :: r000_AllObjects.sql 
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
  
  - create "reference" and "reference_history" schemas 
  - create tables and views: 
    - AlphabetLetter | vw_AlphabetLetter 
    - Month          | vw_Month 
    - Weekday        | vw_Weekday 
    - CalendarDate   | vw_CalendarDate 
  - create user-defined table-type: 
    - UTT_IntegerIDList 
  - create scalar-valued function 
	- fcn_EasterSunday_Computus 
  - create stored procedures
	- usp_Populate_CalendarDate 
	- usp_Generate_Holiday 

***/
--
--
CREATE SCHEMA reference AUTHORIZATION dbo -- the "core" schema to store calendar information and general lookups 
GO 
CREATE SCHEMA reference_history AUTHORIZATION dbo -- necessary to deploy "history" tables, once for each table in this script 
GO 
--
--
--
--
-- 
CREATE TABLE [reference].[AlphabetLetter](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Uppercase] [char](1) NOT NULL,
	[Lowercase] [char](1) NOT NULL,
	[Number] [tinyint] NOT NULL,
	[IsVowel] [bit] NOT NULL,

	[InsertTime] [datetime] NOT NULL,
	[InsertBy] [varchar](128) NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[UpdateBy] [varchar](128) NOT NULL,

 CONSTRAINT [PK_AlphabetLetter] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 
GO

ALTER TABLE [reference].[AlphabetLetter] ADD  CONSTRAINT [DF_AlphabetLetter_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE [reference].[AlphabetLetter] ADD  CONSTRAINT [DF_AlphabetLetter_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE [reference].[AlphabetLetter] ADD  CONSTRAINT [DF_AlphabetLetter_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE [reference].[AlphabetLetter] ADD  CONSTRAINT [DF_AlphabetLetter_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_AlphabetLetter_Lowercase] ON [reference].[AlphabetLetter]
(
	[Lowercase] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_AlphabetLetter_Number] ON [reference].[AlphabetLetter]
(
	[Number] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_AlphabetLetter_Uppercase] ON [reference].[AlphabetLetter]
(
	[Uppercase] ASC
)
GO

CREATE NONCLUSTERED INDEX [IX_AlphabetLetter_IsVowel] ON [reference].[AlphabetLetter]
(
	[IsVowel] ASC
)
GO

ALTER TABLE [reference].[AlphabetLetter]  WITH CHECK ADD  CONSTRAINT [CK_AlphabetLetter_UppercaseAndLowercaseMatch] CHECK  (([Uppercase]=[Lowercase]))
GO

ALTER TABLE [reference].[AlphabetLetter] CHECK CONSTRAINT [CK_AlphabetLetter_UppercaseAndLowercaseMatch]
GO

EXEC utility.usp_Create_HistoryTable @Schema_Name =	'reference' , @Table_Name = 'AlphabetLetter' , @IncludeContextInfoChecks = 0 , @Mode = 'RUN' , @DEBUG = 1;
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'List of English alphabet letters (A to Z)' , @level0type=N'SCHEMA',@level0name=N'reference', @level1type=N'TABLE',@level1name=N'AlphabetLetter'
--GO

INSERT INTO reference.AlphabetLetter
(
	Uppercase
,	Lowercase
,	Number
,   IsVowel 
)
VALUES ('A','a',1,1),
('B','b',2,0),
('C','c',3,0),
('D','d',4,0),
('E','e',5,1),
('F','f',6,0),
('G','g',7,0),
('H','h',8,0),
('I','i',9,1),
('J','j',10,0),
('K','k',11,0),
('L','l',12,0),
('M','m',13,0),
('N','n',14,0),
('O','o',15,1),
('P','p',16,0),
('Q','q',17,0),
('R','r',18,0),
('S','s',19,0),
('T','t',20,0),
('U','u',21,1),
('V','v',22,0),
('W','w',23,0),
('X','x',24,0),
('Y','y',25,0),
('Z','z',26,0) 
--
;

--
--

GO
/**************************************************************************************

	Displays AlphabetLetter records. 

		
		Example:  


			SELECT		X.*  
			FROM		reference.vw_AlphabetLetter  X  
			ORDER BY	X.Number  ASC  
			; 


	Date			Action	
	----------		----------------------------
	2020-04-27		Created initial version. 

**************************************************************************************/	
CREATE VIEW [reference].[vw_AlphabetLetter]	
AS	

	SELECT		X.ID 
	--
	,			X.Uppercase 
	,			X.Lowercase 
	,			X.Number 
	--
	,           X.IsVowel 
	--
	FROM		reference.AlphabetLetter  X  

GO

--
--

CREATE TABLE [reference].[Month](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](10) NOT NULL,
	[ThreeLetterAbbreviation] [char](3) NOT NULL,
	[Number] [tinyint] NOT NULL,

	[InsertTime] [datetime] NOT NULL,
	[InsertBy] [varchar](128) NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[UpdateBy] [varchar](128) NOT NULL,

 CONSTRAINT [PK_Month] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 
GO

ALTER TABLE [reference].[Month] ADD  CONSTRAINT [DF_Month_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE [reference].[Month] ADD  CONSTRAINT [DF_Month_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE [reference].[Month] ADD  CONSTRAINT [DF_Month_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE [reference].[Month] ADD  CONSTRAINT [DF_Month_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_Month_Name] ON [reference].[Month]
(
	[Name] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_Month_Number] ON [reference].[Month]
(
	[Number] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_Month_ThreeLetterAbbreviation] ON [reference].[Month]
(
	[ThreeLetterAbbreviation] ASC
)
GO

ALTER TABLE [reference].[Month]  WITH CHECK ADD  CONSTRAINT [CK_Month_Number] CHECK  (([Number]>=(1) AND [Number]<=(12)))
GO

ALTER TABLE [reference].[Month] CHECK CONSTRAINT [CK_Month_Number]
GO

EXEC utility.usp_Create_HistoryTable @Schema_Name =	'reference' , @Table_Name = 'Month'	, @IncludeContextInfoChecks	= 0 , @Mode = 'RUN' , @DEBUG = 1;
GO

INSERT INTO reference.[Month]
(
	Number
,	ThreeLetterAbbreviation
,	[Name]
)
VALUES (1,'JAN','January'),
(2,'FEB','February'),
(3,'MAR','March'),
(4,'APR','April'),
(5,'MAY','May'),
(6,'JUN','June'),
(7,'JUL','July'),
(8,'AUG','August'),
(9,'SEP','September'),
(10,'OCT','October'),
(11,'NOV','November'),
(12,'DEC','December')
--
;

GO
/**************************************************************************************

	Displays Month records. 

		
		Example:  


			SELECT		X.*  
			FROM		reference.vw_Month  X  
			ORDER BY	X.Number  ASC  
			; 


	Date			Action	
	----------		----------------------------
	2020-04-27		Created initial version. 

**************************************************************************************/	
CREATE VIEW [reference].[vw_Month]	
AS	

	SELECT		X.ID 
	--
	,			X.[Name] 
	,			X.ThreeLetterAbbreviation 
	,			X.Number 
	--
	FROM		reference.[Month]  X  

GO

--
--

CREATE TABLE [reference].[Weekday](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](10) NOT NULL,
	[ThreeLetterAbbreviation] [char](3) NOT NULL,
	[OneLetterAbbreviation] [char](1) NOT NULL,
	[DaysAfterSunday] [tinyint] NOT NULL,

	[InsertTime] [datetime] NOT NULL,
	[InsertBy] [varchar](128) NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[UpdateBy] [varchar](128) NOT NULL,

 CONSTRAINT [PK_Weekday] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 
GO

ALTER TABLE [reference].[Weekday] ADD  CONSTRAINT [DF_Weekday_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE [reference].[Weekday] ADD  CONSTRAINT [DF_Weekday_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE [reference].[Weekday] ADD  CONSTRAINT [DF_Weekday_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE [reference].[Weekday] ADD  CONSTRAINT [DF_Weekday_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_Weekday_DaysAfterSunday] ON [reference].[Weekday]
(
	[DaysAfterSunday] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_Weekday_Name] ON [reference].[Weekday]
(
	[Name] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_Weekday_OneLetterAbbreviation] ON [reference].[Weekday]
(
	[OneLetterAbbreviation] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_Weekday_ThreeLetterAbbreviation] ON [reference].[Weekday]
(
	[ThreeLetterAbbreviation] ASC
)
GO

ALTER TABLE [reference].[Weekday]  WITH CHECK ADD  CONSTRAINT [CK_Weekday_DaysAfterSunday] CHECK  (([DaysAfterSunday]>=(0) AND [DaysAfterSunday]<=(6)))
GO

ALTER TABLE [reference].[Weekday] CHECK CONSTRAINT [CK_Weekday_DaysAfterSunday]
GO

EXEC utility.usp_Create_HistoryTable @Schema_Name =	'reference' , @Table_Name = 'Weekday'	, @IncludeContextInfoChecks	= 0 , @Mode = 'RUN' , @DEBUG = 1;
GO

INSERT INTO reference.[Weekday]
(
	[Name]	
,	ThreeLetterAbbreviation	
,	OneLetterAbbreviation	
,	DaysAfterSunday
)
VALUES ('Sunday','SUN','U',0)
,('Monday','MON','M',1)
,('Tuesday','TUE','T',2)
,('Wednesday','WED','W',3)
,('Thursday','THU','R',4)
,('Friday','FRI','F',5)
,('Saturday','SAT','S',6)
--
;

GO
/**************************************************************************************

	Displays Weekday records. 

		
		Example:  


			SELECT		X.*  
			FROM		reference.vw_Weekday  X  
			ORDER BY	X.DaysAfterSunday  ASC  
			; 


	Date			Action	
	----------		----------------------------
	2020-04-27		Created initial version. 

**************************************************************************************/	
CREATE VIEW [reference].[vw_Weekday]	
AS	

	SELECT		X.ID 
	--
	,			X.[Name] 
	,			X.ThreeLetterAbbreviation 
	,			X.OneLetterAbbreviation 
	,			X.DaysAfterSunday 
	--
	FROM		reference.[Weekday]  X  

GO

--
--

CREATE TABLE [reference].[CalendarDate](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[CalendarDate] [date] NOT NULL,
	[YearNumber] [int] NOT NULL,
	[MonthNumber] [tinyint] NOT NULL,
	[DayNumber] [int] NOT NULL,
	[DayInYear] [int] NOT NULL,
	[DaysAfterSunday] [tinyint] NOT NULL,

	[InsertTime] [datetime] NOT NULL,
	[InsertBy] [varchar](128) NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[UpdateBy] [varchar](128) NOT NULL,

 CONSTRAINT [PK_CalendarDate] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)) 
GO

ALTER TABLE [reference].[CalendarDate] ADD  CONSTRAINT [DF_CalendarDate_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE [reference].[CalendarDate] ADD  CONSTRAINT [DF_CalendarDate_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE [reference].[CalendarDate] ADD  CONSTRAINT [DF_CalendarDate_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE [reference].[CalendarDate] ADD  CONSTRAINT [DF_CalendarDate_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO

CREATE NONCLUSTERED INDEX [IX_CalendarDate_DaysAfterSunday] ON [reference].[CalendarDate]
(
	[DaysAfterSunday] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_CalendarDate] ON [reference].[CalendarDate]
(
	[CalendarDate] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_CalendarDate_Numbers] ON [reference].[CalendarDate]
(
	[YearNumber] ASC,
	[MonthNumber] ASC,
	[DayNumber] ASC
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UIX_CalendarDate_YearNumberAndDayInYear] ON [reference].[CalendarDate]
(
	[YearNumber] ASC,
	[DayInYear] ASC
)
GO

ALTER TABLE [reference].[CalendarDate]  WITH CHECK ADD  CONSTRAINT [FK_CalendarDate_DaysAfterSunday] FOREIGN KEY([DaysAfterSunday])
REFERENCES [reference].[Weekday] ([DaysAfterSunday])
GO

ALTER TABLE [reference].[CalendarDate] CHECK CONSTRAINT [FK_CalendarDate_DaysAfterSunday]
GO

ALTER TABLE [reference].[CalendarDate]  WITH CHECK ADD  CONSTRAINT [FK_CalendarDate_MonthNumber] FOREIGN KEY([MonthNumber])
REFERENCES [reference].[Month] ([Number])
GO

ALTER TABLE [reference].[CalendarDate] CHECK CONSTRAINT [FK_CalendarDate_MonthNumber]
GO

EXEC utility.usp_Create_HistoryTable @Schema_Name =	'reference' , @Table_Name = 'CalendarDate'	, @IncludeContextInfoChecks	= 0 , @Mode = 'RUN' , @DEBUG = 1;
GO

GO
/**************************************************************************************

	Displays CalendarDate records with additional Month and Weekday information. 

		
		Example:  


			SELECT		X.*  
			FROM		reference.vw_CalendarDate  X  
			ORDER BY	X.CalendarDate  ASC  
			; 


	Date			Action	
	----------		----------------------------
	2015-12-16		Created initial version. 
	2020-04-27		Minor revisions. 

**************************************************************************************/	
CREATE VIEW [reference].[vw_CalendarDate]	
AS	

	SELECT		C.ID 
	--
	,			C.CalendarDate 
	--
	,			C.YearNumber 
	,			C.MonthNumber 
	,			C.DayNumber 
	--
	,			C.DayInYear 
	--
	,			C.DaysAfterSunday 
	--
	,			M.[Name]					Month_Name 
	,			M.ThreeLetterAbbreviation	Month_ThreeLetterAbbreviation 
	--
	,			W.[Name]					Weekday_Name 
	,			W.ThreeLetterAbbreviation	Weekday_ThreeLetterAbbreviation 
	,			W.OneLetterAbbreviation		Weekday_OneLetterAbbreviation 
	--
	FROM		reference.CalendarDate  C  
	INNER JOIN	reference.[Month]	    M  ON  C.MonthNumber = M.Number 
	INNER JOIN	reference.[Weekday]	    W  ON  C.DaysAfterSunday = W.DaysAfterSunday 

GO

--
--
--
--

--
--

CREATE TYPE [reference].[UTT_IntegerIDList] AS TABLE(
	[ID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

--
--

--
--
--
--

--
--

CREATE FUNCTION [reference].[fcn_EasterSunday_Computus]   	
(
	@YearNumber		int				
)
RETURNS date	  
AS
/**************************************************************************************

	Returns the date of Easter Sunday for a provided calendar year. 

		The calculation is based on non-astronomical lunar calendar tables. 
	

		Example:	


			SELECT	X.YearNumber	
			,		reference.fcn_EasterSunday_Computus ( X.YearNumber ) EasterSunday_CalendarDate 
			FROM	(
						VALUES	( 2015 )
						,		( 2016 ) 
						,		( 2017 ) 
						,		( 2018 ) 
						,		( 2019 ) 
						,		( 2020 ) 
						,		( 2021 ) 
						,		( 2022 ) 
						,		( 2777 )		
					)	
						X	( YearNumber )
			ORDER BY	X.YearNumber	ASC		
			;		


	Date			Action	
	----------		----------------------------
	2016-01-27		Created initial version.	

**************************************************************************************/	
BEGIN
	
	--
	--	This is Oudin's algorithm (1940) copied from (http://)aa.usno.navy.mil/faq/docs/easter.php 
	--	

	DECLARE		@C			int 
	,			@N			int 
	,			@K			int 
	,			@I			int 
	,			@J			int 
	,			@L			int 
	,			@M			int 
	,			@D			int 
	--
	,			@Output		date	
	--
	;	
	--

	SET @C = @YearNumber / 100 ;	/* note that these are all integer operations */ 
	SET @N = @YearNumber % 19 ; 
	SET @K = ( @C - 17 ) / 25 ; 
	SET @I = @C - @C / 4 - ( @C - @K ) / 3 + 19 * @N + 15 ;
	SET @I = @I % 30 ;
	SET @I = @I - ( @I / 28 ) * ( 1 - ( @I / 28 ) * ( 29 / ( @I + 1 ) ) * ( ( 21 - @N ) / 11 ) ) ;
	SET @J = @YearNumber + @YearNumber / 4 + @I + 2 - @C + @C / 4 ;
	SET @J = @J % 7 ; 
	SET @L = @I - @J ; 
	SET @M = 3 + ( @L + 40 ) / 44 ; 
	SET @D = @L + 28 - 31 * ( @M / 4 ) ; 

	--
	--

	SET @Output = dateadd(day,@D-1,dateadd(month,@M-1,dateadd(year,@YearNumber-2000,'Jan 01, 2000'))) ; 
	
	--
	--

	RETURN @Output ; 

	--
	--

END

GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Returns the date of Easter Sunday within a provided calendar year' , @level0type=N'SCHEMA',@level0name=N'reference', @level1type=N'FUNCTION',@level1name=N'fcn_EasterSunday_Computus'
--GO

--
--
--
--

CREATE PROCEDURE [reference].[usp_Populate_CalendarDate]  
	@MinimumDate	date			=	null	
,	@MaximumDate	date			=	null	
--
,	@Mode			varchar(5)		=	'VIEW'		--	'VIEW' , 'STORE'	
--
,	@DEBUG			bit				=	0	
--
AS
/**************************************************************************************

	Adds new records to the table reference.CalendarDate 
		covering the provided input date range. 

		
		Example:	


			EXEC	reference.usp_Populate_CalendarDate 
						@MinimumDate	=	'Jan 1, 1950' 
					,	@MaximumDate	=	'Dec 31, 2099' 
					--
					,	@Mode			=	'STORE' 
					--
					,	@DEBUG			=	1 
			; 


	Date			Action	
	----------		----------------------------
	2015-12-16		Created initial version. 
	2020-04-27		Minor revisions.

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	--
	--

	DECLARE		@ErrorMessage				varchar(500)	
	,			@RowCount					int				
	--
	,			@RecordCount				int				
	,			@MaximumRecordCount			int				=	200000
	--
	,			@Generation_MinimumDate		date			
	,			@Generation_MaximumDate		date			
	,			@Generation_RecordCount		int				
	--
	,			@ReferenceSunday			date			=	'Jan 02, 2000'	
	--
	,			@Iterator					int				
	--	
	;
	
	--
	--

	DECLARE @Integer TABLE 
	(
		[Value]		int		not null	primary key 
	)
	;

	CREATE TABLE #staging_CalendarDate	
	(
		ID					int			not null	identity(1,1)	primary key 
	--
	,	CalendarDate		date		not null	unique	
	--
	,	YearNumber			int			not null 
	,	MonthNumber			tinyint		not null 
	,	DayNumber			int			not null 
	--
	,	DayInYear			int			not null 
	--
	,	DaysAfterSunday		tinyint		not null 
	--
	,	UNIQUE  (
					YearNumber 
				,	MonthNumber 
				,	DayNumber	
				)	
	,	UNIQUE	(
					YearNumber	 
				,	DayInYear	
				)
	)
	;

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Check input parameters.' ) END ; 

		IF @MinimumDate IS NULL 
		OR @MaximumDate IS NULL 
		BEGIN 
			SET @ErrorMessage = 'Both @MinimumDate and @MaximumDate must be provided.' 
			GOTO ERROR ;
		END		

		IF @MinimumDate > @MaximumDate 
		BEGIN 
			SET @ErrorMessage = '@MaximumDate must not be earlier than @MinimumDate.' 
			GOTO ERROR ;
		END		


		--
		--	calculate number of records requested 	
		--
		BEGIN TRY	
			
			SET @RecordCount = DATEDIFF(day,@MinimumDate,@MaximumDate) + 1 ;

		END TRY 
		BEGIN CATCH		
			SET @ErrorMessage = 'There was an error calculating size of input date range.' 
			GOTO ERROR ;
		END CATCH	


		IF @RecordCount > @MaximumRecordCount 
		BEGIN 
			SET @ErrorMessage = 'The provided date range is too large.' 
			GOTO ERROR ;
		END		

	--
	--
	
		/*
			Date generation range must start from the first date in a calendar year
			 in order to compute 'DayInYear' statistic for each relevant date.
		*/	

	SET @Generation_MinimumDate = DATEADD(month,1-MONTH(@MinimumDate),DATEADD(day,1-day(@MinimumDate),@MinimumDate)) ;
	SET	@Generation_MaximumDate = @MaximumDate ;
	SET @Generation_RecordCount = DATEDIFF(day,@Generation_MinimumDate,@Generation_MaximumDate) + 1 ;

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Generate list of integer values for computations.' ) END ; 
	
	--
	--	store all integer values from 0 to ( @Generation_RecordCount - 1 ) in @Integer table 
	--	
	SET @Iterator = 0 ; 
	WHILE @Iterator < @Generation_RecordCount 
	BEGIN 
		INSERT INTO @Integer	 
		(
			[Value] 
		)	
		VALUES ( @Iterator ) 
		; 
		SET @Iterator += 1 ; 
	END 

	SELECT	@RowCount = COUNT(*) 
	FROM	@Integer  I	 
	; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Calculate and stage requested CalendarDate information.' ) END ; 
	
	BEGIN TRY 

		INSERT INTO #staging_CalendarDate	
		(
			CalendarDate		
		--
		,	YearNumber			
		,	MonthNumber			
		,	DayNumber			
		--
		,	DayInYear			
		--
		,	DaysAfterSunday		
		)	

			SELECT		Y.CalendarDate 
			--
			,			Y.YearNumber 
			,			Y.MonthNumber 
			,			Y.DayNumber 
			--
			,			Y.DayInYear		
			--
			,			Y.DaysAfterSunday	
			FROM		(
							SELECT		X.CalendarDate				CalendarDate	
							--
							,			YEAR  (X.CalendarDate)		YearNumber	
							,			MONTH (X.CalendarDate)		MonthNumber 
							,			DAY	  (X.CalendarDate)		DayNumber	
							--
							,			RANK() OVER ( PARTITION BY YEAR(X.CalendarDate) 
													  ORDER BY X.CalendarDate ASC )		as  DayInYear	
							--
							,			CASE WHEN @ReferenceSunday <= X.CalendarDate 
											 THEN DATEDIFF(day, @ReferenceSunday, X.CalendarDate) % 7 
											 ELSE ( 7 - DATEDIFF(day, X.CalendarDate, @ReferenceSunday) % 7 ) % 7 
										END	 
										as  DaysAfterSunday		
							FROM		(
											SELECT	dateadd(day, I.[Value], @Generation_MinimumDate)  as  CalendarDate	
											FROM	@Integer	I	
										)	
											X	
						)	
							Y	
			WHERE	Y.CalendarDate BETWEEN @MinimumDate AND @MaximumDate 
			;

		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END TRY 
	BEGIN CATCH

		SET @ErrorMessage = 'An error occurred while staging requested CalendarDate records.' 
		GOTO ERROR 

	END CATCH 

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Compare new calculations to existing cache.' ) END ; 

		IF EXISTS ( SELECT		null	
					FROM		#staging_CalendarDate	C	
					INNER JOIN	reference.CalendarDate	D	ON	C.CalendarDate = D.CalendarDate 
					WHERE		C.YearNumber != D.YearNumber 
					OR			C.MonthNumber != D.MonthNumber 
					OR			C.DayNumber != D.DayNumber 
					OR			C.DayInYear != D.DayInYear 
					OR			C.DaysAfterSunday != D.DaysAfterSunday )	 
		BEGIN 
			IF @DEBUG = 1 
			BEGIN 
				SELECT		'Discrepancy between cached CalendarDate records and new calculations: '	Information		
				,			C.CalendarDate	
				,			C.YearNumber		New_YearNumber 
				,			D.YearNumber		Cached_YearNumber 
				,			C.MonthNumber		New_MonthNumber 
				,			D.MonthNumber		Cached_MonthNumber	
				,			C.DayNumber			New_DayNumber 
				,			D.DayNumber			Cached_DayNumber 
				,			C.DayInYear			New_DayInYear	
				,			D.DayInYear			Cached_DayInYear 
				,			C.DaysAfterSunday	New_DaysAfterSunday 
				,			D.DaysAfterSunday	Cached_DaysAfterSunday	
				FROM		#staging_CalendarDate	C	
				INNER JOIN	reference.CalendarDate	D	ON	C.CalendarDate = D.CalendarDate 
				WHERE		C.YearNumber != D.YearNumber 
				OR			C.MonthNumber != D.MonthNumber 
				OR			C.DayNumber != D.DayNumber 
				OR			C.DayInYear != D.DayInYear 
				OR			C.DaysAfterSunday != D.DaysAfterSunday	
			END		

			SET @ErrorMessage = 'There is a discrepancy between cached CalendarDate records and new calculations.' 
			GOTO ERROR 
		END		

		IF EXISTS ( SELECT		null	
					FROM		reference.CalendarDate	D	
					LEFT  JOIN	#staging_CalendarDate	C	ON	D.CalendarDate = C.CalendarDate 
					WHERE		C.ID IS NULL 
					AND			D.CalendarDate BETWEEN @MinimumDate AND @MaximumDate ) 
		BEGIN 
			IF @DEBUG = 1 
			BEGIN 
				SELECT		'Date exists in cache but not in new calculations: '	Information		
				,			D.CalendarDate	
				FROM		reference.CalendarDate	D	
				LEFT  JOIN	#staging_CalendarDate	C	ON	D.CalendarDate = C.CalendarDate 
				WHERE		C.ID IS NULL 
				AND			D.CalendarDate BETWEEN @MinimumDate AND @MaximumDate	
			END		
			
			SET @ErrorMessage = 'There is a cached date in the provided range which does not exist in new calculations.' 
			GOTO ERROR 
		END		

		IF EXISTS ( SELECT		null 
					FROM		#staging_CalendarDate	C	
					LEFT  JOIN	reference.CalendarDate	D	ON	C.CalendarDate = D.CalendarDate 
					WHERE		D.ID IS NULL ) 
		BEGIN 
			IF @DEBUG = 1 
			BEGIN 
				SELECT		@RowCount = COUNT(*) 
				FROM		#staging_CalendarDate	C	
				LEFT  JOIN	reference.CalendarDate	D	ON	C.CalendarDate = D.CalendarDate 
				WHERE		D.ID IS NULL

				PRINT dbo.fcn_DebugInfo( 'There are ' + convert(varchar(20),@RowCount) + ' dates in the new calculations which do not exist in the persistent cache.' )
			END		
		END			
	
	--
	--

	IF @Mode = 'VIEW' 
	BEGIN 

		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Display calculated CalendarDate information.' ) END ; 

			SELECT		C.CalendarDate 
			--
			,			C.YearNumber 
			,			C.MonthNumber 
			,			C.DayNumber 
			--
			,			C.DayInYear 
			--
			,			C.DaysAfterSunday 
			--	
			FROM		#staging_CalendarDate	C	
			ORDER BY	C.CalendarDate ASC 
		
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END		
	ELSE IF @Mode = 'STORE' 
	BEGIN 
		
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'Store new CalendarDate information to persistent table.' ) END ; 

			INSERT INTO reference.CalendarDate 
			(
				CalendarDate 
			--
			,	YearNumber 
			,	MonthNumber 
			,	DayNumber 
			--
			,	DayInYear 
			--
			,	DaysAfterSunday		
			)	

			SELECT		C.CalendarDate 
			--
			,			C.YearNumber 
			,			C.MonthNumber 
			,			C.DayNumber 
			--
			,			C.DayInYear 
			--
			,			C.DaysAfterSunday 
			--
			FROM		#staging_CalendarDate	C	
			LEFT  JOIN	reference.CalendarDate	D	ON	C.CalendarDate = D.CalendarDate		
			WHERE		D.ID IS NULL 
			ORDER BY	C.CalendarDate ASC 
		
		SET @RowCount = @@ROWCOUNT 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( ' rows: ' + convert(varchar(20),@RowCount) ) END ; 

	END		

	--
	--

	FINISH:		

	--
	DROP TABLE #staging_CalendarDate 
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	RETURN 1 ; 

	--
	--
	
	ERROR:	

	--
	IF OBJECT_ID('tempdb..#staging_CalendarDate') IS NOT NULL DROP TABLE #staging_CalendarDate 
	--

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END		

	RETURN -1 ; 

END 

GO

--
--
--
--

CREATE PROCEDURE [reference].[usp_Generate_Holiday] 
	@MinYear					int				=	null	
,	@MaxYear					int				=	null	
--
--,	@Mode						varchar(5)		=	'VIEW'	--	'VIEW' or 'STORE'	
,	@UpdateConflictingYears		bit				=	0	
--
,	@DEBUG						bit				=	0 
-- 
AS
/**************************************************************************************

	Estimates dates for Holidays and updates the lookup table if desired.

		
		Example:	


			EXEC  reference.usp_Generate_Holiday 
				  	  @MinYear				    =    2000 
				  ,	  @MaxYear				    =    2099  
				  --  						     
				  ,	  @UpdateConflictingYears	=	  0	
				  --  							
				  ,	  @DEBUG					=     1
			;	


	Date			Action	
	----------		----------------------------
	2016-01-27		Created initial version.	
	2016-04-15		Added Monday/Tuesday logic for years when Christmas falls on a weekend. 
	2017-12-13		Re-classified holidays (added separate HolidayCalendar categories for Civic Holiday and Remembrance Day). 
					Removed @HolidayCalendar_Name parameter (always running all holidays at once, for now). 
	2022-04-10		Removed (commented) @Mode parameter for GITHUB (no dependent tables exist here). 

**************************************************************************************/	
BEGIN
	SET NOCOUNT ON;

	DECLARE		@ErrorMessage								varchar(250)	=	 null
	,			@RowCount									int				=	 0		 
	--
	,			@HolidayCalendar_Name_OntarioStatutory		varchar(50)		=	'Ontario Statutory'	
	,			@HolidayCalendar_Name_CivicHoliday			varchar(50)		=	'Civic Holiday'	
	,			@HolidayCalendar_Name_RemembranceDay 		varchar(50)		=	'Remembrance Day'	
	--	
	;	

	--
	--

----IF @Mode IS NULL 
----OR @Mode NOT IN ( 'VIEW' , 'STORE' )	
----BEGIN 
----	SET @ErrorMessage = '@Mode value must be either ''VIEW'' or ''STORE''.' ; 
----	GOTO ERROR ; 
----END 

	IF @MinYear IS NULL 
	OR @MaxYear IS NULL 
	OR (
		  @MinYear > @MaxYear 
	   ) 
	BEGIN 
		SET @ErrorMessage = 'Both @MinYear and @MaxYear must be non-null, with @MinYear <= @MaxYear.' ; 
		GOTO ERROR ; 
	END 
	
	--
	--

----IF EXISTS ( SELECT	null	
----			FROM	(	
----						VALUES	
----						( @HolidayCalendar_Name_OntarioStatutory )	
----					,	( @HolidayCalendar_Name_CivicHoliday	 )	
----					,	( @HolidayCalendar_Name_RemembranceDay	 )
----					)	
----						C	( HolidayCalendar_Name )	
----			LEFT  JOIN	reference.HolidayCalendar	X	ON	C.HolidayCalendar_Name = X.[Name] 
----			WHERE		X.ID IS NULL )		
----BEGIN	
----	SET @ErrorMessage = 'At least one configured HolidayCalendar Name value does not exist in table.' 
----	GOTO ERROR	
----END		
	
	--
	--

	CREATE TABLE #CalendarDate 
	(
		ID					int				not null	identity(1,1)	primary key 
	--
	,	CalendarDate		date			not null	unique	
	,	YearNumber			int				not null 
	,	MonthNumber			tinyint			not null 
	,	DayNumber			int				not null 
	,	DaysAfterSunday		tinyint			not null 
	,	DayInYear			int				not null 
	--
	,	Month_LongName		varchar(20)		not null	
	,	Weekday_LongName	varchar(10)		not null	
	); 
		CREATE UNIQUE NONCLUSTERED INDEX #UIX_CalendarDate ON #CalendarDate 
		(
			YearNumber 
		,	MonthNumber 
		,	DayNumber 
		); 
		CREATE NONCLUSTERED INDEX #IX_CalendarDate_MonthAndWeekday ON #CalendarDate 
		(
			Month_LongName 
		,	Weekday_LongName 
		,	YearNumber
		); 

	CREATE TABLE #Holiday 
	(
		ID						int				not null	identity(1,1)	primary key 
	--
	,	CalendarDate			date			not null	
	,	[Name]					varchar(100)	not null	
	,	Note					varchar(200)	null	
	,	HolidayCalendar_Name	varchar(50)		not null	
	--
	,	UNIQUE  (
					HolidayCalendar_Name 
				,	CalendarDate 
				) 
	);

	--
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'BEGIN ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	--
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo('Gather calendar date information for relevant range.') END ; 

		INSERT INTO #CalendarDate 
		(
			CalendarDate 
		,	YearNumber 
		,	MonthNumber 
		,	DayNumber 
		,	DaysAfterSunday		
		,	DayInYear	
		--
		,	Month_LongName 
		,	Weekday_LongName 
		--
		) 

		SELECT		C.CalendarDate 
		,			C.YearNumber 
		,			C.MonthNumber 
		,			C.DayNumber 
		,			C.DaysAfterSunday		
		,			C.DayInYear	
		--
		,			M.[Name] 
		,			W.[Name] 
		--
		FROM		reference.CalendarDate		C	
		INNER JOIN	reference.[Weekday]			W	ON	C.DaysAfterSunday = W.DaysAfterSunday 
													AND C.YearNumber >= @MinYear  
													AND C.YearNumber <= @MaxYear 
		INNER JOIN	reference.[Month]			M	ON	C.MonthNumber = M.Number 
		; 

	SET @RowCount = @@ROWCOUNT ; 
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo(' rows: ' + convert(varchar(20),@RowCount) ) END ; 
	
	--
	--
		
		--
		--
		--
		--	CALCULATE ESTIMATED HOLIDAY DATES 
		--
		--
		--
		
	-- 	
	--
	
	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo('Calculate estimated holiday dates.') END ; 
	
	--
	--
		
		/*	
		
			Holidays to estimate, with descriptions: 
			
				-	New Year's Day			:	always January 1st  
				-	Family Day				:	third Monday in February  
				-	Good Friday				:	Friday before Easter Sunday (Easter Sunday calculated with Computus algorithm) 
				-	Victoria Day			:	last Monday before May 25 
				-	Canada Day				:	July 1st, or following Monday if falling on a weekend 
				-	Civic/Provincial Day	:	first Monday in August 
				-	Labour Day				:	first Monday in September 
				-	Thanksgiving Day		:	second Monday in October 
				-	Remembrance Day			:	November 11th, or following Monday if falling on a weekend 
				-	Christmas				:	December 25th, subject to Note* below  
				-	Boxing Day				:	December 26th, or following Monday if falling on a weekend, subject to Note* below 
		
					Note* : if Christmas falls on a weekend, the following Monday 
							 will be a non-business day for Christmas, 
							 and the Tuesday will be a non-business day for Boxing Day.  

		*/	
		
		--
		--
		--
	
			--
			--	Constant dates : 
			--	
			--	New Year's Day 
			--	Canada Day 
			--	Christmas 
			--	Boxing Day 
			--	
		INSERT INTO #Holiday 
		(
			CalendarDate 
		,	[Name]
		,	Note  
		,	HolidayCalendar_Name 
		)	
		
		SELECT		CASE WHEN C.Weekday_LongName IN ('Saturday','Sunday') 
						 AND  X.RecognizedOnFollowingMonday = 1  
						 THEN coalesce(Y.FollowingMonday,C.CalendarDate) 
						 ELSE C.CalendarDate 
					END		
		,			X.Holiday_Name
		,			CASE WHEN C.Weekday_LongName IN ('Saturday','Sunday') 
						 AND  X.RecognizedOnFollowingMonday = 1  
						 AND  Y.FollowingMonday IS NOT NULL 
						 THEN 'Recognized on following Monday.' 
						 ELSE null 
					END			
		,			CASE WHEN X.Holiday_Name = 'Remembrance Day'	
						 THEN @HolidayCalendar_Name_RemembranceDay 
						 --
						 ELSE @HolidayCalendar_Name_OntarioStatutory 
						 --
					END		  
		--
		FROM		#CalendarDate		C	
		INNER JOIN	(
						VALUES	( 'New Year''s Day'	 ,   1  ,   1  ,  0  ) 
						,		( 'Canada Day'		 ,   7  ,   1  ,  1  ) 
						--
						,		( 'Remembrance Day'	 ,  11  ,  11  ,  1  )	
						--
						,		( 'Christmas'		 ,  12  ,  25  ,  0	 ) 
						,		( 'Boxing Day'		 ,  12  ,  26  ,  1  ) 
					)	
						X	( Holiday_Name , MonthNumber , DayNumber , RecognizedOnFollowingMonday )	
							ON	C.MonthNumber = X.MonthNumber 
							AND C.DayNumber = X.DayNumber 
		OUTER APPLY (
						SELECT		MIN(Cs.CalendarDate)	FollowingMonday 
						FROM		#CalendarDate	Cs	
						WHERE		C.Weekday_LongName IN ('Saturday','Sunday') 
						AND			X.RecognizedOnFollowingMonday = 1 
						AND			Cs.CalendarDate > C.CalendarDate 
						AND			Cs.Weekday_LongName = 'Monday' 
					)	
						Y	
		;	
		
			/*  2016-04-15 addition : 
			
					In a year when Christmas falls on a weekend, 
					 the following Monday and Tuesday are both non-business days 
					  for Christmas and Boxing Day respectively. 
				
			*/ 

				UPDATE		Y	
				SET			Y.CalendarDate = CASE Y.[Name] 
												WHEN 'Christmas' THEN CASE X.DaysAfterSunday 
																		WHEN 0 THEN dateadd(day,1,Y.CalendarDate) 
																		WHEN 6 THEN dateadd(day,2,Y.CalendarDate) 
																	  END 
												WHEN 'Boxing Day' THEN dateadd(day,1,Y.CalendarDate) 
										     END 
				,			Y.Note = CASE Y.[Name]	
									   WHEN 'Christmas' THEN 'Recognized on following Monday.' 
									   WHEN 'Boxing Day' THEN 'Recognized on following Tuesday.' 
									 END 
				--
				FROM		(
								SELECT		C.YearNumber 
								,			C.DaysAfterSunday 
								--
								FROM		#Holiday				H	
								INNER JOIN	reference.CalendarDate	C	ON	H.CalendarDate = C.CalendarDate 
								--
								WHERE		H.HolidayCalendar_Name = @HolidayCalendar_Name_OntarioStatutory 
								AND			H.[Name] = 'Christmas' 
								AND			C.DaysAfterSunday IN ( 0 , 6 )	--  Saturday or Sunday 
								--
							)	
										X	
				INNER JOIN	#Holiday	Y	ON	X.YearNumber = YEAR(Y.CalendarDate)		
											AND Y.HolidayCalendar_Name = @HolidayCalendar_Name_OntarioStatutory 
											AND Y.[Name] IN ('Christmas','Boxing Day')	

			/*  end of 2016-04-15 addition */ 

		--
		--
		--
		
			--
			--	Ascending Rank in Month : 
			--	
			--	Family Day 
			--	Civic/Provincial Day 
			--	Labour Day 
			--	Thanksgiving Day 
			--	
		INSERT INTO #Holiday 
		(
			CalendarDate	
		,	[Name]			
		,	Note			
		,	HolidayCalendar_Name	
		)	
		
		SELECT		Y.CalendarDate 
		,			X.Holiday_Name	
		,			null	
		,			CASE WHEN X.Holiday_Name = 'Civic/Provincial Day'	
						 THEN @HolidayCalendar_Name_CivicHoliday 
						 --
						 ELSE @HolidayCalendar_Name_OntarioStatutory 
						 --
					END		
		--
		FROM		(
						VALUES	( 'Family Day'			  ,  'February'   ,  'Monday'  ,  3  ) 
						--	
						,		( 'Civic/Provincial Day'  ,  'August'     ,  'Monday'  ,  1  )
						--	 
						,		( 'Labour Day'			  ,  'September'  ,  'Monday'  ,  1  ) 
						,		( 'Thanksgiving Day'	  ,  'October'    ,  'Monday'  ,  2  ) 
					)	
						X	( Holiday_Name , Month_LongName , Weekday_LongName , AscendingRankInMonth )	
		CROSS APPLY (
						SELECT		R.CalendarDate 
						FROM		(
										SELECT		C.CalendarDate 
										,			RANK() OVER ( PARTITION BY	C.YearNumber	
																  ORDER BY		C.CalendarDate ASC )	AscendingRankInMonth 
										FROM		#CalendarDate	C	
										WHERE		C.Month_LongName = X.Month_LongName 
										AND			C.Weekday_LongName = X.Weekday_LongName 
									)	
										R 
						WHERE		R.AscendingRankInMonth = X.AscendingRankInMonth 	
					)	
						Y	
		;	
		
		--
		--
		--
		
			--
			--	Good Friday  
			--	
		INSERT INTO #Holiday 
		(
			CalendarDate 
		,	[Name] 
		,	Note 
		,	HolidayCalendar_Name 
		)	
		
		SELECT		Z.CalendarDate			
		,			'Good Friday'			
		,			null	
		,			@HolidayCalendar_Name_OntarioStatutory	
		--
		FROM		(
						SELECT	distinct	C.YearNumber 
						FROM	#CalendarDate	C	
					)	
						X	
		CROSS APPLY (
						SELECT	reference.fcn_EasterSunday_Computus ( X.YearNumber )  EasterSundayDate 
					)	
						Y	
		INNER JOIN	#CalendarDate	Z	ON	X.YearNumber = Z.YearNumber							
										AND Z.Weekday_LongName = 'Friday'						
										AND Z.CalendarDate = DATEADD(day,-2,Y.EasterSundayDate)	
		;	
		
		--
		--
		--
		
			--
			--	Victoria Day  
			--	
		INSERT INTO #Holiday 
		(
			CalendarDate 
		,	[Name] 
		,	Note  
		,	HolidayCalendar_Name 
		)	
		
		SELECT		MAX(D.CalendarDate)		
		,			'Victoria Day'			
		,			null	
		,			@HolidayCalendar_Name_OntarioStatutory	
		--
		FROM		#CalendarDate	Z	
		INNER JOIN	#CalendarDate	D	ON	Z.MonthNumber = 5 
										AND Z.DayNumber = 25 
										AND Z.YearNumber = D.YearNumber 
										AND D.MonthNumber = 5 
										AND Z.CalendarDate > D.CalendarDate 
										AND D.Weekday_LongName = 'Monday' 
		GROUP BY	Z.YearNumber 
		;	
		
		--
		--
		
		IF @DEBUG = 1 
		BEGIN 
			SELECT	@RowCount = COUNT(*) 
			FROM	#Holiday	H	; 
			
			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo(' rows: ' + convert(varchar(20),@RowCount) ) END ; 
		END 
	
	--
	--
	
----IF @Mode = 'VIEW' 
----BEGIN 
	
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo('Display results.') END ; 
	
		SELECT		H.CalendarDate 
		,			H.[Name] 
		,			H.Note  
		,			H.HolidayCalendar_Name 
		--
		FROM		#Holiday	H	
		--
		ORDER BY	H.CalendarDate			ASC		
		,			H.HolidayCalendar_Name	ASC 
		--
		;

		SET @RowCount = @@ROWCOUNT ; 
		IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo(' rows: ' + convert(varchar(20),@RowCount) ) END ; 
			
----END		
----ELSE IF @Mode = 'STORE' 
----BEGIN 
----
----	--
----	--
----	
----	IF EXISTS ( SELECT		null 
----				FROM		(
----								SELECT	distinct	H.HolidayCalendar_Name	
----								FROM	#Holiday	H	
----							)	
----								X	
----				LEFT  JOIN	reference.HolidayCalendar	Y	ON	X.HolidayCalendar_Name = Y.[Name] 
----				WHERE		Y.ID IS NULL )	
----	BEGIN	
----		IF @DEBUG = 1 
----		BEGIN 
----			SELECT		'Unexpected HolidayCalendar_Name value:'	Information		
----			--	
----			,			X.HolidayCalendar_Name	
----			--	
----			FROM		(
----							SELECT	distinct	H.HolidayCalendar_Name	
----							FROM	#Holiday	H	
----						)	
----							X	
----			LEFT  JOIN	reference.HolidayCalendar	Y	ON	X.HolidayCalendar_Name = Y.[Name] 
----			WHERE		Y.ID IS NULL
----		END		
----
----		SET @ErrorMessage = 'At least one staged HolidayCalendar_Name value does not exist in HolidayCalendar table.' 
----		GOTO ERROR	
----	END		
----	
----	--
----	--
----
----	IF EXISTS ( SELECT		null	
----				FROM		(
----								SELECT	distinct	YEAR(H.CalendarDate)	YearNumber 
----								,					H.HolidayCalendar_Name		
----								FROM	#Holiday		H	
----							)	
----								X	
----				INNER JOIN	reference.HolidayCalendar	T	ON	X.HolidayCalendar_Name =  T.[Name] 
----				INNER JOIN	reference.Holiday			E	ON	T.ID = E.HolidayCalendarID 
----															AND X.YearNumber = YEAR(E.CalendarDate)		
----				LEFT  JOIN	#Holiday					N	ON	E.CalendarDate = N.CalendarDate 
----															AND E.[Name] = N.[Name]	
----															AND T.[Name] = N.HolidayCalendar_Name 
----															--
----															AND ( 
----																	E.Note = N.Note		
----																OR	(
----																		E.Note IS NULL 
----																	AND N.Note IS NULL	
----																	)	
----																)	
----															--		
----				WHERE		N.CalendarDate IS NULL ) 
----	BEGIN 
----	
----		IF coalesce(@UpdateConflictingYears,0) = 0  
----		BEGIN 
----			IF @DEBUG = 1 
----			BEGIN 
----				SELECT		'Existing Holiday record does not appear in new record-set: '	Information		
----				--
----				,			E.ID			HolidayID 
----				,			T.[Name]		HolidayCalendar_Name 
----				,			E.CalendarDate		
----				,			E.[Name]				
----				,			E.Note 		
----				--
----				,			E.InsertTime	
----				,			E.UpdateTime	
----				--
----				FROM		(
----								SELECT	distinct	YEAR(H.CalendarDate)	YearNumber 
----								,					H.HolidayCalendar_Name		
----								FROM	#Holiday		H	
----							)	
----								X	
----				INNER JOIN	reference.HolidayCalendar	T	ON	X.HolidayCalendar_Name =  T.[Name] 
----				INNER JOIN	reference.Holiday			E	ON	T.ID = E.HolidayCalendarID 
----															AND X.YearNumber = YEAR(E.CalendarDate)		
----				LEFT  JOIN	#Holiday					N	ON	E.CalendarDate = N.CalendarDate 
----															AND E.[Name] = N.[Name]	
----															AND T.[Name] = N.HolidayCalendar_Name 
----															--
----															AND ( 
----																	E.Note = N.Note		
----																OR	(
----																		E.Note IS NULL 
----																	AND N.Note IS NULL	
----																	)	
----																)	
----															--		
----				WHERE		N.CalendarDate IS NULL 
----			END		
----		
----			SET @ErrorMessage = 'There is a conflict between the new estimates and the existing Holiday records.' 
----			GOTO ERROR 
----		END		
----		ELSE IF @UpdateConflictingYears = 1 
----		BEGIN 
----			
----			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo('Delete existing Holiday records which do not appear in new record-set.') END ; 
----			
----				DELETE		E	
----				FROM		(
----								SELECT	distinct	YEAR(H.CalendarDate)	YearNumber 
----								,					H.HolidayCalendar_Name		
----								FROM	#Holiday		H	
----							)	
----								X	
----				INNER JOIN	reference.HolidayCalendar	T	ON	X.HolidayCalendar_Name =  T.[Name] 
----				INNER JOIN	reference.Holiday			E	ON	T.ID = E.HolidayCalendarID 
----															AND X.YearNumber = YEAR(E.CalendarDate)		
----				LEFT  JOIN	#Holiday					N	ON	E.CalendarDate = N.CalendarDate 
----															AND E.[Name] = N.[Name]	
----															AND T.[Name] = N.HolidayCalendar_Name 
----															--
----															AND ( 
----																	E.Note = N.Note		
----																OR	(
----																		E.Note IS NULL 
----																	AND N.Note IS NULL	
----																	)	
----																)	
----															--		
----				WHERE		N.CalendarDate IS NULL 
----				--
----				;
----			
----			SET @RowCount = @@ROWCOUNT ; 
----			IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo(' rows: ' + convert(varchar(20),@RowCount) ) END ; 
----		
----		END		
----	
----	END		
----	
----	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo('Add new estimates to Holiday table.') END ; 
----			
----		INSERT INTO reference.Holiday	
----		(
----			HolidayCalendarID 
----		,	CalendarDate 
----		,	[Name]	
----		,	Note 	
----		)	
----	
----		SELECT		T.ID				
----		,			H.CalendarDate		
----		,			H.[Name]	
----		,			H.Note	
----		--
----		FROM		#Holiday					  H	
----		INNER JOIN	reference.HolidayCalendar	  T	  ON  H.HolidayCalendar_Name = T.[Name]	
----		LEFT  JOIN	reference.Holiday			  E	  ON  H.CalendarDate = E.CalendarDate 
----											  		  AND H.[Name] = E.[Name] 
----											  		  AND T.ID = E.HolidayCalendarID	
----													  --
----													  AND ( 
----													  	  	 H.Note = E.Note		
----													  	  OR (
----													  	  	 	 H.Note IS NULL 
----													  	  	 AND E.Note IS NULL	
----													  	  	 )	
----													  	  )	
----													  --		
----		--	
----		WHERE		E.ID IS NULL 
----		--	
----		;
----	
----	SET @RowCount = @@ROWCOUNT ; 
----	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo(' rows: ' + convert(varchar(20),@RowCount) ) END ; 
----
----END		
	
	--
	--

	FINISH: 

	--
	DROP TABLE #CalendarDate ;
	DROP TABLE #Holiday ; 
	--

	IF @DEBUG = 1 BEGIN PRINT dbo.fcn_DebugInfo( 'END ' + object_schema_name( @@PROCID ) + '.' + object_name( @@PROCID ) ) END ; 

	RETURN 1 ; 
	
	--
	--

	ERROR: 
	
	--
	IF OBJECT_ID('tempdb..#CalendarDate') IS NOT NULL DROP TABLE #CalendarDate ;
	IF OBJECT_ID('tempdb..#Holiday') IS NOT NULL DROP TABLE #Holiday ;
	--

	IF @ErrorMessage IS NOT NULL 
	BEGIN 

		RAISERROR ( @ErrorMessage , 16 , 1 ) ; 

	END		

	RETURN -1 ; 
	
END
GO

--EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Generates a list of holiday dates based on local customs and assumptions for a provided range of years' , @level0type=N'SCHEMA',@level0name=N'reference', @level1type=N'PROCEDURE',@level1name=N'usp_Generate_Holiday'
--GO

GO

--
--
--
--

--	
--	
--	
	--
	-- // END of dbo-schema Table & View CREATION statements 
	--
--	
--  CHECK STRUCTURAL INTEGRITY -- naming conventions, history tables & triggers, etc. 
--	
EXEC  utility.usp_Check_StructuralIntegrity 
  @DEBUG  =  1	
;
GO
--
-- END FILE :: r000_AllObjects.sql 
--
