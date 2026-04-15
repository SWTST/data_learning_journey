#=========================================================================
# IndexOptimise.ps1 - Ola Hallengren Maintenance Solution Deployment
# Purpose: Deploy, configure, or remove Ola's database maintenance solution
#          across multiple SQL Server instances with job schedule preservation
#=========================================================================

# Configuration: Enable certificate-based SQL connections and load registered servers
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -Register
$allServers = Get-DbaRegisteredServer -SqlInstance acul021 -Group 'All Servers\Dev'

# Credentials for different authentication methods
$ssa     = Get-Credential -Message "Enter SSA login"
$windows = Get-Credential -Message "Enter Windows login"

# Testing and mode variables
$testServer = 'ADEVWEATSQL1'  # Set to a specific server name for testing, or $null for all targets
$removeMode = $false          # Set to $true to run in removal/cleanup mode instead of deployment

# ========================================================================
# Database check: Verify if Ola maintenance objects exist on each server
# ========================================================================
$spCheck = @"
IF DB_ID('DBA') IS NULL
    SELECT
        @@SERVERNAME AS ServerName,
        0 AS HasIndexSP,
        0 AS HasIndexJob,
        0 AS HasDBCC,
        0 AS HasDBCCJob
ELSE
    SELECT
        @@SERVERNAME AS ServerName,
        CASE WHEN EXISTS (SELECT 1 FROM DBA.sys.procedures WHERE name = 'IndexOptimize') THEN 1 ELSE 0 END AS HasIndexSP,
        CASE WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name LIKE '%IndexOptimi%e%') THEN 1 ELSE 0 END AS HasIndexJob,
        CASE WHEN EXISTS (SELECT 1 FROM DBA.sys.procedures WHERE name = 'DatabaseIntegrityCheck') THEN 1 ELSE 0 END AS HasDBCC,
        CASE WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name LIKE '%DatabaseIntegrityCheck%') THEN 1 ELSE 0 END AS HasDBCCJob
"@


# ========================================================================
# Legacy job check: Query for old maintenance jobs (pre-Ola standardization)
# ========================================================================
$legacyCheck = @"
    USE [MSDB]
    SELECT @@SERVERNAME as [ServerName],
    j.name as [JobName],
    js.step_name as [StepName],
    SUBSTRING(js.command, PATINDEX('%EXEC%',js.command), LEN(js.command)) AS [Command]
    FROM dbo.sysjobs j
    INNER JOIN dbo.sysjobsteps js ON j.job_id = js.job_id
    WHERE j.name LIKE '%Optimisation%'

"@

# Collect legacy job details from all servers and store results
$legacyResults = [System.Collections.Generic.List[object]]::new()
foreach ($server in $allServers) {
    try {
        $r = Invoke-WithFallback -SqlInstance $server.ServerName -Query $legacyCheck
        if ($r) { $legacyResults.AddRange(@($r)) }
    } catch {
        Write-Host "  Failed to query legacy jobs on $($server.ServerName): $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# Group legacy results by server for easier lookup during deployment
$legacyByServer = $legacyResults | Group-Object ServerName

# ========================================================================
# Function: Invoke-WithFallback
# Purpose: Execute SQL query with credential fallback (SSA -> Windows auth)
# ========================================================================
function Invoke-WithFallback {
    param($SqlInstance, $Query)
    try {
        return Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $ssa -Query $Query -EnableException
    } catch {
        Write-Host "  SSA failed on $SqlInstance, trying Windows: $($_.Exception.Message)" -ForegroundColor DarkYellow
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $windows -Query $Query -EnableException
        Write-Host "  Windows succeeded on $SqlInstance" -ForegroundColor DarkYellow
        return $result
    }
}

# ========================================================================
# Function: Parse-LegacyParams
# Purpose: Extract stored procedure parameters from legacy job command strings
# Parses @ParamName = value format and converts to appropriate types
# ========================================================================
function Parse-LegacyParams {
    param($command)
    $params = @{}
    # Match @Param = value patterns
    $matches = [regex]::Matches($command, '@(\w+)\s*=\s*([^,\s]+)')
    foreach ($match in $matches) {
        $key = $match.Groups[1].Value
        $value = $match.Groups[2].Value.Trim("'")
        if ($value -eq 'NULL') { $value = $null }
        elseif ($value -match '^-?\d+$') { $value = [int]$value }
        $params[$key] = $value
    }
    return $params
}

# ========================================================================
# Function: Get-OlaCommand
# Purpose: Convert legacy maintenance parameters to Ola IndexOptimize command
# Maps old parameters to new Ola defaults where possible
# ========================================================================
function Get-OlaCommand {
    param($legacyParams)
    # Default Ola parameters
    $olaParams = @{
        Databases = 'USER_DATABASES'
        FragmentationLevel1 = 5
        FragmentationLevel2 = 30
        FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'
        FragmentationHigh = 'INDEX_REBUILD_ONLINE'
        UpdateStatistics = 'ALL'
        OnlyModifiedStatistics = 'Y'
        LogToTable = 'Y'
    }

    # Mirror legacy settings where possible
    if ($legacyParams.ContainsKey('RetentionWeeks') -and $legacyParams.RetentionWeeks -lt 0) {
        $olaParams.UpdateStatistics = 'ALL'
        $olaParams.OnlyModifiedStatistics = 'N'  # Update all stats if retention is negative (always update?)
    }
    if ($legacyParams.ContainsKey('RebuildHeap') -and $legacyParams.RebuildHeap -eq 1) {
        $olaParams.FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
    }
    # Add more mappings as needed based on legacy params

    # Build command string
    $commandLines = @("EXEC dbo.IndexOptimize")
    foreach ($key in $olaParams.Keys) {
        $value = $olaParams[$key]
        if ($value -is [string] -and $value -notmatch '^\d+$') { $value = "'$value'" }
        $commandLines += "  @$key = $value,"
    }
    $command = ($commandLines -join "`n").TrimEnd(',')
    return $command
}


# ========================================================================
# Function: Remove-OlaMaintenanceSolution
# Purpose: Clean up Ola maintenance solution from a SQL Server instance
# Removes jobs, stored procedures, and optionally the entire DBA database
# ========================================================================
function Remove-OlaMaintenanceSolution {
    param($SqlInstance, $Credential)
    try {
        Write-Host "  Removing Ola maintenance solution from $SqlInstance..." -ForegroundColor Yellow
        
        # Drop SQL Agent jobs related to Ola maintenance
        Get-DbaAgentJob -SqlInstance $SqlInstance -SqlCredential $Credential |
        Where-Object { $_.Name -match 'IndexOptimi[sz]e|DatabaseIntegrityCheck' } |
        Remove-DbaAgentJob -SqlInstance $SqlInstance -SqlCredential $Credential -Confirm:$false
        
        # Drop procedures from DBA database (if it exists)
        if ((Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $Credential -Query "SELECT DB_ID('DBA')" -EnableException).Column1) {
            $dropQueries = @(
                "USE DBA; IF OBJECT_ID('dbo.IndexOptimize') IS NOT NULL DROP PROCEDURE dbo.IndexOptimize;",
                "USE DBA; IF OBJECT_ID('dbo.DatabaseIntegrityCheck') IS NOT NULL DROP PROCEDURE dbo.DatabaseIntegrityCheck;",
                "USE DBA; IF OBJECT_ID('dbo.CommandExecute') IS NOT NULL DROP PROCEDURE dbo.CommandExecute;",
                "USE DBA; IF OBJECT_ID('dbo.CommandLog') IS NOT NULL DROP TABLE dbo.CommandLog;"
            )
            foreach ($query in $dropQueries) {
                Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $Credential -Query $query -EnableException
            }
            
            # Optionally drop DBA database if it's empty (only Ola objects were added)
            $checkDBA = Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $Credential -Query @"
                USE DBA;
                SELECT COUNT(*) AS UserObjects
                FROM sys.objects
                WHERE type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')  -- Tables, views, procedures, functions
                AND name NOT IN ('CommandLog')  -- Exclude Ola's table if it still exists
"@ -EnableException

        }
        
        Write-Host "  Removal completed on $SqlInstance" -ForegroundColor Green
    } catch {
        Write-Host "  Removal failed on $SqlInstance - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ========================================================================
# Main Processing: Check all servers for existing Ola maintenance objects
# ========================================================================
$results = [System.Collections.Generic.List[object]]::new()

foreach ($server in $allServers) {
    Write-Host "Checking $($server.ServerName)" -ForegroundColor Yellow
    try {
        $r = Invoke-WithFallback -SqlInstance $server.ServerName -Query $spCheck
        $results.Add($r)
    } catch {
        Write-Host "  FAILED to query $($server.ServerName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ========================================================================
# Determine target servers based on mode (removal vs deployment)
# ========================================================================
if ($removeMode) {
    # In removal mode, process all servers or the single test server regardless of current object presence.
    $targets = if ($testServer) {
        $allServers | Where-Object { $_.ServerName -eq $testServer }
    } else {
        $allServers
    }
} else {
    # Servers needing deployment (missing SP or Job)
    $targets = $results | Where-Object { $_.HasIndexSP -eq 0 -or $_.HasIndexJob -eq 0 -or $_.HasDBCC -eq 0 -or $_.HasDBCCJob -eq 0}
    if ($testServer) {
        $targets = $targets | Where-Object { $_.ServerName -eq $testServer }
    }
}
$results | format-table -AutoSize
$targets | Format-Table -AutoSize

Write-Host "`n$($targets.Count) server(s) need stuff deployed`n" -ForegroundColor Cyan

# ========================================================================
# Main Deployment Loop: Process each target server
# ========================================================================
foreach ($t in $targets) {
        $instance = $t.ServerName
        $needsIndexSP  = $t.HasIndexSP  -eq 0
        $needsIndexJob = $t.HasIndexJob -eq 0
        $needsDBCC     = $t.HasDBCC     -eq 0
        $needsDBCCJob  = $t.HasDBCCJob  -eq 0
        $needsJobs     = $needsIndexJob -or $needsDBCCJob
        $modeLabel = if ($removeMode) { 'Removing' } else { 'Deploying' }

    Write-Host "$modeLabel to $instance (IndexSP:$needsIndexSP IndexJob:$needsIndexJob DBCC:$needsDBCC DBCCJob:$needsDBCCJob)" -ForegroundColor Yellow
    
    # Try to determine which credential works for this server
    $cred = $null
    try {
        $null = Invoke-DbaQuery -SqlInstance $instance -SqlCredential $ssa -Query "SELECT 1" -EnableException
        $cred = $ssa
    } catch {
        $cred = $windows
    }

    # ====================================================================
    # Removal Mode: Clean up Ola maintenance solution
    # ====================================================================
    if ($removeMode) {
        Remove-OlaMaintenanceSolution -SqlInstance $instance -Credential $cred
        continue
    }

    # ====================================================================
    # Deployment Mode: Install and configure Ola maintenance solution
    # ====================================================================
    try {
        # Ensure DBA database exists (required for Ola procedures)
        Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -EnableException -Query @"
        IF DB_ID('DBA') IS NULL CREATE DATABASE DBA;
"@

        # Capture existing backup job details before installation
        # Check both (DBA) prefixed names and Ola default names in case of partial previous runs
        $backupJobs = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred |
            Where-Object { $_.Name -like '*DatabaseBackup*' } |
            Sort-Object Name -Unique

        # If both (DBA) and default-named versions exist for the same suffix, prefer the (DBA) one
        $backupByType = @{}
        foreach ($bj in $backupJobs) {
            $suffix = $bj.Name -replace '^\(DBA\) - ', ''
            if (-not $backupByType.ContainsKey($suffix) -or $bj.Name -like '(DBA) -*') {
                $backupByType[$suffix] = $bj
            }
        }
        $backupJobs = $backupByType.Values

        # Extract job schedules and steps for later restoration
        $backupDetails = $backupJobs | ForEach-Object {
            $schedules = Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -Query @"
                USE msdb;
                SELECT s.name, s.enabled, s.freq_type, s.freq_interval,
                       s.freq_subday_type, s.freq_subday_interval,
                       s.freq_relative_interval, s.freq_recurrence_factor,
                       s.active_start_date, s.active_start_time,
                       s.active_end_date, s.active_end_time
                FROM dbo.sysjobs j
                JOIN dbo.sysjobschedules js ON j.job_id = js.job_id
                JOIN dbo.sysschedules s ON js.schedule_id = s.schedule_id
                WHERE j.name = '$($_.Name)'
"@ -EnableException
            $steps = Get-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred -Job $_.Name | Select-Object ID, Name, Subsystem, Database, Command, OnSuccessAction, OnFailAction, RetryAttempts, RetryInterval
            # Normalise the saved name to (DBA) convention for restore later
            $savedName = if ($_.Name -like '(DBA) -*') { $_.Name } else { "(DBA) - $($_.Name)" }
            [PSCustomObject]@{
                Name        = $savedName
                Description = $_.Description
                Enabled     = $_.Enabled
                Category    = $_.Category
                Owner       = $_.Owner
                Schedules   = @($schedules)
                Steps       = $steps
            }
        }

        if ($backupDetails) {
            Write-Host "  Captured settings for $(@($backupDetails).Count) backup job(s)" -ForegroundColor Cyan
        }

        # Remove ALL existing Ola jobs before clean install (avoids name collisions and ensures fresh state)
        $olaJobs = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred | Where-Object {
            $_.Name -match 'IndexOptimi[sz]e|DatabaseIntegrityCheck|DatabaseBackup|CommandLog Cleanup|Output File Cleanup|sp_delete_backuphistory|sp_purge_jobhistory' -or
            $_.Name -match '^\(DBA\) - (IndexOptimi[sz]e|DatabaseIntegrityCheck|DatabaseBackup|CommandLog Cleanup|Output File Cleanup|sp_delete_backuphistory|sp_purge_jobhistory)'
        }
        foreach ($oj in $olaJobs) {
            Remove-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -InputObject $oj -Confirm:$false
            Write-Host "  Removed existing job '$($oj.Name)' before reinstall" -ForegroundColor Yellow
        }

        # Install Ola's complete maintenance solution with all jobs
        # The -Solution All parameter installs IndexOptimize, DatabaseIntegrityCheck, and DatabaseBackup
        # The -InstallJobs parameter creates the associated SQL Agent jobs
        Install-DbaMaintenanceSolution `
            -SqlInstance   $instance `
            -SqlCredential $cred `
            -Database      DBA `
            -Solution      All `
            -InstallJobs `
            -LogToTable `
            -ReplaceExisting `
            -EnableException

        # Rename Ola's default job names to company naming convention: (DBA) - [JobName]
        $jobRenames = @{
            'IndexOptimize - USER_DATABASES'                  = '(DBA) - IndexOptimise - USER_DATABASES'
            'DatabaseIntegrityCheck - USER_DATABASES'         = '(DBA) - DatabaseIntegrityCheck - USER_DATABASES'
            'DatabaseIntegrityCheck - SYSTEM_DATABASES'       = '(DBA) - DatabaseIntegrityCheck - SYSTEM_DATABASES'
            'DatabaseBackup - USER_DATABASES - FULL'          = '(DBA) - DatabaseBackup - USER_DATABASES - FULL'
            'DatabaseBackup - USER_DATABASES - DIFF'          = '(DBA) - DatabaseBackup - USER_DATABASES - DIFF'
            'DatabaseBackup - USER_DATABASES - LOG'           = '(DBA) - DatabaseBackup - USER_DATABASES - LOG'
            'DatabaseBackup - SYSTEM_DATABASES - FULL'        = '(DBA) - DatabaseBackup - SYSTEM_DATABASES - FULL'
            'Output File Cleanup'                             = '(DBA) - Output File Cleanup'
            'sp_delete_backuphistory'                         = '(DBA) - sp_delete_backuphistory'
            'sp_purge_jobhistory'                             = '(DBA) - sp_purge_jobhistory'
            'CommandLog Cleanup'                              = '(DBA) - CommandLog Cleanup'
        }
        foreach ($oldName in $jobRenames.Keys) {
            $job = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred | Where-Object { $_.Name -eq $oldName }
            if ($job) {
                $newName = $jobRenames[$oldName]
                Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -Query "EXEC msdb.dbo.sp_update_job @job_name = N'$oldName', @new_name = N'$newName'" -EnableException
                Write-Host "  Renamed job '$oldName' -> '$newName'" -ForegroundColor Green
            }
        }

        # Restore previously captured backup job settings (schedules, steps, etc.)
        foreach ($detail in $backupDetails) {
            $jobName = $detail.Name  # already in (DBA) convention from capture step
            $backupJob = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -Job $jobName

            if (-not $backupJob) {
                Write-Host "  WARNING: Could not find backup job '$jobName' after install on $instance" -ForegroundColor Red
                continue
            }

            # Set job properties (enabled/disabled, category, owner)
            if ($detail.Enabled) {
                Set-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -Job $jobName `
                    -Description $detail.Description -Enabled `
                    -Category $detail.Category -OwnerLogin $detail.Owner
            } else {
                Set-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -Job $jobName `
                    -Description $detail.Description -Disabled `
                    -Category $detail.Category -OwnerLogin $detail.Owner
            }

            # Restore job schedules (frequency, timing, etc.)
            if ($detail.Schedules -and @($detail.Schedules).Count -gt 0) {
                # Remove the default schedules that Ola created during installation
                $currentSchedules = Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -Query @"
                    SELECT s.schedule_id
                    FROM msdb.dbo.sysjobs j
                    JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
                    JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
                    WHERE j.name = N'$jobName'
"@ -EnableException
                foreach ($cs in $currentSchedules) {
                    Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -Query "EXEC msdb.dbo.sp_delete_schedule @schedule_id = $($cs.schedule_id), @force_delete = 1" -EnableException
                }

                # Recreate the original schedules with their saved parameters
                foreach ($sched in $detail.Schedules) {
                    if (-not $sched) { continue }
                    Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -Query @"
                        EXEC msdb.dbo.sp_add_jobschedule
                            @job_name = N'$jobName',
                            @name = N'$($sched.name)',
                            @enabled = $($sched.enabled),
                            @freq_type = $($sched.freq_type),
                            @freq_interval = $($sched.freq_interval),
                            @freq_subday_type = $($sched.freq_subday_type),
                            @freq_subday_interval = $($sched.freq_subday_interval),
                            @freq_relative_interval = $($sched.freq_relative_interval),
                            @freq_recurrence_factor = $($sched.freq_recurrence_factor),
                            @active_start_date = $($sched.active_start_date),
                            @active_start_time = $($sched.active_start_time),
                            @active_end_date = $($sched.active_end_date),
                            @active_end_time = $($sched.active_end_time)
"@ -EnableException
                }
            }

            # Restore job step commands — match by position since names may differ after reinstall
            $currentSteps = @(Get-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred -Job $jobName)
            $savedSteps = @($detail.Steps)

            
            


            if($currentSteps.Count -eq 1 -and $savedSteps.count -eq 1){

                $currentStep = $currentSteps[0]
                $savedStep   = $savedSteps[0]

                $currentStepName = if ($currentStep.Name) { $currentStep.Name } else { $currentStep.StepName }

                Write-Host "    Restoring step '$currentStepName' -> '$($savedStep.Name)'" -ForegroundColor DarkGray

                Set-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred `
                            -Job $jobName `
                            -StepName $currentStepName `
                            -NewName $savedStep.Name `
                            -Command $savedStep.Command `
                            -Database $savedStep.Database `
                            -Force
                } else {
                    Write-Host("WARNING: Expected exactly 1 current step and 1 saved step for '$jobName' on $instance. Current=$($currentSteps.Count), Saved=$($savedSteps.Count)") -ForegroundColor Red
                }


            <#-----------------------------------------------------------------------------------------------------------
            for ($i = 0; $i -lt $savedSteps.Count; $i++) {
                $savedStep = $savedSteps[$i]
                $targetStep = if ($i -lt $currentSteps.Count) { $currentSteps[$i] } else { $null }
                if ($savedStep -and $targetStep) {
                    # Get the temporary target step name as created by Ola install
                    $stepName = $targetStep.Name

                    # Update the existing step command and database
                    Set-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred `
                        -Job $jobName `
                        -StepName $stepName `
                        -Command $savedStep.Command `
                        -Database $savedStep.Database `
                        -Force

                    # Rename the step back to the original name
                    if ($savedStep.Name) {
                        
                    $renameQuery = @"
                    EXEC msdb.dbo.sp_update_jobstep
                        @job_name     = N'$jobName',
                        @step_id      = $($targetStep.ID),
                        @step_name = N'$($savedStep.Name)'
"@

                        Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -Query $renameQuery -EnableException
                        $stepName = $savedStep.Name
                    }
           
                    Write-Host "    Restored step '$stepName' command" -ForegroundColor DarkCyan
                }
            }
             ------------------------------------------------------------------------------------------------------------#>
            Write-Host "  Restored settings for backup job '$jobName' on $instance" -ForegroundColor Green
        }

        Write-Host "  Deployed to $instance" -ForegroundColor Green

        # Check for legacy jobs and mirror their settings if found
        $legacyGroup = $legacyByServer | Where-Object { $_.Name -eq $instance }
        $olaCommand = $null
        if ($legacyGroup) {
            Write-Host "  Legacy optimisation jobs found on $instance, mirroring settings..." -ForegroundColor Cyan
            # Parse parameters from legacy job steps and merge them
            $allLegacyParams = @{}
            foreach ($job in $legacyGroup.Group) {
                $params = Parse-LegacyParams $job.Command
                foreach ($key in $params.Keys) {
                    $allLegacyParams[$key] = $params[$key]  # Merge params, last wins if duplicates
                }
            }
            $olaCommand = Get-OlaCommand $allLegacyParams
            Write-Host "  Mirrored command generated for $instance" -ForegroundColor Green
        }

        # Disable new maintenance jobs by default (they'll be enabled/configured below)
        Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred |
        Where-Object { $_.Name -match 'IndexOptimi[sz]e|DatabaseIntegrityCheck' } |
        Set-DbaAgentJob -Disabled

        # Configure IndexOptimize job with mirrored settings or default parameters
        $indexJob = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred |
                    Where-Object Name -match 'IndexOptimi[sz]e - USER_DATABASES'
        if ($indexJob) {
            # Use mirrored command if legacy job was found, otherwise use defaults
            $commandToUse = if ($olaCommand) { $olaCommand } else {
                @"
EXEC dbo.IndexOptimize
  @Databases = 'USER_DATABASES',
  @FragmentationLevel1 = 50,
  @FragmentationLevel2 = 80,
  @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE',
  @FragmentationHigh = 'INDEX_REBUILD_ONLINE',
  @UpdateStatistics = 'ALL',
  @OnlyModifiedStatistics = 'Y',
  @LogToTable = 'Y';
"@
            }

            $indexStep = Get-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred -Job $indexJob.Name | Select-Object -First 1
            $indexStepName = if ($indexStep.Name) { $indexStep.Name } elseif ($indexStep.StepName) { $indexStep.StepName } else { $null }

            if ($indexStepName) {
                Set-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred `
                    -Job $indexJob.Name `
                    -StepName $indexStepName `
                    -Command $commandToUse
            } else {
                # No existing step found — create one
                Set-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred `
                    -Job $indexJob.Name `
                    -StepName 'IndexOptimize - USER_DATABASES' `
                    -Command $commandToUse `
                    -Database DBA `
                    -Force
            }
            Write-Host "  Configured IndexOptimize job on $instance" -ForegroundColor Green
        }

        <# Disable legacy jobs if they exist
        if ($legacyGroup) {
            Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred |
            Where-Object Name -like '*(DBA) - Optimisation*' |
            ForEach-Object {
                Set-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -Job $_.Name -Disabled
                Write-Host "  Disabled legacy job '$($_.Name)' on $instance" -ForegroundColor Yellow
            }
        }
        #>

    } catch {
        Write-Host "FAILED on $instance : $($_.Exception.Message)" -ForegroundColor Red
    }

    }