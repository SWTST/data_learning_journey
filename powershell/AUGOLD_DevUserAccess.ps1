# ---------------------------------------------------------
# BASE CONFIG
# ---------------------------------------------------------
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -Register

$myCreds = Get-Credential -UserName "" -Message "Input SSA Login"
$AUGoldServers = Get-DbaRegServer -SqlInstance acul021 -Group 'All Servers\AUGold'

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
# ACCESS RULES (single source of truth — all UPPERCASE)
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
            IncludeServers = { param($server) $server -in @('AGSQLDEVV71','AGSQLUATV7') }
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
        Database = $db.Name
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


