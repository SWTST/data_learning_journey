USE [DBA]
GO

/****** Object:  StoredProcedure [dbo].[UspDatabaseOptimiseStatistics]    Script Date: 4/20/2026 3:54:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************************************************

Author  : Nic Hopper
Created : Feb 2012
Purpose : Performs statistic updates based on the age of the statistic.
SQL Svr : 2000,2005, 2008, 2008 R2,2012,2014
Version : 2.2.39

Testing : dbo.UspDatabaseOptimiseStatistics	<Database Name> - Null equals all databases,otherwise the name of the database to process.
									<StatiticsAgeHours> - The number of hours since the last update for the statistic.
									<SampleValue> - The percentage to sample when updating the statistic.
									<PrintCommandOnly> - Used to generate the command for debugging and manual updates.
History	: 14-Jan-2016 - Rewritten procedure to store statistic data and also expanded functionality to enable database.
						specific settings.
		20-Jan-2016 - Fixed issue where data was incorrectly deleted from the dbo.tblStatUpdate table.
					- Minor changes to output message.
		23-Jan-2016 - Changes include - Option to configure specific statistic update properties for a database, table
					or statistic via statistic overrides.
					- Supports Sampling and Resampling
					- Supports Sampling by ROWS or PERCENT
		28-Jan-2016 - Support for long object name
					- Added errror handling
					- Fixed bug that could create excessive exclusion reporting if @DBName was null.
					- Performance enhancements for when @DBName is specified as it no longer requires running on all databases.
		29-Jan-2016	- Extended the length of the command string to support longer object names.
					- Excludes databases which are not online or a read only.
					- Support for databases with collations different to the the DBA database.
		04-Feb-2016	- Fixed issue where if @DBName was provided the database state was not checked and this could result in errors.

Parameters
	@DBName - the database name, if null all databases will be assessed
	@StatisticAgeHours - The maximum age a statistic can be to avoid being assessed, 0 will force
	@SampleValue - The sample rate for the update, null will default to a SAMPLE in which SQL will decide based
					on the table size. Unless an override sample type has been set in the override table then this value
					will be applied as a PERCENT.
	@PrintCommandOnly - Prints the commands that would be run but it does not run the actual command.
******************************************************************************************************************/


CREATE PROCEDURE [dbo].[UspDatabaseOptimiseStatistics]
(
@DBName SYSNAME = NULL,
@StatisticAgeHours SMALLINT=1,
@SampleValue SMALLINT = NULL,
@PrintCommandOnly BIT = 0
)

AS

--Turn no count on
SET NOCOUNT ON;

--Declare the internal variables used by the procedure
DECLARE @Counter INT = 1,
		@Command VARCHAR(2000),
		@RecordDate NVARCHAR(25),
		@SampleOverrideValue SMALLINT,
		@SampleOverrideType VARCHAR(10),
		@ResampleOverride BIT;

--Set the value of @RecordDate to equal the current date and time
SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

IF @SampleValue NOT BETWEEN 1 AND 100
	BEGIN
		RAISERROR('%s - The sample rate provided is not valid it must be between 1 and 100.', 0, 1,@RecordDate);
		RETURN -1
	END;

IF @DBName IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Sys.Databases WHERE State_Desc = 'ONLINE' AND is_read_only = 0 AND Name = @DBName)
	BEGIN
		RAISERROR('%s - The database %s is not in the correct state and can not be processed.', 0, 1,@RecordDate,@DBName);
		RETURN -1
	END;

--Check to see if the global temp table ##DatabaseExclusions already exists, if it does then drop it
IF EXISTS (SELECT 1 FROM tempdb..sysobjects WHERE name = '##DatabaseExclusions')
	BEGIN
		DROP TABLE ##DatabaseExclusions
	END;

--Check to see if the global temp table ##VtblStats already exists, if it does then drop it
IF EXISTS (SELECT 1 FROM tempdb..sysobjects WHERE name = '##VtblStats')
	BEGIN
		DROP TABLE ##VtblStats
	END;

--Create the table ##DatabaseExclusions
CREATE TABLE ##DatabaseExclusions
(
DatabaseName SYSNAME NOT NULL PRIMARY KEY
);

--Insert excluded databases into the table
INSERT INTO ##DatabaseExclusions

SELECT ('AdventureWorks') UNION ALL 
SELECT ('AdventureWorksDW') UNION ALL
SELECT('Northwind') UNION ALL
SELECT('pubs') UNION ALL
SELECT('ReportServerTempDB') UNION ALL
SELECT('tempdb') UNION ALL
SELECT DatabaseName FROM dbo.tblDatabaseConfig WHERE ConfigName = 'STATS EXCLUDE' AND DatabaseConfigValue = '1';


--IF @DBName has been provided then populate the exclusions with all the other databases.
IF @DBName IS NOT NULL
	BEGIN
		INSERT INTO ##DatabaseExclusions
		SELECT name FROM sys.databases D 
		WHERE Name <> @DBName 
		AND NOT EXISTS(SELECT 1 FROM ##DatabaseExclusions E WHERE D.Name = E.DatabaseName)
	END;

--Add other databases which can not be processed.
INSERT INTO ##DatabaseExclusions
SELECT name FROM sys.databases D 
WHERE (state_desc <> 'Online' OR is_read_only = 1)
AND NOT EXISTS(SELECT 1 FROM ##DatabaseExclusions E WHERE D.Name = E.DatabaseName);

--Create the table ##VtblStats
CREATE TABLE ##VtblStats
(
StatID INT IDENTITY(1,1),
DatabaseName VARCHAR(40),
SchemaName VARCHAR(255),
TableName VARCHAR(255),
StatName VARCHAR(255),
UpdateStartTime DATETIME,
UpdateEndTime DATETIME,
UpdateSampleValue INT,
);

--Set the value of @RecordDate to equal the current date and time
SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

RAISERROR('%s - Generating list of statistics to process. Searching for statistics aged %i hours or older.', 0, 1,@RecordDate,@StatisticAgeHours) WITH NOWAIT;

--Set the value of @Command
SELECT @Command = 'USE [?];

					DECLARE @DatabaseName VARCHAR(40),
							@RecordDate VARCHAR(20)
					SET @DatabaseName = ''?''
					SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

					IF NOT EXISTS (SELECT 1 FROM ##DatabaseExclusions WHERE DatabaseName = ''?'')
						BEGIN

							RAISERROR (''%s - Checking the %s database.'',0,1,@RecordDate,@DatabaseName)
							INSERT INTO ##VtblStats
							(DatabaseName,SchemaName,TableName,StatName)

							SELECT DB_NAME() AS DatabaseName,
							schema_name(O.schema_id),
							 ''['' + OBJECT_NAME(S.object_id) + '']'' AS TableName,
							''['' + S.name + '']'' AS StatName
							FROM sys.stats S
							INNER JOIN sys.objects O ON S.object_id = O.Object_id
							WHERE DATEDIFF(hh,STATS_DATE(S.object_id,stats_id),GETDATE()) >= ' + CAST(@StatisticAgeHours AS VARCHAR(2))
						+ ' END
						ELSE ' +
							'BEGIN
								RAISERROR (''%s - The database %s has been marked as an exclusion and will not be processed.'',0,1,@RecordDate,@DatabaseName)
							END';

--If @DBName is null then we will run the command on database
IF @DBName IS NULL
	BEGIN
		--Execute @Command for each database
		EXEC sp_msforeachdb @command1 = @command;
	END
ELSE
	BEGIN
		SELECT @Command = REPLACE(@Command,'?',@DBName)
		EXEC (@Command)
	END


--Set the value of @RecordDate to equal the current date and time
SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

RAISERROR('%s - Statistics gathering completed, updating statistics with a sample rate of %i. Statistics with a specified override value will be different.', 0, 1,@RecordDate,@SampleValue) WITH NOWAIT;

--While a record exists update the statistic
WHILE EXISTS (SELECT 1 FROM ##VtblStats WHERE StatID = @Counter)
	BEGIN

		--Reset the value of @SampleOverrideValue
		SET @SampleOverrideValue = NULL;
		SET @SampleOverrideType = NULL;
		SET @ResampleOverride = 0;

		--See if there is an overide value for the statistic itself
		SELECT @SampleOverrideValue  = CASE WHEN OS.SampleValue IS NOT NULL THEN OS.SampleValue
										WHEN OT.SampleValue IS NOT NULL THEN OT.SampleValue
										WHEN Osc.SampleValue IS NOT NULL THEN Osc.SampleValue
										WHEN OD.SampleValue IS NOT NULL THEN OD.SampleValue
									END,
				 @SampleOverrideType  = CASE WHEN OS.SampleType IS NOT NULL THEN OS.SampleType
														WHEN OT.SampleType IS NOT NULL THEN OT.SampleType
														WHEN Osc.SampleType IS NOT NULL THEN Osc.SampleType
														WHEN OD.SampleType IS NOT NULL THEN OD.SampleType
													END,
				@ResampleOverride = CASE WHEN OS.ForceResample IS NOT NULL THEN OS.ForceResample
														WHEN OT.ForceResample IS NOT NULL THEN OT.ForceResample
														WHEN Osc.ForceResample IS NOT NULL THEN Osc.ForceResample
														WHEN OD.ForceResample IS NOT NULL THEN OD.ForceResample
													END
		FROM ##VtblStats S
		LEFT JOIN (
				--Get the override values for the statistic
				SELECT DatabaseName,SchemaName,TableName,StatisticName,SampleValue,SampleType,ForceResample FROM dbo.tblStatisticsOverride WHERE Active = 1
				) AS OS ON REPLACE(REPLACE(S.DatabaseName,'[',''),']','') = OS.DatabaseName COLLATE DATABASE_DEFAULT
											AND REPLACE(REPLACE(S.SchemaName,'[',''),']','')= OS.SchemaName COLLATE DATABASE_DEFAULT
											AND REPLACE(REPLACE(S.TableName,'[',''),']','')  = OS.TableName COLLATE DATABASE_DEFAULT
											AND REPLACE(REPLACE(S.StatName,'[',''),']','') = OS.StatisticName COLLATE DATABASE_DEFAULT
		LEFT JOIN (
				SELECT DatabaseName,SchemaName,TableName,StatisticName,SampleValue,SampleType,ForceResample FROM dbo.tblStatisticsOverride WHERE Active = 1
				) AS Osc ON REPLACE(REPLACE(S.DatabaseName,'[',''),']','') = OSc.DatabaseName COLLATE DATABASE_DEFAULT
											AND REPLACE(REPLACE(S.SchemaName,'[',''),']','')= OSc.SchemaName COLLATE DATABASE_DEFAULT
											AND OSc.TableName IS NULL
											AND OSc.StatisticName IS NULL
		LEFT JOIN (
				SELECT DatabaseName,SchemaName,TableName,StatisticName,SampleValue,SampleType,ForceResample FROM dbo.tblStatisticsOverride WHERE Active = 1
				) AS OT ON REPLACE(REPLACE(S.DatabaseName,'[',''),']','') = OT.DatabaseName COLLATE DATABASE_DEFAULT
											AND REPLACE(REPLACE(S.SchemaName,'[',''),']','')= OT.SchemaName COLLATE DATABASE_DEFAULT
											AND REPLACE(REPLACE(S.TableName,'[',''),']','')  = OT.TableName COLLATE DATABASE_DEFAULT
											AND OT.StatisticName IS NULL
		LEFT JOIN (
				SELECT DatabaseName,SchemaName,TableName,StatisticName,SampleValue,SampleType,ForceResample FROM dbo.tblStatisticsOverride WHERE Active = 1
				) AS OD ON REPLACE(REPLACE(S.DatabaseName,'[',''),']','') = OD.DatabaseName COLLATE DATABASE_DEFAULT
											AND OD.SchemaName IS NULL
											AND OD.TableName IS NULL
											AND OD.StatisticName IS NULL
		WHERE StatID = @Counter;

		IF @ResampleOverride = 1 AND (@SampleOverrideType IS NOT NULL OR @SampleOverrideValue IS NOT NULL)
		BEGIN

		--Set the value of @RecordDate to equal the current date and time
		SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

		RAISERROR('%s - A conflict in values was detecting, when a force resample is attempted, the override value amd type must be null, I will set them to be null now and continue to process.', 0, 1,@RecordDate) WITH NOWAIT;


			SET @SampleOverrideType = NULL
			SET @SampleOverrideValue = NULL
		END

		--Build the @Command string
		SELECT @Command = 'USE [' + DatabaseName + ']; UPDATE STATISTICS ' + SchemaName + '.' + TableName + ' ' + StatName
		+ CASE WHEN @ResampleOverride = 1 THEN ' WITH RESAMPLE ' 
					ELSE  + ' WITH SAMPLE ' + '' 
			END
		+ CASE WHEN @SampleValue IS NULL AND @SampleOverrideValue IS NOT NULL THEN CAST(ISNULL(@SampleOverrideValue,@SampleValue) AS VARCHAR(3)) + '' + ' ' +  ISNULL(@SampleOverrideType,'PERCENT') + ''
				WHEN @SampleValue IS NOT NULL THEN CAST(ISNULL(@SampleOverrideValue,@SampleValue) AS VARCHAR(3)) + '' + ' ' +  ISNULL(@SampleOverrideType,'PERCENT') + '' 
				ELSE '' 
			END
		FROM ##VtblStats S
		WHERE StatID = @Counter;

		--Set the value of @RecordDate to equal the current date and time
		SET @RecordDate = CONVERT(CHAR(23),GETDATE(),121);

		--If the @PrintCommandOnly value has not been set then run the command
		IF @PrintCommandOnly = 0
			BEGIN

				BEGIN TRY

					--Set the start point
					UPDATE ##VtblStats
					SET UpdateStartTime = GETDATE(),
						UpdateSampleValue = ISNULL(@SampleOverrideValue,@SampleValue)
					WHERE StatID = @Counter;

						RAISERROR('%s - Running the command (%s).', 0, 1,@RecordDate,@Command) WITH NOWAIT;

						EXEC(@Command);

						UPDATE ##VtblStats
						SET UpdateEndTime = GETDATE()
						WHERE StatID = @Counter;

				END TRY

				BEGIN CATCH
					RAISERROR('%s - Oops an error occured whilst running the command (%s), please investigate this, the process will now continue.', 0, 1,@RecordDate,@Command) WITH NOWAIT;
				END CATCH

			END

		ELSE
			BEGIN
				RAISERROR('%s - Outputting the command (%s).', 0, 1,@RecordDate,@Command) WITH NOWAIT;
			END;
	
		--Increment the value of @Counter by 1
		SET @Counter = @Counter + 1;
	END
	;

RAISERROR('%s - Statistics update completed successfully.', 0, 1,@RecordDate) WITH NOWAIT;

BEGIN TRY

	--Delete statistic update data older than 7 days
	DELETE FROM dbo.tblStatUpdate
	WHERE UpdateStartTime < DATEADD(D,-7,GETDATE());

	INSERT INTO dbo.tblStatUpdate
	(
		[DatabaseName],
		[TableName],
		[StatName],
		[UpdateStartTime], 
		[UpdateEndTime], 
		[UpdateSampleValue]
	)
	SELECT DatabaseName,
	TableName,
	StatName,
	UpdateStartTime,
	UpdateEndTime,
	UpdateSampleValue
	FROM ##VtblStats;

END TRY

BEGIN CATCH
	RAISERROR('%s - Oops, something went wrong whilst updating the tblStatUpdate table. Statistics have been processed however.', 0, 1,@RecordDate) WITH NOWAIT;
END CATCH
 
--Drop the temp tables which were used by the process
DROP TABLE ##VtblStats;
DROP TABLE ##DatabaseExclusions;
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This procedure is used specifically for the optimisation of statistics.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'PROCEDURE',@level1name=N'UspDatabaseOptimiseStatistics'
GO


