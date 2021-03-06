--
-- BEGIN FILE :: a000_EXAMPLE_DatabaseCreationScript.sql 
--
/************************************************************************************************************************************
-- This is only an example of a query to create a new database (script generated on August 24th, 2020). 
-- I generally recommend creating new databases using the SSMS user-interface forms instead of a query. 
-- After creating this database, give it the standard [dbo].[fcn_DebugInfo] scalar-valued function & [utility]-schema and objects. 
-- If using this script file, remember to change 'FILENAME' values below for main data-file & log-file paths. 
************************************************************************************************************************************/
USE [master]
GO
CREATE DATABASE [a_METADATA]
 CONTAINMENT = NONE
 ON  PRIMARY /*** !! IMPORTANT !! ... change FILENAME values below to match the appropriate paths for your instance !! ***/ 
( NAME = N'a_METADATA', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.TIGERSSDEV\MSSQL\DATA\a_METADATA.mdf' , SIZE = 262144KB , MAXSIZE = UNLIMITED, FILEGROWTH = 524288KB )
 LOG ON 
( NAME = N'a_METADATA_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.TIGERSSDEV\MSSQL\DATA\a_METADATA_log.ldf' , SIZE = 524288KB , MAXSIZE = 2048GB , FILEGROWTH = 524288KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
BEGIN
EXEC [a_METADATA].[dbo].[sp_fulltext_database] @action = 'enable'
END
GO
ALTER DATABASE [a_METADATA] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [a_METADATA] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [a_METADATA] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [a_METADATA] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [a_METADATA] SET ARITHABORT OFF 
GO
ALTER DATABASE [a_METADATA] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [a_METADATA] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [a_METADATA] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [a_METADATA] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [a_METADATA] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [a_METADATA] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [a_METADATA] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [a_METADATA] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [a_METADATA] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [a_METADATA] SET  DISABLE_BROKER 
GO
ALTER DATABASE [a_METADATA] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [a_METADATA] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [a_METADATA] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [a_METADATA] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [a_METADATA] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [a_METADATA] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [a_METADATA] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [a_METADATA] SET RECOVERY FULL 
GO
ALTER DATABASE [a_METADATA] SET  MULTI_USER 
GO
ALTER DATABASE [a_METADATA] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [a_METADATA] SET DB_CHAINING OFF 
GO
ALTER DATABASE [a_METADATA] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [a_METADATA] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [a_METADATA] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [a_METADATA] SET QUERY_STORE = OFF
GO
ALTER DATABASE [a_METADATA] SET  READ_WRITE 
GO
--
-- END FILE :: a000_EXAMPLE_DatabaseCreationScript.sql 
--