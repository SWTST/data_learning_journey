# ---------------------------------------------------------
# BASE CONFIG
# ---------------------------------------------------------
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -Register

$myCreds = Get-Credential -UserName "" -Message "Input your SSA Login"
$AUGoldServers = Get-DbaRegServer -SqlInstance acul021 -Group 'All Servers\AUGold' -ExcludeServerName "adc-uks-db1.augold.local"



# List of target databases (UPPERCASE)
$targetDatabases = @(
    'EXAMPLEDATA',
    'AUGOLDV2DW',
    'AUGOLDDIGITALSERVICES',
    'AUGOLDSERVICESDB',
    'EXAMPLESHREDDERSTAGING',
    'DCTANYWHERE',
    'SHREDDERCONFIG'
)

# ---------------------------------------------------------
# QUERY ALL MATCHING DATABASES
# ---------------------------------------------------------
$dbQuery = @"
USE master
SELECT @@SERVERNAME AS ServerName, name
FROM sys.databases
WHERE name IN ('$(($targetDatabases -join "','"))')
"@

$AllDatabases = Invoke-DbaQuery -SqlInstance $AUGoldServers.ServerName -SqlCredential $myCreds -Query $dbQuery

# ---------------------------------------------------------
# ACCESS RULES (single source of truth � all UPPERCASE)
# R = 1, RW = 2, RW + DDL = 3
# ---------------------------------------------------------
$AccessRules = @{

    DCDev = @{
        IncludeServers = { param($server) $server -ne 'ADC-USE-DB1' }
        Databases = @{
            'EXAMPLEDATA'        = 2
            'AUGOLDV2DW'         = 1
            'AUGOLDSERVICESDB'   = 1
        }
    }

    NetDev = @{
        IncludeServers = { param($server) $server -in @('AGSQLDEVV7','AGSQLUATV7') }
        Databases = @{}
    }

    DBDev = @(
        @{
            IncludeServers = { param($server) $server -in @('AGSQLDEVV7','AGSQLUATV7') }
            Databases = $targetDatabases
            Level = 3
        },
        @{
            IncludeServers = { param($server) $server -in @('ADC-USE-DB1','ADC-USE-UAT-DB1') }
            Databases = $targetDatabases
            Level = 1
        },
        @{
            IncludeServers = { param($server) $server -eq 'ADC-USE-PM-DB1' }
            Databases = $targetDatabases
            Level = 2
        }
    )

    QA = @{
        IncludeServers = { param($server) $server -ne 'ADC-USE-DB1' }
        Databases = @{
            'EXAMPLEDATA'            = 1
            'AUGOLDV2DW'             = 1
            'AUGOLDSERVICESDB'       = 1
            'EXAMPLESHREDDERSTAGING' = 1
        }
    }
}

# Build NetDev DB mapping
foreach ($dbName in $targetDatabases) {
    $AccessRules.NetDev.Databases[$dbName] = 2
}

# ---------------------------------------------------------
# BUILD ACCESS MATRIX OBJECTS
# ---------------------------------------------------------
$accessMatrix = foreach ($db in $AllDatabases) {
    [PSCustomObject]@{
        Server   = $db.ServerName
        Database = $db.Name.ToUpper()
        DatabaseRaw = $db.Name 
        DCDev    = 0
        NetDev   = 0
        DBDev    = 0
        QA       = 0
    }
}

# ---------------------------------------------------------
# NORMALISE SERVER + DATABASE NAMES (critical)
# ---------------------------------------------------------
foreach ($row in $accessMatrix) {
    # UPPERCASE server name, strip domain/instance
    $row.Server = $row.Server.Split('\')[0].Split('.')[0].ToUpper()

    # UPPERCASE database name
    $row.Database = $row.Database.ToUpper()
}

# ---------------------------------------------------------
# APPLY ACCESS RULES
# ---------------------------------------------------------
foreach ($row in $accessMatrix) {

    # --- DCDev ---
    if ($AccessRules.DCDev.IncludeServers.Invoke($row.Server)) {
        if ($AccessRules.DCDev.Databases.ContainsKey($row.Database)) {
            $row.DCDev = $AccessRules.DCDev.Databases[$row.Database]
        }
    }

    # --- NetDev ---
    if ($AccessRules.NetDev.IncludeServers.Invoke($row.Server)) {
        if ($AccessRules.NetDev.Databases.ContainsKey($row.Database)) {
            $row.NetDev = 2
        }
    }

    # --- DBDev ---
    foreach ($rule in $AccessRules.DBDev) {
        if ($rule.IncludeServers.Invoke($row.Server)) {
            if ($row.Database -in $rule.Databases) {
                $row.DBDev = $rule.Level
            }
        }
    }

    # --- QA ---
    if ($AccessRules.QA.IncludeServers.Invoke($row.Server)) {
        if ($AccessRules.QA.Databases.ContainsKey($row.Database)) {
            $row.QA = $AccessRules.QA.Databases[$row.Database]
        }
    }
}

# ---------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------
$accessMatrix | Format-Table -AutoSize


#========================
# END OF ACCESS MATRIX
#========================


<#
AIMS

1. Check for server level user using short username
    I. If not there then New-DbaLogin.
    II. If there then skip and alert.
2. Check for DB user using short username
    I. If not there then New-DbUser
    II. If there then skip and alert
3. Use value in AccessMatrix to determine the level of access the user needs on each DB
4. Give the user specific database level access
#>

$userCreds = Get-Credential -UserName "" -Message "Input users SSA Login"
$userName = $userCreds.UserName
$securePwd = $userCreds.Password

[int]$userGroup = Read-Host("Which user group will this login be a part of? `n  DCDev: 1`n  NetDev: 2`n  DBDev: 3`n  QA: 4`nPlease enter a number between 1 and 4.")


function Assign-Access {
    param(
        [int]$level,
        [string]$login,
        [string]$sqlInstance,
        [string]$databaseName
    )
    if ($level -eq 1){
        Add-DbaDbRoleMember -SqlInstance $sqlInstance -SqlCredential $myCreds -Database $databaseName -Role db_datareader -Member $login -Confirm:$false
    }
    if ($level -eq 2){
        Add-DbaDbRoleMember -SqlInstance $sqlInstance -SqlCredential $myCreds -Database $databaseName -Role db_datareader -Member $login -Confirm:$false
        Add-DbaDbRoleMember -SqlInstance $sqlInstance -SqlCredential $myCreds -Database $databaseName -Role db_datawriter -Member $login -Confirm:$false
    }
    if ($level -eq 3){
        Add-DbaDbRoleMember -SqlInstance $sqlInstance -SqlCredential $myCreds -Database $databaseName -Role db_datareader -Member $login -Confirm:$false
        Add-DbaDbRoleMember -SqlInstance $sqlInstance -SqlCredential $myCreds -Database $databaseName -Role db_datawriter -Member $login -Confirm:$false
        Add-DbaDbRoleMember -SqlInstance $sqlInstance -SqlCredential $myCreds -Database $databaseName -Role db_ddladmin -Member $login -Confirm:$false
    }
}
    
# -----------------------------
# CREATE USERS / GRANT ACCESS
# -----------------------------

# Map the selected group to the property name in the matrix
$levelPropByGroup = @{
    1 = 'DCDev'
    2 = 'NetDev'
    3 = 'DBDev'
    4 = 'QA'
}
$levelProp = $levelPropByGroup[$userGroup]
if (-not $levelProp) {
    throw "Invalid user group selection: $userGroup (expected 1..4)"
}

foreach ($server in $AUGoldServers) {

    $serverInstance = $server.ServerName
    $serverShort    = ($serverInstance -split '[\\.]')[0].ToUpper()

    # All rows for this server
    $rowsForServer = $accessMatrix | Where-Object { $_.Server -eq $serverShort }

    # Only rows where the chosen group has access > 0
    $eligibleRows = $rowsForServer | Where-Object { $_.$levelProp -gt 0 }

    if (-not $eligibleRows) {
        Write-Host "Skipping $serverShort � no $levelProp access required" -ForegroundColor DarkGray
        continue
    }

    # Ensure login exists (SQL login)
    $loginExists = Get-DbaLogin -SqlInstance $serverInstance -SqlCredential $myCreds `
                   -Login $userName -ErrorAction SilentlyContinue
    if (-not $loginExists) {
        New-DbaLogin -SqlInstance $serverInstance -SqlCredential $myCreds `
            -Login $userName -SecurePassword $securePwd -ErrorAction Stop
        Write-Host "Login created on $serverShort" -ForegroundColor Cyan
    }
    else {
        Write-Host "Login already exists on $serverShort" -ForegroundColor Yellow
    }

    foreach ($row in $eligibleRows) {
        $level = [int]$row.$levelProp
        if ($level -le 0) { continue }

        # Ensure DB user exists
        $dbUser = Get-DbaDbUser -SqlInstance $serverInstance -SqlCredential $myCreds `
                  -Database $row.DatabaseRaw -User $userName -ErrorAction SilentlyContinue | Where-Object {$_.Name -eq $userName}
        if (-not $dbUser) {
            New-DbaDbUser -SqlInstance $serverInstance -SqlCredential $myCreds `
                -Database $row.DatabaseRaw -Login $userName -Username $userName -Force -ErrorAction Stop 
                Write-Host "User created on $($row.DatabaseRaw)" -ForegroundColor Cyan
        }

        # Grant roles for the selected level
        Assign-Access -sqlInstance $serverInstance -databaseName $row.Database -login $userName -level $level
    }
}