--
-- BEGIN FILE :: a005_dbocatalogue_fcn_ConsolidatedInventory.sql 
--
USE [a_METADATA] 
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbocatalogue].[fcn_ConsolidatedInventory]
(
	@DatabaseName  varchar(256)  
)
RETURNS TABLE 
AS 
/**************************************************************************************

	Returns a combined list of records from all [dbocatalogue] tables, 
	 
	 for a particular database if a value is provided for the parameter @DatabaseName, 
	 
	  otherwise for all available databases (when @DatabaseName is NULL). 

	
		Example:	


			SELECT	X.* 
			--
			FROM  dbocatalogue.fcn_ConsolidatedInventory ( null )  X  
			--
			WHERE  X.DatabaseName = 'a_METADATA' 
			--
			ORDER BY  X.ScopedDatabaseID  ASC 
			,		  X.RecordTypeRank    ASC 
			,		  X.RecordID          ASC 
			--
			; 
			

	Date			Action	
	----------		----------------------------
	2020-09-27		Created initial version.	
	
**************************************************************************************/	
RETURN	
(   --
	--
	SELECT	SD.LatestCheckForSynchronizationUpdate  as  InventoryTimestamp  
	--
	,		X.ScopedDatabaseID  
	--
	,		X.RecordTypeRank 
	,		X.RecordType 
	,		X.RecordID 
	--
	,		SD.DatabaseName  as  DatabaseName 
	,		X.RoleName 
	,		X.SchemaName 
	,		X.ObjectName 
	,		X.OrdinalNumber  as  ChildItemNumber 
	,		X.ParameterName 
	,		X.ColumnName 
	--
	,		X.PurposeOrMeaning_Description 
	,		X.TechnicalNotes 
	--
	FROM	(
				SELECT	Xs.ID		as  ScopedDatabaseID  
				--
				,		1					   as  RecordTypeRank 
				,		'ScopedDatabase'	   as  RecordType -- 0  
				,		convert(bigint,Xs.ID)  as  RecordID 
				-- 
				,		convert(varchar(256),null)  as  RoleName 
				,		convert(varchar(256),null)  as  SchemaName 
				,		convert(varchar(256),null)  as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase  Xs 
				WHERE   Xs.DatabaseName = @DatabaseName 
				OR		@DatabaseName IS NULL 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		2				as	RecordTypeRank 
				,		'DatabaseRole'	as  RecordType -- 1a  
				,		Xs.ID			as  RecordID 
				-- 
				,		Xs.RoleName					as  RoleName 
				,		convert(varchar(256),null)	as  SchemaName 
				,		convert(varchar(256),null)  as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	   SDs 
				INNER JOIN	dbocatalogue.DatabaseRole  Xs  ON  SDs.ID = Xs.ScopedDatabaseID 
														   AND ( SDs.DatabaseName = @DatabaseName 
															   OR @DatabaseName IS NULL ) 
				WHERE	Xs.RecordIsActive = 1 

				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		3				  as  RecordTypeRank 
				,		'DatabaseSchema'  as  RecordType -- 1b  
				,		Xs.ID			  as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Xs.SchemaName				as  SchemaName 
				,		convert(varchar(256),null)  as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Xs  ON  SDs.ID = Xs.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		4				  as  RecordTypeRank 
				,		'TupleStructure'  as  RecordType -- 2a  
				,		Xs.ID			  as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		Xs.ObjectName				as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.TupleStructure  Xs  ON  Ss.ID = Xs.DatabaseSchemaID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		5					    as  RecordTypeRank 
				,		'TupleStructureColumn'  as  RecordType -- 2b  
				,		Xs.ID					as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		TSs.ObjectName				as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		Xs.ColumnName				as  ColumnName
				--
				,		Xs.OrdinalNumber			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.TupleStructure  TSs  ON  Ss.ID = TSs.DatabaseSchemaID 
															  AND TSs.RecordIsActive = 1 
															  --
				INNER JOIN	dbocatalogue.TupleStructureColumn  Xs  ON  TSs.ID = Xs.TupleStructureID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		6						as  RecordTypeRank 
				,		'ScalarValuedFunction'  as  RecordType -- 3a  
				,		Xs.ID					as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		Xs.ObjectName				as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.ScalarValuedFunction  Xs  ON  Ss.ID = Xs.DatabaseSchemaID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		7								 as  RecordTypeRank 
				,		'ScalarValuedFunctionParameter'  as  RecordType -- 3b  
				,		Xs.ID							 as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		SVFs.ObjectName				as  ObjectName
				,		Xs.ParameterName			as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		Xs.OrdinalNumber			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.ScalarValuedFunction  SVFs  ON  Ss.ID = SVFs.DatabaseSchemaID 
																	 AND SVFs.RecordIsActive = 1 
																	 --
				INNER JOIN	dbocatalogue.ScalarValuedFunctionParameter  Xs  ON  SVFs.ID = Xs.ScalarValuedFunctionID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		8						as  RecordTypeRank 
				,		'TableValuedFunction'   as  RecordType -- 4a  
				,		Xs.ID					as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		Xs.ObjectName				as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.TableValuedFunction  Xs  ON  Ss.ID = Xs.DatabaseSchemaID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		9								 as  RecordTypeRank 
				,		'TableValuedFunctionParameter'   as  RecordType -- 4b  
				,		Xs.ID							 as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		TVFs.ObjectName				as  ObjectName
				,		Xs.ParameterName			as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		Xs.OrdinalNumber			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.TableValuedFunction  TVFs  ON  Ss.ID = TVFs.DatabaseSchemaID 
																	AND TVFs.RecordIsActive = 1 
																	--
				INNER JOIN	dbocatalogue.TableValuedFunctionParameter  Xs  ON  TVFs.ID = Xs.TableValuedFunctionID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		10							  as  RecordTypeRank 
				,		'TableValuedFunctionColumn'   as  RecordType -- 4c  
				,		Xs.ID						  as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		TVFs.ObjectName				as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		Xs.ColumnName				as  ColumnName 
				--
				,		Xs.OrdinalNumber			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.TableValuedFunction  TVFs  ON  Ss.ID = TVFs.DatabaseSchemaID 
																	AND TVFs.RecordIsActive = 1 
																    --
				INNER JOIN	dbocatalogue.TableValuedFunctionColumn  Xs  ON  TVFs.ID = Xs.TableValuedFunctionID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		11					as  RecordTypeRank 
				,		'StoredProcedure'   as  RecordType -- 5a  
				,		Xs.ID				as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		Xs.ObjectName				as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.StoredProcedure  Xs  ON  Ss.ID = Xs.DatabaseSchemaID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		12							 as  RecordTypeRank 
				,		'StoredProcedureParameter'   as  RecordType -- 5b  
				,		Xs.ID						 as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		SPs.ObjectName				as  ObjectName
				,		Xs.ParameterName			as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		Xs.OrdinalNumber			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.StoredProcedure  SPs  ON  Ss.ID = SPs.DatabaseSchemaID 
															   AND SPs.RecordIsActive = 1 
															   --
				INNER JOIN	dbocatalogue.StoredProcedureParameter  Xs  ON  SPs.ID = Xs.StoredProcedureID 
				WHERE	Xs.RecordIsActive = 1 
				
				UNION ALL 
				
				SELECT	SDs.ID		as  ScopedDatabaseID  
				--
				,		13				 as  RecordTypeRank 
				,		'SynonymAlias'   as  RecordType -- 6a  
				,		Xs.ID			 as  RecordID 
				-- 
				,		convert(varchar(256),null)	as  RoleName 
				,		Ss.SchemaName				as  SchemaName 
				,		Xs.ObjectName				as  ObjectName
				,		convert(varchar(256),null)  as  ParameterName
				,		convert(varchar(256),null)  as  ColumnName
				--
				,		convert(int,null)			as  OrdinalNumber 
				--
				,		Xs.PurposeOrMeaning_Description 
				,		Xs.TechnicalNotes 
				--
				FROM	serverconfig.ScopedDatabase	     SDs 
				INNER JOIN	dbocatalogue.DatabaseSchema  Ss  ON  SDs.ID = Ss.ScopedDatabaseID 
														     AND ( SDs.DatabaseName = @DatabaseName 
															     OR @DatabaseName IS NULL ) 
															 AND Ss.RecordIsActive = 1 
															 --
				INNER JOIN  dbocatalogue.SynonymAlias  Xs  ON  Ss.ID = Xs.DatabaseSchemaID 
				WHERE	Xs.RecordIsActive = 1 

				--
			)	--
					 X	
	--
	INNER JOIN  serverconfig.ScopedDatabase  SD  ON  X.ScopedDatabaseID = SD.ID 
    --
)   --	
GO 
-- 
-- END FILE :: a005_dbocatalogue_fcn_ConsolidatedInventory.sql 
-- 