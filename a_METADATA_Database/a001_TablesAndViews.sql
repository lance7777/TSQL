--
-- BEGIN FILE :: a001_TablesAndViews.sql 
--
USE [a_METADATA] 
GO
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
CREATE SCHEMA serverconfig AUTHORIZATION dbo -- the "core" schema to store lists of SERVER-LEVEL objects with comments from owners/experts, etc.  
GO 
CREATE SCHEMA serverconfig_history AUTHORIZATION dbo -- necessary to deploy "history" tables, once for each table in this script 
GO 
CREATE SCHEMA dbocatalogue AUTHORIZATION dbo -- the "core" schema to store lists of DATABASE-LEVEL objects with comments from owners/experts, etc.  
GO 
CREATE SCHEMA dbocatalogue_history AUTHORIZATION dbo -- necessary to deploy "history" tables, once for each table in this script 
GO 
--
--
USE [a_METADATA] 
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
--
-- 1. (a) ScopedDatabase TABLE 
--
CREATE TABLE serverconfig.ScopedDatabase (
	[ID] [int] IDENTITY(1,1) NOT NULL,
	--
	[DatabaseName] varchar(256) not null, 
	--
	KeepingRecordsSynchronized bit not null,
	LatestCheckForSynchronizationUpdate datetime null,
	LatestObjectListChangeRecorded datetime null, 
	LatestUpdateToObjectRecordDocumentation datetime null, 
	--
	LatestSizeUpdateTimestamp datetime null,
	LatestTotalFileSize float null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_ScopedDatabase] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_ScopedDatabase_DatabaseName] ON serverconfig.ScopedDatabase
(
	[DatabaseName] ASC
);
CREATE NONCLUSTERED INDEX [IX_ScopedDatabase_KeepingRecordsSynchronized] ON serverconfig.ScopedDatabase
(
	KeepingRecordsSynchronized DESC
);
ALTER TABLE serverconfig.ScopedDatabase ADD  CONSTRAINT [DF_ScopedDatabase_KeepingRecordsSynchronized]  DEFAULT (1) FOR [KeepingRecordsSynchronized]
GO
ALTER TABLE serverconfig.ScopedDatabase ADD  CONSTRAINT [DF_ScopedDatabase_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE serverconfig.ScopedDatabase ADD  CONSTRAINT [DF_ScopedDatabase_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE serverconfig.ScopedDatabase ADD  CONSTRAINT [DF_ScopedDatabase_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE serverconfig.ScopedDatabase ADD  CONSTRAINT [DF_ScopedDatabase_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'serverconfig' 		
, @Table_Name  =  'ScopedDatabase'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 1. (b) vw_ScopedDatabase VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW serverconfig.vw_ScopedDatabase 
AS  
/**************************************************************************************

	Displays ScopedDatabase records. 
	
	The [ID] field is excluded intentionally. 

		
		Example:	
		

			SELECT  TOP 30  X.*
			FROM		serverconfig.vw_ScopedDatabase  X	
			WHERE		X.KeepingRecordsSynchronized = 1 
			ORDER BY	X.[DatabaseName] ASC 
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-06		Created initial version.	

**************************************************************************************/	


	SELECT		X.[DatabaseName] 
	--
	,			X.KeepingRecordsSynchronized 
	,			X.LatestCheckForSynchronizationUpdate 
	,			X.LatestObjectListChangeRecorded 
	,			X.LatestUpdateToObjectRecordDocumentation 
	--
	,			X.LatestSizeUpdateTimestamp 
	,			X.LatestTotalFileSize 
	--
	,			X.PurposeOrMeaning_Description 
	,			X.TechnicalNotes 
	--
	FROM		serverconfig.ScopedDatabase  X  WITH(NOLOCK)  
	--	
	;	
	

GO
--
-- 2. (a) DatabaseSchema TABLE 
--
CREATE TABLE dbocatalogue.DatabaseSchema (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	ScopedDatabaseID int not null, 
	[SchemaName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	LatestObjectListChangeRecorded datetime null, 
	LatestUpdateToObjectRecordDocumentation datetime null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_DatabaseSchema] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_DatabaseSchema] ON dbocatalogue.DatabaseSchema
(
	ScopedDatabaseID ASC,
	[SchemaName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_DatabaseSchema_RecordIsActive] ON dbocatalogue.DatabaseSchema
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.DatabaseSchema  WITH CHECK ADD  CONSTRAINT [FK_CS_DatabaseSchema_ScopedDatabaseID] FOREIGN KEY(ScopedDatabaseID)
REFERENCES serverconfig.ScopedDatabase ([ID])
GO
ALTER TABLE dbocatalogue.DatabaseSchema CHECK CONSTRAINT [FK_CS_DatabaseSchema_ScopedDatabaseID]
GO
ALTER TABLE dbocatalogue.DatabaseSchema ADD  CONSTRAINT [DF_DatabaseSchema_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.DatabaseSchema ADD  CONSTRAINT [DF_DatabaseSchema_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.DatabaseSchema ADD  CONSTRAINT [DF_DatabaseSchema_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.DatabaseSchema ADD  CONSTRAINT [DF_DatabaseSchema_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.DatabaseSchema ADD  CONSTRAINT [DF_DatabaseSchema_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.DatabaseSchema  WITH CHECK ADD  CONSTRAINT [CK_DatabaseSchema_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.DatabaseSchema CHECK CONSTRAINT [CK_DatabaseSchema_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'DatabaseSchema'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 2. (b) vw_DatabaseSchema VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_DatabaseSchema 
AS  
/**************************************************************************************

	Displays DatabaseSchema records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_DatabaseSchema  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			Y.[DatabaseName]	
	,			X.[SchemaName]		
	--
	,			X.LatestObjectListChangeRecorded 
	,			X.LatestUpdateToObjectRecordDocumentation 
	--
	,			X.PurposeOrMeaning_Description  
	,			X.TechnicalNotes 
	--
	FROM		dbocatalogue.DatabaseSchema  X  WITH(NOLOCK)  
	--
	INNER JOIN	serverconfig.ScopedDatabase  Y  WITH(NOLOCK)  ON  X.ScopedDatabaseID = Y.ID 
	--
	WHERE	X.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 3. (a) TupleStructureType TABLE 
--
CREATE TABLE dbocatalogue.TupleStructureType (
	[ID] [int] IDENTITY(1,1) NOT NULL,
	--
	CodeName varchar(10) not null, 
	DisplayName varchar(50) not null, 
	--
	TechnicalNotes varchar(333) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_TupleStructureType] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_TupleStructureType_CodeName] ON dbocatalogue.TupleStructureType
(
	CodeName ASC
);
CREATE UNIQUE NONCLUSTERED INDEX [UIX_TupleStructureType_DisplayName] ON dbocatalogue.TupleStructureType
(
	DisplayName ASC
);
ALTER TABLE dbocatalogue.TupleStructureType ADD  CONSTRAINT [DF_TupleStructureType_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.TupleStructureType ADD  CONSTRAINT [DF_TupleStructureType_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.TupleStructureType ADD  CONSTRAINT [DF_TupleStructureType_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.TupleStructureType ADD  CONSTRAINT [DF_TupleStructureType_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'TupleStructureType'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
INSERT INTO dbocatalogue.TupleStructureType 
(
	CodeName 
,	DisplayName 
) 
VALUES	( 'T'	, 'Table' ) 
,		( 'V'	, 'View' ) 
,		( 'UTT'	, 'User-Defined Table Type' ) 
--
;
GO
--
-- 1. (b) vw_TupleStructureType VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_TupleStructureType 
AS  
/**************************************************************************************

	Displays TupleStructureType records. 

		
		Example:	
		

			SELECT		X.*
			FROM		dbocatalogue.vw_TupleStructureType  X	
			ORDER BY	X.[ID]  ASC 
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			X.CodeName	  
	,			X.DisplayName 
	--
	,			X.TechnicalNotes
	--
	FROM		dbocatalogue.TupleStructureType  X  WITH(NOLOCK)  
	--	
	;	
	

GO
--
-- 4. (a) TupleStructure TABLE 
--
CREATE TABLE dbocatalogue.TupleStructure (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	DatabaseSchemaID bigint not null, 
	[ObjectName] varchar(256) not null, 
	--
	TupleStructureTypeID int not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	Est_CreationTimestamp datetime null, 
	Est_LastModifiedTimestamp datetime null, 
	--
	LatestSizeUpdateTimestamp datetime null, 
	LatestRowCount bigint null,
	LatestTotalSpaceKB float null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_TupleStructure] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_TupleStructure] ON dbocatalogue.TupleStructure
(
	DatabaseSchemaID ASC,
	[ObjectName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_TupleStructure_TupleStructureTypeID] ON dbocatalogue.TupleStructure
(
	TupleStructureTypeID ASC 
);
CREATE NONCLUSTERED INDEX [IX_TupleStructure_RecordIsActive] ON dbocatalogue.TupleStructure
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.TupleStructure  WITH CHECK ADD  CONSTRAINT [FK_TupleStructure_DatabaseSchemaID] FOREIGN KEY(DatabaseSchemaID)
REFERENCES dbocatalogue.DatabaseSchema ([ID])
GO
ALTER TABLE dbocatalogue.TupleStructure CHECK CONSTRAINT [FK_TupleStructure_DatabaseSchemaID]
GO
ALTER TABLE dbocatalogue.TupleStructure  WITH CHECK ADD  CONSTRAINT [FK_TupleStructure_TupleStructureTypeID] FOREIGN KEY(TupleStructureTypeID)
REFERENCES dbocatalogue.TupleStructureType ([ID])
GO
ALTER TABLE dbocatalogue.TupleStructure CHECK CONSTRAINT [FK_TupleStructure_TupleStructureTypeID]
GO
ALTER TABLE dbocatalogue.TupleStructure ADD  CONSTRAINT [DF_TupleStructure_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.TupleStructure ADD  CONSTRAINT [DF_TupleStructure_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.TupleStructure ADD  CONSTRAINT [DF_TupleStructure_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.TupleStructure ADD  CONSTRAINT [DF_TupleStructure_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.TupleStructure ADD  CONSTRAINT [DF_TupleStructure_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.TupleStructure  WITH CHECK ADD  CONSTRAINT [CK_TupleStructure_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.TupleStructure CHECK CONSTRAINT [CK_TupleStructure_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'TupleStructure'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 4. (b) vw_TupleStructure VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_TupleStructure 
AS  
/**************************************************************************************

	Displays TupleStructure records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_TupleStructure  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			X.DatabaseSchemaID 
	,			Z.DatabaseName 
	,			Y.SchemaName
	,			X.ObjectName 
	--
	,			X.TupleStructureTypeID 
	,			T.CodeName					as	TupleStructureType_CodeName 
	,			T.DisplayName				as	TupleStructureType_DisplayName  
	--
	,			X.Est_CreationTimestamp 
	,			X.Est_LastModifiedTimestamp 
	--
	,			X.LatestSizeUpdateTimestamp		
	,			X.LatestRowCount				
	,			X.LatestTotalSpaceKB			
	--
	,			X.PurposeOrMeaning_Description  
	,			X.TechnicalNotes 
	--
	FROM		dbocatalogue.TupleStructure  X  WITH(NOLOCK)  
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	INNER JOIN	dbocatalogue.TupleStructureType  T  WITH(NOLOCK)  ON  X.TupleStructureTypeID = T.ID 
	--
	WHERE	X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 5. (a) TupleStructureColumn TABLE 
--
CREATE TABLE dbocatalogue.TupleStructureColumn (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	TupleStructureID bigint not null, 
	[ColumnName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	OrdinalNumber int not null, 
	DataType_Name varchar(20) null,
	DataType_MaxLength int null, 
	DataType_Precision int null,
	DataType_Scale int null, 
	IsNullable bit null,
	IsIdentity bit null,
	HasDefaultValue bit null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_TupleStructureColumn] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_TupleStructureColumn] ON dbocatalogue.TupleStructureColumn
(
	TupleStructureID ASC,
	[ColumnName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_TupleStructureColumn_OrdinalNumber] ON dbocatalogue.TupleStructureColumn
(
	OrdinalNumber DESC 
);
CREATE NONCLUSTERED INDEX [IX_TupleStructureColumn_RecordIsActive] ON dbocatalogue.TupleStructureColumn
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.TupleStructureColumn  WITH CHECK ADD  CONSTRAINT [FK_TupleStructureColumn_TupleStructureID] FOREIGN KEY(TupleStructureID)
REFERENCES dbocatalogue.TupleStructure ([ID])
GO
ALTER TABLE dbocatalogue.TupleStructureColumn CHECK CONSTRAINT [FK_TupleStructureColumn_TupleStructureID]
GO
ALTER TABLE dbocatalogue.TupleStructureColumn ADD  CONSTRAINT [DF_TupleStructureColumn_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.TupleStructureColumn ADD  CONSTRAINT [DF_TupleStructureColumn_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.TupleStructureColumn ADD  CONSTRAINT [DF_TupleStructureColumn_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.TupleStructureColumn ADD  CONSTRAINT [DF_TupleStructureColumn_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.TupleStructureColumn ADD  CONSTRAINT [DF_TupleStructureColumn_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.TupleStructureColumn  WITH CHECK ADD  CONSTRAINT [CK_TupleStructureColumn_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.TupleStructureColumn CHECK CONSTRAINT [CK_TupleStructureColumn_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'TupleStructureColumn'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 5. (b) vw_TupleStructureColumn VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_TupleStructureColumn 
AS  
/**************************************************************************************

	Displays TupleStructureColumn records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_TupleStructureColumn  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		C.[ID] 
	--	
	,			C.TupleStructureID
	,			Z.[DatabaseName] 
	,			Y.[SchemaName]
	,			X.[ObjectName] 
	--
	,			T.CodeName			as	TupleStructureType_CodeName 
	,			T.DisplayName		as	TupleStructureType_DisplayName  
	--
	,			C.[ColumnName] 
	--
	,			C.OrdinalNumber  
	,			C.DataType_Name  
	,			C.DataType_MaxLength 
	,			C.DataType_Precision 
	,			C.DataType_Scale  
	,			C.IsNullable   
	,			C.IsIdentity   
	,			C.HasDefaultValue 
	--
	,			C.PurposeOrMeaning_Description  
	,			C.TechnicalNotes  
	--
	FROM		dbocatalogue.TupleStructureColumn  C  WITH(NOLOCK)  
	--
	INNER JOIN  dbocatalogue.TupleStructure  X  WITH(NOLOCK)  ON  C.TupleStructureID = X.ID 
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	INNER JOIN	dbocatalogue.TupleStructureType  T  WITH(NOLOCK)  ON  X.TupleStructureTypeID = T.ID 
	--
	WHERE	C.RecordIsActive = 1 
	-- 
	AND		X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 6. (a) ScalarValuedFunction TABLE 
--
CREATE TABLE dbocatalogue.ScalarValuedFunction (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	DatabaseSchemaID bigint not null, 
	[ObjectName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	ReturnValue_DataType_Name varchar(20) null,
	ReturnValue_DataType_MaxLength int null, 
	ReturnValue_DataType_Precision int null,
	ReturnValue_DataType_Scale int null, 
	--
	Est_CreationTimestamp datetime null, 
	Est_LastModifiedTimestamp datetime null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_ScalarValuedFunction] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_ScalarValuedFunction] ON dbocatalogue.ScalarValuedFunction
(
	DatabaseSchemaID ASC,
	[ObjectName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_ScalarValuedFunction_RecordIsActive] ON dbocatalogue.ScalarValuedFunction
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.ScalarValuedFunction  WITH CHECK ADD  CONSTRAINT [FK_ScalarValuedFunction_DatabaseSchemaID] FOREIGN KEY(DatabaseSchemaID)
REFERENCES dbocatalogue.DatabaseSchema ([ID])
GO
ALTER TABLE dbocatalogue.ScalarValuedFunction CHECK CONSTRAINT [FK_ScalarValuedFunction_DatabaseSchemaID]
GO
ALTER TABLE dbocatalogue.ScalarValuedFunction ADD  CONSTRAINT [DF_ScalarValuedFunction_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.ScalarValuedFunction ADD  CONSTRAINT [DF_ScalarValuedFunction_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.ScalarValuedFunction ADD  CONSTRAINT [DF_ScalarValuedFunction_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.ScalarValuedFunction ADD  CONSTRAINT [DF_ScalarValuedFunction_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.ScalarValuedFunction ADD  CONSTRAINT [DF_ScalarValuedFunction_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.ScalarValuedFunction  WITH CHECK ADD  CONSTRAINT [CK_ScalarValuedFunction_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.ScalarValuedFunction CHECK CONSTRAINT [CK_ScalarValuedFunction_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'ScalarValuedFunction'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 6. (b) vw_ScalarValuedFunction VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_ScalarValuedFunction 
AS  
/**************************************************************************************

	Displays ScalarValuedFunction records. 

		
		Example:	
		

			SELECT  TOP 99  X.*
			FROM		dbocatalogue.vw_ScalarValuedFunction  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			X.DatabaseSchemaID 
	,			Z.DatabaseName 
	,			Y.SchemaName
	,			X.ObjectName 
	--
	,			X.ReturnValue_DataType_Name			
	,			X.ReturnValue_DataType_MaxLength	
	,			X.ReturnValue_DataType_Precision	
	,			X.ReturnValue_DataType_Scale		
	--
	,			X.Est_CreationTimestamp 
	,			X.Est_LastModifiedTimestamp 
	--
	,			X.PurposeOrMeaning_Description  
	,			X.TechnicalNotes 
	--
	FROM		dbocatalogue.ScalarValuedFunction  X  WITH(NOLOCK)  
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 7. (a) ScalarValuedFunctionParameter TABLE 
--
CREATE TABLE dbocatalogue.ScalarValuedFunctionParameter (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	ScalarValuedFunctionID bigint not null, 
	[ParameterName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	OrdinalNumber int not null, 
	DataType_Name varchar(20) null,
	DataType_MaxLength int null, 
	DataType_Precision int null,
	DataType_Scale int null, 
	HasDefaultValue bit null, 
	IsOutput bit null,
	IsReadOnly bit null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_ScalarValuedFunctionParameter] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_ScalarValuedFunctionParameter] ON dbocatalogue.ScalarValuedFunctionParameter
(
	ScalarValuedFunctionID ASC,
	[ParameterName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_ScalarValuedFunctionParameter_OrdinalNumber] ON dbocatalogue.ScalarValuedFunctionParameter
(
	OrdinalNumber DESC 
);
CREATE NONCLUSTERED INDEX [IX_ScalarValuedFunctionParameter_RecordIsActive] ON dbocatalogue.ScalarValuedFunctionParameter
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter  WITH CHECK ADD  CONSTRAINT [FK_ScalarValuedFunctionParameter_ScalarValuedFunctionID] FOREIGN KEY(ScalarValuedFunctionID)
REFERENCES dbocatalogue.ScalarValuedFunction ([ID])
GO
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter CHECK CONSTRAINT [FK_ScalarValuedFunctionParameter_ScalarValuedFunctionID]
GO
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter ADD  CONSTRAINT [DF_ScalarValuedFunctionParameter_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter ADD  CONSTRAINT [DF_ScalarValuedFunctionParameter_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter ADD  CONSTRAINT [DF_ScalarValuedFunctionParameter_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter ADD  CONSTRAINT [DF_ScalarValuedFunctionParameter_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter ADD  CONSTRAINT [DF_ScalarValuedFunctionParameter_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter  WITH CHECK ADD  CONSTRAINT [CK_ScalarValuedFunctionParameter_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.ScalarValuedFunctionParameter CHECK CONSTRAINT [CK_ScalarValuedFunctionParameter_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'ScalarValuedFunctionParameter'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 7. (b) vw_ScalarValuedFunctionParameter VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_ScalarValuedFunctionParameter 
AS  
/**************************************************************************************

	Displays ScalarValuedFunctionParameter records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_ScalarValuedFunctionParameter  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		P.[ID] 
	--	
	,			P.ScalarValuedFunctionID
	,			Z.[DatabaseName] 
	,			Y.[SchemaName]
	,			X.[ObjectName] 
	--
	,			P.[ParameterName] 
	--
	,			P.OrdinalNumber  
	,			P.DataType_Name  
	,			P.DataType_MaxLength 
	,			P.DataType_Precision 
	,			P.DataType_Scale  
	,			P.HasDefaultValue 
	,			P.IsOutput   
	,			P.IsReadOnly 
	--
	,			P.PurposeOrMeaning_Description  
	,			P.TechnicalNotes  
	--
	FROM		dbocatalogue.ScalarValuedFunctionParameter  P  WITH(NOLOCK)  
	--
	INNER JOIN  dbocatalogue.ScalarValuedFunction  X  WITH(NOLOCK)  ON  P.ScalarValuedFunctionID = X.ID 
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	P.RecordIsActive = 1 
	-- 
	AND		X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 8. (a) TableValuedFunction TABLE 
--
CREATE TABLE dbocatalogue.TableValuedFunction (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	DatabaseSchemaID bigint not null, 
	[ObjectName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	Est_CreationTimestamp datetime null, 
	Est_LastModifiedTimestamp datetime null, 
	--
	IsInline bit not null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_TableValuedFunction] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_TableValuedFunction] ON dbocatalogue.TableValuedFunction
(
	DatabaseSchemaID ASC,
	[ObjectName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_TableValuedFunction_RecordIsActive] ON dbocatalogue.TableValuedFunction
(
	RecordIsActive DESC 
);
CREATE NONCLUSTERED INDEX [IX_TableValuedFunction_IsInline] ON dbocatalogue.TableValuedFunction
(
	IsInline DESC 
);
ALTER TABLE dbocatalogue.TableValuedFunction  WITH CHECK ADD  CONSTRAINT [FK_TableValuedFunction_DatabaseSchemaID] FOREIGN KEY(DatabaseSchemaID)
REFERENCES dbocatalogue.DatabaseSchema ([ID])
GO
ALTER TABLE dbocatalogue.TableValuedFunction CHECK CONSTRAINT [FK_TableValuedFunction_DatabaseSchemaID]
GO
ALTER TABLE dbocatalogue.TableValuedFunction ADD  CONSTRAINT [DF_TableValuedFunction_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.TableValuedFunction ADD  CONSTRAINT [DF_TableValuedFunction_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.TableValuedFunction ADD  CONSTRAINT [DF_TableValuedFunction_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.TableValuedFunction ADD  CONSTRAINT [DF_TableValuedFunction_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.TableValuedFunction ADD  CONSTRAINT [DF_TableValuedFunction_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.TableValuedFunction  WITH CHECK ADD  CONSTRAINT [CK_TableValuedFunction_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.TableValuedFunction CHECK CONSTRAINT [CK_TableValuedFunction_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'TableValuedFunction'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 8. (b) vw_TableValuedFunction VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_TableValuedFunction 
AS  
/**************************************************************************************

	Displays TableValuedFunction records. 

		
		Example:	
		

			SELECT  TOP 99  X.*
			FROM		dbocatalogue.vw_TableValuedFunction  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			X.DatabaseSchemaID 
	,			Z.DatabaseName 
	,			Y.SchemaName
	,			X.ObjectName 
	--
	,			X.Est_CreationTimestamp 
	,			X.Est_LastModifiedTimestamp 
	--
	,			X.IsInline 
	--
	,			X.PurposeOrMeaning_Description  
	,			X.TechnicalNotes 
	--
	FROM		dbocatalogue.TableValuedFunction  X  WITH(NOLOCK)  
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 9. (a) TableValuedFunctionParameter TABLE 
--
CREATE TABLE dbocatalogue.TableValuedFunctionParameter (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	TableValuedFunctionID bigint not null, 
	[ParameterName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	OrdinalNumber int not null, 
	DataType_Name varchar(20) null,
	DataType_MaxLength int null, 
	DataType_Precision int null,
	DataType_Scale int null, 
	HasDefaultValue bit null, 
	IsOutput bit null,
	IsReadOnly bit null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_TableValuedFunctionParameter] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_TableValuedFunctionParameter] ON dbocatalogue.TableValuedFunctionParameter
(
	TableValuedFunctionID ASC,
	[ParameterName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_TableValuedFunctionParameter_OrdinalNumber] ON dbocatalogue.TableValuedFunctionParameter
(
	OrdinalNumber DESC 
);
CREATE NONCLUSTERED INDEX [IX_TableValuedFunctionParameter_RecordIsActive] ON dbocatalogue.TableValuedFunctionParameter
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.TableValuedFunctionParameter  WITH CHECK ADD  CONSTRAINT [FK_TableValuedFunctionParameter_TableValuedFunctionID] FOREIGN KEY(TableValuedFunctionID)
REFERENCES dbocatalogue.TableValuedFunction ([ID])
GO
ALTER TABLE dbocatalogue.TableValuedFunctionParameter CHECK CONSTRAINT [FK_TableValuedFunctionParameter_TableValuedFunctionID]
GO
ALTER TABLE dbocatalogue.TableValuedFunctionParameter ADD  CONSTRAINT [DF_TableValuedFunctionParameter_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.TableValuedFunctionParameter ADD  CONSTRAINT [DF_TableValuedFunctionParameter_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.TableValuedFunctionParameter ADD  CONSTRAINT [DF_TableValuedFunctionParameter_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.TableValuedFunctionParameter ADD  CONSTRAINT [DF_TableValuedFunctionParameter_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.TableValuedFunctionParameter ADD  CONSTRAINT [DF_TableValuedFunctionParameter_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.TableValuedFunctionParameter  WITH CHECK ADD  CONSTRAINT [CK_TableValuedFunctionParameter_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.TableValuedFunctionParameter CHECK CONSTRAINT [CK_TableValuedFunctionParameter_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'TableValuedFunctionParameter'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 9. (b) vw_TableValuedFunctionParameter VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_TableValuedFunctionParameter 
AS  
/**************************************************************************************

	Displays TableValuedFunctionParameter records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_TableValuedFunctionParameter  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		P.[ID] 
	--	
	,			P.TableValuedFunctionID
	,			Z.[DatabaseName] 
	,			Y.[SchemaName]
	,			X.[ObjectName] 
	--
	,			P.[ParameterName] 
	--
	,			P.OrdinalNumber  
	,			P.DataType_Name  
	,			P.DataType_MaxLength 
	,			P.DataType_Precision 
	,			P.DataType_Scale  
	,			P.HasDefaultValue 
	,			P.IsOutput   
	,			P.IsReadOnly 
	--
	,			P.PurposeOrMeaning_Description  
	,			P.TechnicalNotes  
	--
	FROM		dbocatalogue.TableValuedFunctionParameter  P  WITH(NOLOCK)  
	--
	INNER JOIN  dbocatalogue.TableValuedFunction  X  WITH(NOLOCK)  ON  P.TableValuedFunctionID = X.ID 
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	P.RecordIsActive = 1 
	-- 
	AND		X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 10. (a) TableValuedFunctionColumn TABLE 
--
CREATE TABLE dbocatalogue.TableValuedFunctionColumn (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	TableValuedFunctionID bigint not null, 
	[ColumnName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	OrdinalNumber int not null, 
	DataType_Name varchar(20) null,
	DataType_MaxLength int null, 
	DataType_Precision int null,
	DataType_Scale int null, 
	IsNullable bit null,
	IsIdentity bit null,
	HasDefaultValue bit null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_TableValuedFunctionColumn] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_TableValuedFunctionColumn] ON dbocatalogue.TableValuedFunctionColumn
(
	TableValuedFunctionID ASC,
	[ColumnName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_TableValuedFunctionColumn_OrdinalNumber] ON dbocatalogue.TableValuedFunctionColumn
(
	OrdinalNumber DESC 
);
CREATE NONCLUSTERED INDEX [IX_TableValuedFunctionColumn_RecordIsActive] ON dbocatalogue.TableValuedFunctionColumn
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.TableValuedFunctionColumn  WITH CHECK ADD  CONSTRAINT [FK_TableValuedFunctionColumn_TableValuedFunctionID] FOREIGN KEY(TableValuedFunctionID)
REFERENCES dbocatalogue.TableValuedFunction ([ID])
GO
ALTER TABLE dbocatalogue.TableValuedFunctionColumn CHECK CONSTRAINT [FK_TableValuedFunctionColumn_TableValuedFunctionID]
GO
ALTER TABLE dbocatalogue.TableValuedFunctionColumn ADD  CONSTRAINT [DF_TableValuedFunctionColumn_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.TableValuedFunctionColumn ADD  CONSTRAINT [DF_TableValuedFunctionColumn_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.TableValuedFunctionColumn ADD  CONSTRAINT [DF_TableValuedFunctionColumn_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.TableValuedFunctionColumn ADD  CONSTRAINT [DF_TableValuedFunctionColumn_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.TableValuedFunctionColumn ADD  CONSTRAINT [DF_TableValuedFunctionColumn_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.TableValuedFunctionColumn  WITH CHECK ADD  CONSTRAINT [CK_TableValuedFunctionColumn_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.TableValuedFunctionColumn CHECK CONSTRAINT [CK_TableValuedFunctionColumn_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'TableValuedFunctionColumn'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 10. (b) vw_TableValuedFunctionColumn VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_TableValuedFunctionColumn 
AS  
/**************************************************************************************

	Displays TableValuedFunctionColumn records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_TableValuedFunctionColumn  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		C.[ID] 
	--	
	,			C.TableValuedFunctionID
	,			Z.[DatabaseName] 
	,			Y.[SchemaName]
	,			X.[ObjectName] 
	--
	,			C.[ColumnName] 
	--
	,			C.OrdinalNumber  
	,			C.DataType_Name  
	,			C.DataType_MaxLength 
	,			C.DataType_Precision 
	,			C.DataType_Scale  
	,			C.IsNullable   
	,			C.IsIdentity   
	,			C.HasDefaultValue 
	--
	,			C.PurposeOrMeaning_Description  
	,			C.TechnicalNotes  
	--
	FROM		dbocatalogue.TableValuedFunctionColumn  C  WITH(NOLOCK)  
	--
	INNER JOIN  dbocatalogue.TableValuedFunction  X  WITH(NOLOCK)  ON  C.TableValuedFunctionID = X.ID 
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	C.RecordIsActive = 1 
	-- 
	AND		X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 11. (a) StoredProcedure TABLE 
--
CREATE TABLE dbocatalogue.StoredProcedure (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	DatabaseSchemaID bigint not null, 
	[ObjectName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	Est_CreationTimestamp datetime null, 
	Est_LastModifiedTimestamp datetime null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_StoredProcedure] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_StoredProcedure] ON dbocatalogue.StoredProcedure
(
	DatabaseSchemaID ASC,
	[ObjectName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_StoredProcedure_RecordIsActive] ON dbocatalogue.StoredProcedure
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.StoredProcedure  WITH CHECK ADD  CONSTRAINT [FK_StoredProcedure_DatabaseSchemaID] FOREIGN KEY(DatabaseSchemaID)
REFERENCES dbocatalogue.DatabaseSchema ([ID])
GO
ALTER TABLE dbocatalogue.StoredProcedure CHECK CONSTRAINT [FK_StoredProcedure_DatabaseSchemaID]
GO
ALTER TABLE dbocatalogue.StoredProcedure ADD  CONSTRAINT [DF_StoredProcedure_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.StoredProcedure ADD  CONSTRAINT [DF_StoredProcedure_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.StoredProcedure ADD  CONSTRAINT [DF_StoredProcedure_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.StoredProcedure ADD  CONSTRAINT [DF_StoredProcedure_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.StoredProcedure ADD  CONSTRAINT [DF_StoredProcedure_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.StoredProcedure  WITH CHECK ADD  CONSTRAINT [CK_StoredProcedure_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.StoredProcedure CHECK CONSTRAINT [CK_StoredProcedure_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'StoredProcedure'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 11. (b) vw_StoredProcedure VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_StoredProcedure 
AS  
/**************************************************************************************

	Displays StoredProcedure records. 

		
		Example:	
		

			SELECT  TOP 333  X.*
			FROM		dbocatalogue.vw_StoredProcedure  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			X.DatabaseSchemaID 
	,			Z.DatabaseName 
	,			Y.SchemaName
	,			X.ObjectName 
	--
	,			X.Est_CreationTimestamp 
	,			X.Est_LastModifiedTimestamp 
	--
	,			X.PurposeOrMeaning_Description  
	,			X.TechnicalNotes 
	--
	FROM		dbocatalogue.StoredProcedure  X  WITH(NOLOCK)  
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 12. (a) StoredProcedureParameter TABLE 
--
CREATE TABLE dbocatalogue.StoredProcedureParameter (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	StoredProcedureID bigint not null, 
	[ParameterName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	OrdinalNumber int not null, 
	DataType_Name varchar(20) null,
	DataType_MaxLength int null, 
	DataType_Precision int null,
	DataType_Scale int null, 
	HasDefaultValue bit null, 
	IsOutput bit null,
	IsReadOnly bit null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_StoredProcedureParameter] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_StoredProcedureParameter] ON dbocatalogue.StoredProcedureParameter
(
	StoredProcedureID ASC,
	[ParameterName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_StoredProcedureParameter_OrdinalNumber] ON dbocatalogue.StoredProcedureParameter
(
	OrdinalNumber DESC 
);
CREATE NONCLUSTERED INDEX [IX_StoredProcedureParameter_RecordIsActive] ON dbocatalogue.StoredProcedureParameter
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.StoredProcedureParameter  WITH CHECK ADD  CONSTRAINT [FK_StoredProcedureParameter_StoredProcedureID] FOREIGN KEY(StoredProcedureID)
REFERENCES dbocatalogue.StoredProcedure ([ID])
GO
ALTER TABLE dbocatalogue.StoredProcedureParameter CHECK CONSTRAINT [FK_StoredProcedureParameter_StoredProcedureID]
GO
ALTER TABLE dbocatalogue.StoredProcedureParameter ADD  CONSTRAINT [DF_StoredProcedureParameter_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.StoredProcedureParameter ADD  CONSTRAINT [DF_StoredProcedureParameter_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.StoredProcedureParameter ADD  CONSTRAINT [DF_StoredProcedureParameter_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.StoredProcedureParameter ADD  CONSTRAINT [DF_StoredProcedureParameter_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.StoredProcedureParameter ADD  CONSTRAINT [DF_StoredProcedureParameter_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.StoredProcedureParameter  WITH CHECK ADD  CONSTRAINT [CK_StoredProcedureParameter_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.StoredProcedureParameter CHECK CONSTRAINT [CK_StoredProcedureParameter_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'StoredProcedureParameter'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 12. (b) vw_StoredProcedureParameter VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_StoredProcedureParameter 
AS  
/**************************************************************************************

	Displays StoredProcedureParameter records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_StoredProcedureParameter  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		P.[ID] 
	--	
	,			P.StoredProcedureID
	,			Z.[DatabaseName] 
	,			Y.[SchemaName]
	,			X.[ObjectName] 
	--
	,			P.[ParameterName] 
	--
	,			P.OrdinalNumber  
	,			P.DataType_Name  
	,			P.DataType_MaxLength 
	,			P.DataType_Precision 
	,			P.DataType_Scale  
	,			P.HasDefaultValue 
	,			P.IsOutput   
	,			P.IsReadOnly 
	--
	,			P.PurposeOrMeaning_Description  
	,			P.TechnicalNotes  
	--
	FROM		dbocatalogue.StoredProcedureParameter  P  WITH(NOLOCK)  
	--
	INNER JOIN  dbocatalogue.StoredProcedure  X  WITH(NOLOCK)  ON  P.StoredProcedureID = X.ID 
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	P.RecordIsActive = 1 
	-- 
	AND		X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 13. (a) SynonymAlias TABLE 
--
CREATE TABLE dbocatalogue.SynonymAlias (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	DatabaseSchemaID bigint not null, 
	[ObjectName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	Target_ServerName varchar(256) null, 
	Target_DatabaseName varchar(256) null,
	Target_SchemaName varchar(256) null, 
	Target_ObjectName varchar(256) null, 
	--
	Est_CreationTimestamp datetime null, 
	Est_LastModifiedTimestamp datetime null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_SynonymAlias] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_SynonymAlias] ON dbocatalogue.SynonymAlias
(
	DatabaseSchemaID ASC,
	[ObjectName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_SynonymAlias_RecordIsActive] ON dbocatalogue.SynonymAlias
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.SynonymAlias  WITH CHECK ADD  CONSTRAINT [FK_SynonymAlias_DatabaseSchemaID] FOREIGN KEY(DatabaseSchemaID)
REFERENCES dbocatalogue.DatabaseSchema ([ID])
GO
ALTER TABLE dbocatalogue.SynonymAlias CHECK CONSTRAINT [FK_SynonymAlias_DatabaseSchemaID]
GO
ALTER TABLE dbocatalogue.SynonymAlias ADD  CONSTRAINT [DF_SynonymAlias_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.SynonymAlias ADD  CONSTRAINT [DF_SynonymAlias_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.SynonymAlias ADD  CONSTRAINT [DF_SynonymAlias_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.SynonymAlias ADD  CONSTRAINT [DF_SynonymAlias_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.SynonymAlias ADD  CONSTRAINT [DF_SynonymAlias_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.SynonymAlias  WITH CHECK ADD  CONSTRAINT [CK_SynonymAlias_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.SynonymAlias CHECK CONSTRAINT [CK_SynonymAlias_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'SynonymAlias'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 13. (b) vw_SynonymAlias VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_SynonymAlias 
AS  
/**************************************************************************************

	Displays SynonymAlias records. 

		
		Example:	
		

			SELECT  TOP 333  X.*
			FROM		dbocatalogue.vw_SynonymAlias  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			X.DatabaseSchemaID 
	,			Z.DatabaseName 
	,			Y.SchemaName
	,			X.ObjectName 
	--
	,			X.Target_ServerName 
	,			X.Target_DatabaseName 
	,			X.Target_SchemaName 
	,			X.Target_ObjectName 
	-- 
	,			X.Est_CreationTimestamp 
	,			X.Est_LastModifiedTimestamp 
	--
	,			X.PurposeOrMeaning_Description  
	,			X.TechnicalNotes 
	--
	FROM		dbocatalogue.SynonymAlias  X  WITH(NOLOCK)  
	--
	INNER JOIN	dbocatalogue.DatabaseSchema  Y  WITH(NOLOCK)  ON  X.DatabaseSchemaID = Y.ID 
	INNER JOIN	serverconfig.ScopedDatabase  Z  WITH(NOLOCK)  ON  Y.ScopedDatabaseID = Z.ID 
	--
	WHERE	X.RecordIsActive = 1 
	AND     Y.RecordIsActive = 1 
	--
	;	
	

GO
--
-- 14. (a) DatabaseRole TABLE 
--
CREATE TABLE dbocatalogue.DatabaseRole (
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	--
	ScopedDatabaseID int not null, 
	[RoleName] varchar(256) not null, 
	--
	RecordIsActive bit not null, 
	RecordDeactivationTimestamp datetime null, 
	--
	Est_CreationTimestamp datetime null, 
	Est_LastModifiedTimestamp datetime null, 
	--
	PurposeOrMeaning_Description varchar(1080) null, 
	TechnicalNotes varchar(1080) null, 
	--
	[InsertTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NOT NULL,
	[InsertBy] [nvarchar](256) NOT NULL,
	[UpdateBy] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_DatabaseRole] PRIMARY KEY CLUSTERED 
(
	[ID] ASC 
)); 
CREATE UNIQUE NONCLUSTERED INDEX [UIX_DatabaseRole] ON dbocatalogue.DatabaseRole
(
	ScopedDatabaseID ASC,
	[RoleName] ASC
); 
CREATE NONCLUSTERED INDEX [IX_DatabaseRole_RecordIsActive] ON dbocatalogue.DatabaseRole
(
	RecordIsActive DESC 
);
ALTER TABLE dbocatalogue.DatabaseRole  WITH CHECK ADD  CONSTRAINT [FK_CS_DatabaseRole_ScopedDatabaseID] FOREIGN KEY(ScopedDatabaseID)
REFERENCES serverconfig.ScopedDatabase ([ID])
GO
ALTER TABLE dbocatalogue.DatabaseRole CHECK CONSTRAINT [FK_CS_DatabaseRole_ScopedDatabaseID]
GO
ALTER TABLE dbocatalogue.DatabaseRole ADD  CONSTRAINT [DF_DatabaseRole_RecordIsActive]  DEFAULT (1) FOR [RecordIsActive]
GO
ALTER TABLE dbocatalogue.DatabaseRole ADD  CONSTRAINT [DF_DatabaseRole_InsertTime]  DEFAULT (getdate()) FOR [InsertTime]
ALTER TABLE dbocatalogue.DatabaseRole ADD  CONSTRAINT [DF_DatabaseRole_InsertBy]  DEFAULT (suser_sname()) FOR [InsertBy]
ALTER TABLE dbocatalogue.DatabaseRole ADD  CONSTRAINT [DF_DatabaseRole_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
ALTER TABLE dbocatalogue.DatabaseRole ADD  CONSTRAINT [DF_DatabaseRole_UpdateBy]  DEFAULT (suser_sname()) FOR [UpdateBy]
GO
ALTER TABLE dbocatalogue.DatabaseRole  WITH CHECK ADD  CONSTRAINT [CK_DatabaseRole_RecordIsActive_And_RecordDeactivationTimestamp] 
 CHECK  (( RecordIsActive = 1 ) OR ( RecordDeactivationTimestamp IS NOT NULL ))
GO
ALTER TABLE dbocatalogue.DatabaseRole CHECK CONSTRAINT [CK_DatabaseRole_RecordIsActive_And_RecordDeactivationTimestamp]
GO
EXEC  utility.usp_Create_HistoryTable 
  @Schema_Name  =  'dbocatalogue' 		
, @Table_Name  =  'DatabaseRole'	
--
, @IncludeContextInfoChecks  =  0	
--	
, @Mode  =  'RUN' 
--
, @DEBUG  =  1 
--
;
GO
--
-- 14. (b) vw_DatabaseRole VIEW 
-- 
USE [a_METADATA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbocatalogue.vw_DatabaseRole 
AS  
/**************************************************************************************

	Displays DatabaseRole records. 

		
		Example:	
		

			SELECT  TOP 777  X.*
			FROM		dbocatalogue.vw_DatabaseRole  X	
			ORDER BY	X.[ID]  DESC  
			;	

			
	Date			Action	
	----------		----------------------------
	2020-09-07		Created initial version.	

**************************************************************************************/	


	SELECT		X.[ID] 
	--	
	,			Y.[DatabaseName]	
	,			X.[RoleName]		
	--
	,			X.Est_CreationTimestamp 
	,			X.Est_LastModifiedTimestamp 
	--
	,			X.PurposeOrMeaning_Description  
	,			X.TechnicalNotes 
	--
	FROM		dbocatalogue.DatabaseRole  X  WITH(NOLOCK)  
	--
	INNER JOIN	serverconfig.ScopedDatabase  Y  WITH(NOLOCK)  ON  X.ScopedDatabaseID = Y.ID 
	--
	WHERE	X.RecordIsActive = 1 
	--
	;	
	

GO	
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
-- END FILE :: a001_TablesAndViews.sql 
--