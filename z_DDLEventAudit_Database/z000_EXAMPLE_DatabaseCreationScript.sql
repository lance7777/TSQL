--
-- BEGIN FILE :: z000_EXAMPLE_DatabaseCreationScript.sql 
--
/***************************************************************************************************************
-- This is only an example of a query to create a new database (script generated on August 31st, 2020). 
-- I generally recommend creating new databases using the SSMS user-interface forms instead of a query. 
-- After creating this database, give it the standard [dbo].[fcn_DebugInfo] scalar-valued function. 
-- If using this script file, remember to change 'FILENAME' values below for main data-file & log-file paths. 
***************************************************************************************************************/
USE [master]
GO
CREATE DATABASE [z_DDLEventAudit]
 CONTAINMENT = NONE
 ON  PRIMARY /*** !! IMPORTANT !! ... change FILENAME values below to match the appropriate paths for your instance !! ***/ 
( NAME = N'z_DDLEventAudit', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.TIGERSSDEV\MSSQL\DATA\z_DDLEventAudit.mdf' , SIZE = 1048576KB , MAXSIZE = 10485760KB , FILEGROWTH = 524288KB )
 LOG ON 
( NAME = N'z_DDLEventAudit_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.TIGERSSDEV\MSSQL\DATA\z_DDLEventAudit_log.ldf' , SIZE = 524288KB , MAXSIZE = 10485760KB , FILEGROWTH = 524288KB )
GO
ALTER DATABASE [z_DDLEventAudit] SET COMPATIBILITY_LEVEL = 150
GO
ALTER DATABASE [z_DDLEventAudit] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET ARITHABORT OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF)
GO
ALTER DATABASE [z_DDLEventAudit] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [z_DDLEventAudit] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [z_DDLEventAudit] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET  DISABLE_BROKER 
GO
ALTER DATABASE [z_DDLEventAudit] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [z_DDLEventAudit] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [z_DDLEventAudit] SET  READ_WRITE 
GO
ALTER DATABASE [z_DDLEventAudit] SET RECOVERY FULL 
GO
ALTER DATABASE [z_DDLEventAudit] SET  MULTI_USER 
GO
ALTER DATABASE [z_DDLEventAudit] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [z_DDLEventAudit] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [z_DDLEventAudit] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = Off;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET LEGACY_CARDINALITY_ESTIMATION = Primary;
GO
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = On;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET PARAMETER_SNIFFING = Primary;
GO
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = Off;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET QUERY_OPTIMIZER_HOTFIXES = Primary;
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [z_DDLEventAudit] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
--
-- END FILE :: z000_EXAMPLE_DatabaseCreationScript.sql 
--