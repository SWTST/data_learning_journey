USE [DBA]
GO

/****** Object:  StoredProcedure [dbo].[UspDatabaseOptimise]    Script Date: 4/20/2026 3:51:50 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UspDatabaseOptimise]
(
@DBName SYSNAME = 'model',
@RetentionWeeks SMALLINT = -5,
@ReassessDay TINYINT = 0,
@LimitProcessing INT = 2147483647,
@BulkRecovery BIT = 0,
@SortOrder VARCHAR(4) = 'DESC',
@RebuildHeap BIT = 0,
@Debug BIT = 0
)
/******************************************************************************************************************

Author  : Nic Hopper
Created : 13-Feb-2012
Purpose : Performs index housekeeping by assessing fragmentation and the either reorganising or rebuilding the index
		  the process is customisable for index via the tblDatabaseConfig table, which allows setting of;
			- Index scan type - Simple/Sampled or detailed
			- Percentages for reorg and rebuild - 
			- upper and lower page count
			for each database - see the '--Set the value of the configuration variables' section below for more details.
SQL Svr : 2005, 2008, 2008 R2,2012,2014 - SQL 2000 is not compatiable with this version you should use the previous version
Version : 2.7.41

Testing : dbo.UspDatabaseOptimise	<Database Name - Null equals all databases>,
									<Mode of the operation - INDEX or STATS>,
									<Number of weeks to retain data for (negative number)>,
									<The day to reassess the indexes - 0 equals every day>,
									<Number of indexes that should be updated in this execution>,
									<Enable bulk recovery mode switching - 1 equals on, 0 equals off>
									<The order in which to process the indexes based on fragmentation>
									<Enable rebuilding of heap tables where the forwarded row count is greater than zero or fragmentation exists>

History	: 29-Feb-2012 - Added in check for databases running in SQL 2000 compatiability mode as if
						a database is it can cause issues with DB_ID() and DB_NAME() commands.
		  14-Mar-2012 - Fixed issue with SQL 2000 databases have non dbo users as the owners.
		  23-Mar-2012 - Added in additional reporting steps.
		  23-Apr-2012 - Fixed issue were read only databases would cause errors.
						Fixed issue were index names with spaces would cause errors.
						Fixed issue were whitespace on database configuration values could
						result in databases marked for exclusion being processed.
		  23-May-2012 - Fixed issue where BLOB objects being read in SQL 2005 + could cause duplicate
						records which resulted in the index being processed twice.
						Modified the way that SQL 2000 fragmentation is detected from extent to
						logical.
						Fixed issue where schema's with spaces in them would cause errors.
		  18-Jul-2012 - Added in support for using an existing set of assessment data and limiting
						the number of indexes being processed.
						Added in the option to change the recovery model to BULK LOGGED when a database
						name is provided.
		  19-Jul-2012 - Added support for sorting of indexes to be processed.
						Recovery models are now stored in a table in tempdb (used by cancellation job).
		  20-Jul-2012 - Session details are now recorded.
		  23-Jul-2012 - Removed PageCount from @VtblIndex as it can cause duplication in index
						processing.
						ProcessedDate column changed from BIT to DATETIME for greater visibility of
						processing state.
		  14-Aug-2012 - Fixed issue where exclusions were being applied but not reported.
		  29-Aug-2012 - Added in support for indexes where the 'allow page lock' is not set (forces rebuild).
		  11-Dec-2012 - Ended support for SQL 2000 (Removed SQL 2000 code).
						Re-written error handling to use TRY CATCH.
						Added in support for the rebuild of heaps for SQL 2008 or higher where the forward record
						count is greater than zero or fragmentation exists. 
						** Use with care as repeated rebuilds can cause fragmentation**
						Removed IndexOption parameter as it was unused.
		  30-Sep-2013 - Added in support for indexed views in index assessment and defragmentation.
		  11-Mar-2014 - Increased DatabaseName length from 40 to 80 in the table variable (@VtblIndex) to reflect 
						changes to the persisted table (tblIndexFragmentation).
						Fixed issue where a database with a read-only file that had an index that required a rebuild
						would result in an error.
						Added in some additional comments regarding forced rebuilds of indexes.
		  28-Mar-2014 - Added in support for statistic scan types.
		  20-Nov-2015 - Resolved an issue with when the scan type is specified in 'STATS' option executions.
		  14-Jan-2016 - Removed index statistic code as statics are now processed by the procedure dbo.UspDatabaseOptimiseStatistics.
		  29-Jan-2016 - Support for databases with collations different to the the DBA database.
		  05-Feb-2016 - Collation support fix extended.
		  03-Mar-21016 - Removed sp_msforeachdb as it was proving unreliable incertain circumstances.
						- Removed parameter optmethod as it was no longer used.
						- Various improvements.
		  14-Sep-2016 - Fixed bug which could prevent the ALTER INDEX script working

******************************************************************************************************************/

AS

--Turn no count on
SET NOCOUNT ON;

--Declare the internal variables for the procedure
DECLARE @SQLVersion DECIMAL(3,1),
		@SQLCommand VARCHAR(MAX),
		@ProcessingDate DATETIME,
		@IndexScanMode VARCHAR(8),
		@ReorganiseThreshold VARCHAR(8),
		@RebuildThreshold VARCHAR(8),
		@PageCountLowerThreshold VARCHAR(8),
		@PageCountUpperThreshold VARCHAR(20),
		@RebuildOnline BIT,
		@RowID INT,
		@RecordDate NVARCHAR(25),
		@RecoveryModel NVARCHAR(25),
		@ForceRebuild BIT,
		@ForceReOrg BIT,
		@IndexType VARCHAR(20);

--First lets check the parameters are set correctly
IF @DBName IS NULL
	BEGIN
		RAISERROR ('Sorry @DBName must me set. Please set it to be a valid database and try again.',10,1)
		RETURN -1
	END

--Check to see if the global temp table ##DatabaseExclusions already exists, if it does then drop it
IF EXISTS (SELECT 1 FROM tempdb..sysobjects WHERE name = '##DatabaseExclusions')
	BEGIN
		DROP TABLE ##DatabaseExclusions
	END;
	
--Check to see if the global temp table ##ProcessData already exists, if it does then drop it
IF EXISTS (SELECT 1 FROM tempdb..sysobjects WHERE name = '##ProcessData')
	BEGIN
		DROP TABLE ##ProcessData
	END;

--Check to see if the table RecoveryModels already exists in tempdb, if it does then drop it
IF EXISTS (SELECT 1 FROM tempdb..sysobjects WHERE name = 'RecoveryModels')
	BEGIN
		DROP TABLE tempdb.dbo.RecoveryModels
	END;

--Create the global temp table ##DatabaseExclusions
CREATE TABLE ##DatabaseExclusions
(
DatabaseName SYSNAME NOT NULL PRIMARY KEY
);

--Create the global temp table ##ProcessData
CREATE TABLE ##ProcessData
(
SPID INT,
ProcessStartTime DATETIME,
ProcessEndTime DATETIME
);

--Create the table dbo.RecoveryModels in tempdb
CREATE TABLE tempdb.dbo.RecoveryModels
(
DatabaseName SYSNAME NOT NULL PRIMARY KEY,
OriginalRecoveryModel NVARCHAR(25)
);

--Determine the version of SQL Server and set the value of @ProcessingDate
SELECT	@SQLVersion = dbo.udfServerVersion(),
		@ProcessingDate = GETDATE(),
		@RowID = 1;

--If the value of @RetentionWeeks is null then set it to be 5
IF @RetentionWeeks IS NULL
	BEGIN
		SET @RetentionWeeks = -5
	END;

--Check to ensure @SortOrder is a valid value, if it is not then set it to be DESC
IF @SortOrder NOT IN ('ASC','DESC')
	BEGIN
		SET @SortOrder = 'DESC'
	END;

--If the value of @LimitProcessing is null then set it to be 2147483647
IF @LimitProcessing IS NULL
	BEGIN
		SET @LimitProcessing = 2147483647
	END;

--If the @BulkRecovery parameter has been enabled but no @DBName has then raise an error
IF @BulkRecovery <> 0 AND @DBName IS NULL
	BEGIN
		RAISERROR ('The bulk recovery option can only be used when a database name is provided.',16,1)
		RETURN -1
	END;

--Check that the value of @ReassessDay is between 0 and 7
IF ISNULL(@ReassessDay,99) NOT BETWEEN 0 AND 7
	BEGIN
		RAISERROR ('The reassess day was not set correctly, it must be a value between 0 and 7. With the value representing the day of the week and 0 being everyday.',10,1)
		RETURN -1
	END
		
--Set the value of the configuration variables
SELECT @IndexScanMode = CAST(DatabaseConfigValue AS VARCHAR(8)) FROM DBA.dbo.tblDatabaseConfig WHERE ConfigName = 'INDEX STATS SCANMODE';
SELECT @ReorganiseThreshold = CAST(DatabaseConfigValue AS VARCHAR(8)) FROM DBA.dbo.tblDatabaseConfig WHERE ConfigName = 'REORGANIZE THRESHOLD';
SELECT @RebuildThreshold = CAST(DatabaseConfigValue AS VARCHAR(8)) FROM DBA.dbo.tblDatabaseConfig WHERE ConfigName = 'REBUILD THRESHOLD';
SELECT @PageCountLowerThreshold = CAST(DatabaseConfigValue AS VARCHAR(8)) FROM DBA.dbo.tblDatabaseConfig WHERE ConfigName = 'REINDEX PAGES LOWER THRESHOLD';
SELECT @PageCountUpperThreshold = CASE WHEN CAST(DatabaseConfigValue AS VARCHAR(20)) = '*' THEN 2147483647 ELSE CAST(DatabaseConfigValue AS INT) END  FROM DBA.dbo.tblDatabaseConfig WHERE ConfigName = 'REINDEX PAGES UPPER THRESHOLD';
SELECT @RebuildOnline = CASE WHEN DatabaseConfigValue = '1' THEN 1 ELSE 0 END FROM DBA.dbo.tblDatabaseConfig WHERE ConfigName = 'REBUILD ONLINE';

--If the version is less than 8 (SQL 2005) then raise an error
IF @SQLVersion < 9
	BEGIN
		RAISERROR ('This version of SQL is not supported by this procedure.',16,1)
		RETURN -1
	END;


--Insert the SPID and start time into the ##ProcessData table
INSERT INTO ##ProcessData
(SPID,ProcessStartTime)

SELECT @@SPID,GETDATE();

--Insert the database recovery model information into the dbo.RecoveryModels table
INSERT INTO tempdb.dbo.RecoveryModels
(DatabaseName,OriginalRecoveryModel)
	
SELECT Name,
		CAST(DATABASEPROPERTYEX(name,'RECOVERY') AS NVARCHAR(35)) AS OriginalRecoveryModel
FROM Sys.Databases;

--Set the value of @RecordDate to be the current date and time
SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
	
RAISERROR('%s - Recovery models for databases have been recorded.', 0, 1,@RecordDate,@DBName) WITH NOWAIT;
	
--Populate the global temp table with databases to exclude
INSERT INTO ##DatabaseExclusions 
SELECT ('AdventureWorks') UNION ALL 
SELECT ('AdventureWorksDW') UNION ALL
SELECT('Northwind') UNION ALL
SELECT('pubs') UNION ALL
SELECT('ReportServerTempDB') UNION ALL
SELECT('tempdb');

--Insert and additional databases which can be excluded
INSERT INTO ##DatabaseExclusions
(DatabaseName)

SELECT DatabaseName
FROM DBA.dbo.tblDatabaseConfig D
WHERE ConfigName = 'OPTIMISE EXCLUDE'
AND LTRIM(RTRIM(CAST(DatabaseConfigValue AS VARCHAR(1)))) = 1
AND NOT EXISTS (SELECT 1 FROM ##DatabaseExclusions E WHERE D.DatabaseName = E.DatabaseName COLLATE DATABASE_DEFAULT)

-- And additional databases which can be excluded, this is done seperately due to the collation needing to be included.
INSERT INTO ##DatabaseExclusions
(DatabaseName)

SELECT name
FROM sys.databases D
WHERE (
	DATABASEPROPERTYEX(name, 'Status') <> 'ONLINE'
	OR DATABASEPROPERTYEX(name, 'Updateability')  = 'READ_ONLY'
	)
AND NOT EXISTS (SELECT 1 FROM ##DatabaseExclusions E WHERE D.Name = E.DatabaseName COLLATE DATABASE_DEFAULT);

--Set the value of @RecordDate to be the current date and time
SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
	
RAISERROR('%s - Exclusions list has been populated.', 0, 1,@RecordDate,@DBName) WITH NOWAIT;	

--If the database is in the exclusions list then no action is required
IF @DBName IN (SELECT DatabaseName FROM ##DatabaseExclusions)
	BEGIN
		--Set the value of @RecordDate to be the current date and time	
		SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
	
		RAISERROR('%s - The database (%s) is in the exclusions list, no action will be performed.', 0, 1,@RecordDate,@DBName) WITH NOWAIT;
	
		--Return success
		RETURN 0;
	END

--If the version of SQL Server is below SQL 2008 then heap rebuilds are not supported.
IF @SQLVersion < 10 AND @RebuildHeap = 1
	BEGIN
		--Set the value of @RecordDate to be the current date and time	
		SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
	
		RAISERROR('%s - This version of SQL Server does not support heap rebuilds, the feature will be disabled.', 0, 1,@RecordDate) WITH NOWAIT;
		
		--Set the value of @RebuildHeap to be 0
		SET @RebuildHeap = 0;
	END

--If @BulkRecovery is enabled and @DBName has been provided
IF @BulkRecovery = 1 AND @DBName IS NOT NULL 
	BEGIN
		--Determine the current recovery model of the database
		SELECT @RecoveryModel = CAST(DATABASEPROPERTYEX(@DBName, 'RECOVERY') AS NVARCHAR(25));

		--If it is not in full mode then no action is required.
		IF @RecoveryModel <> 'FULL'
			BEGIN
				--Set the value of @RecordDate to be the current date and time
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
			
				RAISERROR('%s - The database (%s) is not in full recovery model so the bulk option will be ignored.', 0, 1,@RecordDate,@DBName) WITH NOWAIT;	
			END
		--Else change the recovery model of the database to be BULK LOGGED
		ELSE
			BEGIN
				SELECT @SQLCommand = 'USE Master; ALTER DATABASE [' +  @DBName + '] SET RECOVERY BULK_LOGGED WITH NO_WAIT';
				
				EXEC (@SQLCommand);
				
				--Set the value of @RecordDate to be the current date and time
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
			
				RAISERROR('%s - The database (%s) has been changed from %s to BULK LOGGED.', 0, 1,@RecordDate,@DBName,@RecoveryModel) WITH NOWAIT;	
			END
	END

--Begin try
BEGIN TRY

		--If the value of @ReassessDay equals today or is 0 then we reassess the index fragmentation
		IF @ReassessDay = (SELECT DATEPART(DW,GETDATE())) OR @ReassessDay = 0
			BEGIN			
				SET @SQLCommand = 'USE [?] DECLARE @DatabaseID TINYINT,@RecordDate NVARCHAR(25),@ReadOnly BIT
				IF NOT EXISTS (SELECT 1 FROM ##DatabaseExclusions WHERE DatabaseName = ''?'')
					BEGIN
						SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121) 
						RAISERROR(''%s - Assesing index fragmentation on the database (?).'',0,1,@RecordDate) WITH NOWAIT

						SELECT @ReadOnly = COUNT(1) FROM sys.database_files WHERE is_read_only = 1
								
						INSERT INTO dba.dbo.tblIndexFragmentation
						(database_name,object_name,index_name,partition_number,index_type_desc,alloc_unit_type_desc,
						index_depth,index_level,avg_fragmentation_in_percent,fragment_count,avg_fragment_size_in_pages,
						page_count,avg_page_space_used_in_percent,record_count,ghost_record_count,
						version_ghost_record_count,min_record_size_in_bytes,max_record_size_in_bytes,avg_record_size_in_bytes,
						forwarded_record_count,DateRecorded)
								
						SELECT	DB_NAME(database_id),''['' + SCHEMA_NAME(T.schema_id) + ''].['' + T.Name + '']'',
								I.Name,partition_number,index_type_desc,alloc_unit_type_desc,index_depth,index_level,
								avg_fragmentation_in_percent = CASE WHEN I.allow_page_locks = 0 AND avg_fragmentation_in_percent > ' + @ReorganiseThreshold + ' THEN 110
																	WHEN @ReadOnly > 0 AND avg_fragmentation_in_percent > ' + @ReorganiseThreshold + ' THEN 00 
								ELSE avg_fragmentation_in_percent END,fragment_count,avg_fragment_size_in_pages,page_count,avg_page_space_used_in_percent,record_count,
								ghost_record_count,version_ghost_record_count,min_record_size_in_bytes,max_record_size_in_bytes,avg_record_size_in_bytes,forwarded_record_count,'
								+ '''' + CONVERT(VARCHAR(40),@ProcessingDate,113) + '''' + '
						FROM sys.dm_db_index_physical_stats (db_id(''?''),null,null,null,' + '''' + @IndexScanMode + '''' + ') D
						INNER JOIN sys.objects T ON D.Object_id = T.Object_id INNER JOIN sys.indexes I ON D.object_id = I.object_id AND D.index_id = I.index_id
						WHERE D.index_id BETWEEN 1 AND 249 OR 1 = ' + CONVERT(VARCHAR(1),@RebuildHeap) + '
					END
				ELSE
					BEGIN
						SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121)
						RAISERROR(''%s - The database (?) has been excluded from the optimisation process.'',0,1,@RecordDate) WITH NOWAIT
					END';
						
				--Now we have the string built we need to run it

				--Set the value of @RecordDate to be the current date and time
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
							
				RAISERROR('%s - Assessing index fragmentation on the %s database using minimum page count value of %s and a reorganisation threshold of %s percent. The scan mode is (%s).', 0, 1,@RecordDate,@DBName,@PageCountLowerThreshold,@ReorganiseThreshold,@IndexScanMode) WITH NOWAIT;
										
				--Add in the @DBName value into the @SQLCommand string
				SET @SQLCommand = REPLACE(@SQLCommand,'?',@DBName);

				IF @Debug = 1
					BEGIN
						PRINT @SQLCommand
					END
						
				--Execute @SQLCommand
				EXEC (@SQLCommand);
							
				--Set the value of @RecordDate to be the current date and time
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
						
				RAISERROR('%s - Completed index assesment the details of which are available in the dbo.tblIndexFragmentation table.', 0, 1,@RecordDate) WITH NOWAIT;
			END
		--Else we are using the last set of fragmentation data
		ELSE
			IF @DBName IS NOT NULL
				BEGIN
					SET @ProcessingDate = (SELECT MAX(DateRecorded) FROM dbo.tblIndexFragmentation WHERE database_name = @DBName);
						
					SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
																									
					RAISERROR('%s - Re-assessment is disabled for this database today, using the last set of fragmentation data for the database (%s). Processing using minimum page count value of %s and a reorganisation threshold of %s percent. ', 0, 1,@RecordDate,@DBName,@PageCountLowerThreshold,@ReorganiseThreshold) WITH NOWAIT;
				END
		

		--Declare a table variable which will hold the details of the indexes that are fragmented
		DECLARE @VtblIndex TABLE
		(
		Id INT IDENTITY(1,1),
		DatabaseName VARCHAR(80),
		ObjectName VARCHAR(255),
		IndexName VARCHAR(255),
		IndexType VARCHAR(20),
		FragmentationPercentage FLOAT
		);

		--Insert the details of the fragmented indexes into the table variable
		INSERT INTO @VtblIndex
		(
		DatabaseName,
		ObjectName,
		IndexName,
		IndexType,
		FragmentationPercentage
		)

		--Determine the indexes that require maintenance
		SELECT TOP (@LimitProcessing)	I.database_name AS DatabaseName,
										I.[object_name] AS ObjectName,
										I.index_name AS IndexName,
										I.index_type_desc AS IndexType,
										MAX(I.avg_fragmentation_in_percent) AS avg_fragmentation_in_percent
		FROM dba.dbo.tblIndexFragmentation I
		WHERE DateRecorded = @ProcessingDate
		AND avg_fragmentation_in_percent >= @ReorganiseThreshold
		AND page_count BETWEEN @PageCountLowerThreshold AND @PageCountUpperThreshold
		AND DefragmentationEnd IS NULL
		AND (I.database_name = @DBName OR @DBName IS NULL)
		AND (
			I.index_type_desc <> 'HEAP'
				OR 
			(I.index_type_desc = 'HEAP' 
			AND (forwarded_record_count > 0 OR I.avg_fragmentation_in_percent > @ReorganiseThreshold)
			AND @RebuildHeap = 1)
			)
		GROUP BY I.database_name,
				I.[object_name],
				I.index_name,
				I.index_type_desc
		ORDER BY CASE WHEN I.index_type_desc <> 'HEAP' THEN 0 ELSE 1 END, 
				CASE WHEN @SortOrder = 'ASC' THEN MAX(I.avg_fragmentation_in_percent) END ASC,
				CASE WHEN @SortOrder = 'DESC' THEN MAX(I.avg_fragmentation_in_percent) END DESC;

		--If no records are inserted then write to the log and return out of the procedure
		IF @@ROWCOUNT = 0
			BEGIN
				--Set the value of @RecordDate to be the current date and time
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
			
				RAISERROR('%s - No fragmented indexes found using the specified parameters, no further action is required.', 0, 1,@RecordDate) WITH NOWAIT;
				
				--Now check if the recovery model is different to what we began with, if it is then change the recovery model back
				IF (SELECT CAST(DATABASEPROPERTYEX(@DBName, 'RECOVERY') AS NVARCHAR(25))) <> @RecoveryModel
					BEGIN
						SELECT @SQLCommand = 'USE Master; ALTER DATABASE [' +  @DBName + '] SET RECOVERY ' + @RecoveryModel + ' WITH NO_WAIT';
								
						EXEC (@SQLCommand);
									
						SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
						
						RAISERROR('%s - The database (%s) has been changed back from BULK LOGGED to %s.', 0, 1,@RecordDate,@DBName,@RecoveryModel) WITH NOWAIT;		
					END
									
				--Return success
				RETURN 0;
			END
		
		--Reset the value of @SQLCommand to be an empty string
		SET @SQLCommand = '';

		--Set the value of @RecordDate to be the current date and time
		SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

		RAISERROR('%s - Finished assessing index fragmentation, beginning process to remove external fragmentation.', 0, 1,@RecordDate) WITH NOWAIT;

		SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

		RAISERROR('%s - Picked the top (%i) most fragmented indexes to process, based on the (%s) sort order.', 0, 1,@RecordDate,@LimitProcessing,@SortOrder) WITH NOWAIT;

		--Now we have a list of the indexes that require maintenance we can loop over them
		WHILE EXISTS (SELECT 1 FROM @VtblIndex WHERE Id = @RowID)
			BEGIN
				--Determine the index type and if the index requires a forced rebuild or reorganise
				SELECT	@IndexType = IndexType,
						@ForceRebuild = CASE WHEN FragmentationPercentage = 110 THEN 1 ELSE 0 END,
						@ForceReOrg = CASE WHEN FragmentationPercentage = 00 THEN 1 ELSE 0 END
				FROM @VtblIndex 
				WHERE Id = @RowID;
						
				--If the index is a heap
				IF @IndexType = 'HEAP'
					BEGIN
						--Build up the value of the @SQLCommand variable
						SELECT @SQLCommand = 'USE [' + DatabaseName + ']; ALTER TABLE ' + LTRIM(RTRIM(ObjectName)) + ' REBUILD'
						FROM @VtblIndex
						WHERE Id = @RowID;						
					END
				--Else the index is not a heap
				ELSE IF @IndexType <> 'HEAP'
					BEGIN
						--Build up the value of the @SQLCommand variable
						SELECT @SQLCommand = 'USE [' + DatabaseName + ']; ALTER INDEX [' + LTRIM(RTRIM(IndexName)) + '] ON ' + LTRIM(RTRIM(ObjectName))
											+ ' ' + CASE WHEN FragmentationPercentage < @RebuildThreshold THEN 'REORGANIZE' 
															WHEN FragmentationPercentage >= @RebuildThreshold THEN 'REBUILD'
															END
						FROM @VtblIndex
						WHERE Id = @RowID;
					END
						
				--If the @RebuildOnline variable equals 1 and edition of SQL supports it then turn on online index maintenance.
				IF @RebuildOnline = 1 AND SERVERPROPERTY('EngineEdition') = 3
					BEGIN
						SET @SQLCommand = @SQLCommand + ' WITH (ONLINE=ON)';
					END
									
				--If @ForceRebuild equals 1 then add a comment on to mark the record in the log as a forced rebuild
				IF @ForceRebuild = 1
					BEGIN
						SET @SQLCommand = @SQLCommand + ' --*FORCED REBUILD*';
					END

				--If @ForceReOrg equals 1 then add a comment on to mark the record in the log as a forced reorganise
				IF @ForceReOrg = 1
					BEGIN
						SET @SQLCommand = @SQLCommand + ' --*FORCE REORGANIZE*';
					END
							
				--Set the value of @RecordDate to be the current date and time
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
				
				RAISERROR('%s - Running command (%s).', 0, 1,@RecordDate,@SQLCommand) WITH NOWAIT;
				
				--Mark the index defragmentation start time										
				UPDATE F
				SET DefragmentationStart = GETDATE()
				FROM tblIndexFragmentation F
				INNER JOIN @VtblIndex V ON V.DatabaseName = F.database_name
											AND V.ObjectName = F.[object_name]
											AND ISNULL(V.IndexName,'HEAP') = ISNULL(F.index_name,'HEAP')
											AND F.DateRecorded = @ProcessingDate
				WHERE V.Id = @RowID;		
				
				--Execute @SQLCommand
				EXEC (@SQLCommand);
								
				--Mark the index defragmentation end time									
				UPDATE F
				SET DefragmentationEnd = GETDATE()
				FROM tblIndexFragmentation F
				INNER JOIN @VtblIndex V ON V.DatabaseName = F.database_name
											AND V.ObjectName = F.[object_name]
											AND ISNULL(V.IndexName,'HEAP') = ISNULL(F.index_name,'HEAP')
											AND F.DateRecorded = @ProcessingDate
				WHERE V.Id = @RowID;
					
				--Increment the value of @RowID by 1				
				SET @RowID = @RowID + 1;
										
				--Reset the value of @SQLCommand to be an empty string
				SET @SQLCommand = '';
			END							
			
		--Begin transaction	
		BEGIN TRANSACTION
			
			--Delete records where are older than the value of @RetentionWeeks
			DELETE FROM dbo.tblIndexFragmentation
			WHERE DateRecorded < DATEADD(wk,@RetentionWeeks,@ProcessingDate);

		--Commit transaction		
		COMMIT TRANSACTION
			
		--Now check if the recovery model is different to what we began with, if it is then change the recovery model back
		IF (SELECT CAST(DATABASEPROPERTYEX(@DBName, 'RECOVERY') AS NVARCHAR(25))) <> @RecoveryModel
			BEGIN
				SELECT @SQLCommand = 'USE Master; ALTER DATABASE [' +  @DBName + '] SET RECOVERY ' + @RecoveryModel + ' WITH NO_WAIT';
					
				EXEC (@SQLCommand);
					
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
						
				RAISERROR('%s - The database (%s) has been changed back from BULK LOGGED to %s.', 0, 1,@RecordDate,@DBName,@RecoveryModel) WITH NOWAIT;		
			END
			
		--Set the value of @RecordDate to be the current date and time
		SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
			
		RAISERROR('%s - Successfully completed process to remove external fragmentation.', 0, 1,@RecordDate) WITH NOWAIT;

		--Update the ##ProcessData table to set the ProcessEndTime
		UPDATE ##ProcessData
		SET ProcessEndTime = GETDATE();				
					
		--Turn no count off
		SET NOCOUNT OFF;

		--Return success
		RETURN 0;

--End try
END TRY

--Begin catch
BEGIN CATCH

	--Declare the variable @ErrorMessage
	DECLARE @ErrorMessage VARCHAR(500);
	
	--Set the value of @ErrorMessage
	SET @ErrorMessage = 'The error (' + ERROR_MESSAGE() + ') was raised by the procedure.';

	--If a transaction is open then roll it back
	IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION
		END;
		
	--Now check if the recovery model is different to what we began with, if it is then change the recovery model back
	IF (SELECT CAST(DATABASEPROPERTYEX(@DBName, 'RECOVERY') AS NVARCHAR(25))) <> @RecoveryModel
		BEGIN
			SELECT @SQLCommand = 'USE Master; ALTER DATABASE [' +  @DBName + '] SET RECOVERY ' + @RecoveryModel + ' WITH NO_WAIT';
			
			--Begin try
			BEGIN TRY
					
				--Execute the value @SQLCommand
				EXEC (@SQLCommand);
			
			--End try
			END TRY
			
			--Begin catch
			BEGIN CATCH
			
				--Set the value of @RecordDate
				SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
				--Set the value of @ErrorMessage
				SET @ErrorMessage = 'Oops this is a bit embarrasing, the error handler appears to have errored whilst trying to change the recovery model back to %s, please can you help? Oh and if it helps the original error message was (' + @ErrorMessage + ').';
				--Raise the error message
				RAISERROR(@ErrorMessage,16,1,@RecoveryModel);
				--Return failure
				RETURN -1;			
			--End catch
			END CATCH
			
			SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
			
			RAISERROR('%s - The database (%s) has been changed back from BULK LOGGED to %s.', 0, 1,@RecordDate,@DBName,@RecoveryModel) WITH NOWAIT;		
		END
		
	--Update the ##ProcessData table to set the ProcessEndTime
	UPDATE ##ProcessData
	SET ProcessEndTime = GETDATE();
	
	SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);
	
	RAISERROR('%s - An error occured the details of which are below, any open transactions were rolled back and the recovery model has been restored to %s.',10,1,@RecordDate,@RecoveryModel) WITH NOWAIT;
	
	--Raise the error message
	RAISERROR(@ErrorMessage,16,1);

	--Return failure
	RETURN -1;

--End catch
END CATCH
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This procedure is used to assess index fragmentation and then deal with accoring to a reorganise and rebuild threshold contained in dbo.tblDatabaseConfig,
			it can also be used to either sample or fully rebuild statistics. ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'PROCEDURE',@level1name=N'UspDatabaseOptimise'
GO


