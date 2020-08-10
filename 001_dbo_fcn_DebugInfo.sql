-- 
-- BEGIN // file :: 001_dbo_fcn_DebugInfo.sql 
-- 
USE [x_ANY_DATABASE_NAME_HERE] -- DEV NOTE (TJ) :: 2020-08-09 :: first script prepared for GITHUB !!! 
GO
CREATE FUNCTION [dbo].[fcn_DebugInfo]
(
	@Message	varchar(512)
)
RETURNS varchar(768)
AS
/**************************************************************************************

	Returns the current date and time (of the server, as text), 
	 usually followed by a provided message (input parameter value). 

	Intended for use in stored procedures, to report information during query execution 
	 (like the row-counts affected by noteworthy INSERT/UPDATE/DELETE transactions). 


		Example: 

			PRINT	dbo.fcn_DebugInfo(null)		; 
			WAITFOR DELAY '00:00:01.000'		; 
			PRINT	dbo.fcn_DebugInfo('test')	; 


	Date			Action	
	----------		-------------------------------------------------------------
	2020-08-09		Initial version prepared to post @ GITHUB / lance7777 / TSQL.	

**************************************************************************************/
BEGIN
	
	--
	--  (0)  Initialize variables 
	--

	DECLARE @Output				varchar(768) 	-- to be set and returned, at end 
	--
	--
	,		@CurrentTimestamp	datetime		=	getdate()		
	--
	,		@TimestampString	varchar(40)		-- value set below  // Sec. (1) 
	--
	,		@SeparatorSymbol	varchar(10)		=	' :: '		    
	--
	,		@NestLevel					int		=	coalesce(try_convert(int, @@NESTLEVEL ,2),0) - 2  -- ignore first 2 levels (first "indent" at level 3)
	--
	,		@SpacesPerNestLevel			int		=	 4	-- extra "indent" spaces are added or removed as the execution session's nest level changes
	,		@LastIndentedNestLevel		int		=	10	-- any values higher than this one are to be treated as if they're equal to this level instead
	--
	,		@IndentSpaces		varchar(100) 	-- value set below  // Sec. (2) 
	--
	,		@TextWithIndent		varchar(650) 	-- value set below  // Sec. (3) 
	--
	;
	
	--
	--  (1)  Prepare timestamp prefix for output message 
	--
	
	SET @TimestampString = convert(varchar(20),@CurrentTimestamp,20)  -- 'yyyy-MM-dd hh:mm:ss'  
	;
	
	--
	--  (2)  Determine whitespace indent, if relevant (when a sub-procedure runs from within a calling procedure)
	--
	
	SET	@IndentSpaces = SPACE( CASE WHEN @NestLevel <= 0 
								    THEN 0 
								    WHEN @NestLevel >= @LastIndentedNestLevel 
								    THEN @LastIndentedNestLevel 
								    ELSE @NestLevel 
							   END * @SpacesPerNestLevel )
	;

	--
	--  (3)  Check input message 
	--
	
	SET	@TextWithIndent = CASE WHEN @Message IS NULL 
							   OR	@Message = '' 
							   THEN '' 
							   ELSE @IndentSpaces + @Message 
						  END 
	;

	--
	--  (4)  Set and return output value 
	--
	
	SET @Output = @TimestampString + @SeparatorSymbol + @TextWithIndent 
	;

	/*** EXAMPLE: '2020-03-05 04:09:00 :: Task finished.' ***/ 
	
	RETURN @Output 
	; 

END
GO
-- 
-- END // file :: 001_dbo_fcn_DebugInfo.sql 
-- 