#=========

#Claude

#=========

Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -Register
$allServers = Get-DbaRegisteredServer -SqlInstance acul021 -Group 'All Servers\Dev'

$ssa     = Get-Credential -Message "Enter SSA login"
$windows = Get-Credential -Message "Enter Windows login"

# Add these new variables for testing
$testServer = 'ADEVWEATSQL1'  # Set to a specific server name for testing, or $null for all targets
$removeMode = $false     # Set to $true to run in removal/cleanup mode instead of deployment

$spCheck = @"
IF DB_ID('DBA') IS NULL
    SELECT @@SERVERNAME AS ServerName, 0 AS HasSP, 0 AS HasJob
ELSE
    SELECT
        @@SERVERNAME AS ServerName,
        CASE WHEN EXISTS (SELECT 1 FROM DBA.sys.procedures WHERE name = 'IndexOptimize') THEN 1 ELSE 0 END AS HasIndexSP,
        CASE WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name LIKE '%IndexOptimize%') THEN 1 ELSE 0 END AS HasIndexJob,
        CASE WHEN EXISTS (SELECT 1 FROM DBA.sys.procedures WHERE name = 'DatabaseIntegrityCheck') THEN 1 ELSE 0 END AS HasDBCC,
        CASE WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name LIKE '%DatabaseIntegrityCheck%') THEN 1 ELSE 0 END AS HasDBCCJob
"@

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

# Collect legacy job details
$legacyResults = [System.Collections.Generic.List[object]]::new()
foreach ($server in $allServers) {
    try {
        $r = Invoke-WithFallback -SqlInstance $server.ServerName -Query $legacyCheck
        if ($r) { $legacyResults.AddRange(@($r)) }
    } catch {
        Write-Host "  Failed to query legacy jobs on $($server.ServerName): $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# Group legacy results by server
$legacyByServer = $legacyResults | Group-Object ServerName

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

function Remove-OlaMaintenanceSolution {
    param($SqlInstance, $Credential)
    try {
        Write-Host "  Removing Ola maintenance solution from $SqlInstance..." -ForegroundColor Yellow
        
        # Drop jobs
        Get-DbaAgentJob -SqlInstance $SqlInstance -SqlCredential $Credential |
        Where-Object { $_.Name -match 'IndexOptimize|DatabaseIntegrityCheck' } |
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

foreach ($t in $targets) {
        $instance = $t.ServerName
        $needsIndexSP  = $t.HasIndexSP  -eq 0
        $needsIndexJob = $t.HasIndexJob -eq 0
        $needsDBCC     = $t.HasDBCC     -eq 0
        $needsDBCCJob  = $t.HasDBCCJob  -eq 0
        $needsJobs     = $needsIndexJob -or $needsDBCCJob
        $modeLabel = if ($removeMode) { 'Removing' } else { 'Deploying' }

    Write-Host "$modeLabel to $instance (IndexSP:$needsIndexSP IndexJob:$needsIndexJob DBCC:$needsDBCC DBCCJob:$needsDBCCJob)" -ForegroundColor Yellow
    
    # Pick credential that works
    $cred = $null
    try {
        $null = Invoke-DbaQuery -SqlInstance $instance -SqlCredential $ssa -Query "SELECT 1" -EnableException
        $cred = $ssa
    } catch {
        $cred = $windows
    }

    if ($removeMode) {
        Remove-OlaMaintenanceSolution -SqlInstance $instance -Credential $cred
        continue
    }

    try {
        # Ensure DBA database exists
        Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -EnableException -Query @"
        IF DB_ID('DBA') IS NULL CREATE DATABASE DBA;
"@

        # Capture existing backup job details before installation
        $backupJobs = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred | Where-Object { $_.Name -like '(DBA) - DatabaseBackup*' }

        # Remove duplicate backup jobs from earlier runs and preserve the first instance by name
        foreach ($jobGroup in $backupJobs | Group-Object Name) {
            if ($jobGroup.Count -gt 1) {
                $duplicates = $jobGroup.Group | Select-Object -Skip 1
                foreach ($dup in $duplicates) {
                    Remove-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -InputObject $dup -Confirm:$false
                    Write-Host "  Removed duplicate backup job '$($dup.Name)'" -ForegroundColor Yellow
                }
            }
        }

        $backupJobs = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred | Where-Object { $_.Name -like '(DBA) - DatabaseBackup*' }
        $backupDetails = $backupJobs | ForEach-Object {
            $schedules = Invoke-DbaQuery -SqlInstance $instance -SqlCredential $cred -Query @"
                USE msdb;
                SELECT s.schedule_id, s.name, s.enabled, s.freq_type, s.freq_interval, s.freq_subday_type, s.freq_subday_interval,
                       s.active_start_date, s.active_start_time, s.active_end_date, s.active_end_time
                FROM dbo.sysjobs j
                JOIN dbo.sysjobschedules js ON j.job_id = js.job_id
                JOIN dbo.sysschedules s ON js.schedule_id = s.schedule_id
                WHERE j.name = '$($_.Name)'
"@ -EnableException
            $scheduleIds = @($schedules | Select-Object -ExpandProperty schedule_id)
            $steps = Get-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred -Job $_.Name | Select-Object StepName, Subsystem, Database, Command, OnSuccessAction, OnFailAction, RetryAttempts, RetryInterval
            [PSCustomObject]@{
                Name = $_.Name
                Description = $_.Description
                Enabled = $_.Enabled
                Category = $_.Category
                Owner = $_.Owner
                ScheduleIds = $scheduleIds
                Steps = $steps
            }
        }

        # Install Ola's solution — do not install backup jobs so existing backup-to-URL jobs are preserved
        $solutions = @()
        if ($needsIndexSP -or $needsIndexJob) { $solutions += 'IndexOptimize' }
        if ($needsDBCC -or $needsDBCCJob) { $solutions += 'IntegrityCheck' }
        if (-not $solutions) { $solutions = 'IndexOptimize','IntegrityCheck' }

        Install-DbaMaintenanceSolution `
            -SqlInstance   $instance `
            -SqlCredential $cred `
            -Database      DBA `
            -Solution      $solutions `
            -InstallJobs `
            -LogToTable `
            -ReplaceExisting `
            -EnableException

        # Restore backup job settings and step commands
        foreach ($detail in $backupDetails) {
            $backupJob = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -Job $detail.Name
            if ($backupJob) {
                Set-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -Job $detail.Name -Description $detail.Description -Enabled $detail.Enabled -Category $detail.Category -Owner $detail.Owner

                if ($detail.ScheduleIds -and $detail.ScheduleIds.Count -gt 0) {
                    Set-DbaAgentJob -SqlInstance $instance -SqlCredential $cred -Job $detail.Name -ScheduleId ([int[]]$detail.ScheduleIds)
                }

                foreach ($step in $detail.Steps) {
                    if ($step -and $step.StepName) {
                        Set-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred `
                            -Job $detail.Name `
                            -StepName $step.StepName `
                            -Command $step.Command `
                            -Database $step.Database `
                            -Force
                    }
                }

                Write-Host "  Restored settings for backup job '$($detail.Name)' on $instance" -ForegroundColor Green
            }
        }

        Write-Host "  Deployed to $instance" -ForegroundColor Green

        # Check for legacy jobs and mirror settings if possible
        $legacyGroup = $legacyByServer | Where-Object { $_.Name -eq $instance }
        $olaCommand = $null
        if ($legacyGroup) {
            Write-Host "  Legacy optimisation jobs found on $instance, mirroring settings..." -ForegroundColor Cyan
            # Parse parameters from legacy job steps
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

        Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred |
        Where-Object { $_.Name -match 'IndexOptimize|DatabaseIntegrityCheck' } |
        Set-DbaAgentJob -Disabled

        # Configure IndexOptimize job with mirrored or default settings
        $indexJob = Get-DbaAgentJob -SqlInstance $instance -SqlCredential $cred |
                    Where-Object Name -match 'IndexOptimize - USER_DATABASES'
        if ($indexJob) {
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

            $indexStepName = (Get-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred -Job $indexJob.Name | Select-Object -First 1 -ExpandProperty StepName)
            if (-not $indexStepName) { $indexStepName = 'Index Maintenance' }

            Set-DbaAgentJobStep -SqlInstance $instance -SqlCredential $cred `
                -Job $indexJob.Name `
                -StepName $indexStepName `
                -Command $commandToUse
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

