﻿param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$ConfigFile,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$EnvironmentFile,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$IdentityPath
)

function CheckForCredentials
{
    #Check For Rubrik Credentials
    $CredFile = $IdentityPath + $Environment.rubrikCred
    If (-not (Test-Path -Path $CredFile))
    {
        Write-Host -ForegroundColor Yellow "$CredFile does not exist"
        $null = Read-Host "Press any key to continue and create the appropriate credential files"
        CreateCredentialFile -FilePath $CredFile -Message "Please enter a username and password with access to the Rubrik cluster..."
    }

    #Check for SQL Credentials
    foreach ($database in $config.databases)
    {
        $CredFile = $IdentityPath + $database.TargetDBSQLCredentials
        If (-not (Test-Path -Path $CredFile))
        {
            Write-Host -ForegroundColor Yellow "$CredFile does not exist"
            $null = Read-Host "Press any key to continue and create the appropriate credential files"
            CreateCredentialFile -FilePath $CredFile -Message "Please enter a SQL username and password with access to $($database.TargetDBServer).  ***NOTE*** This must be a SQL account - Domain accounts are not supported."
        }
    }

}

function CreateCredentialFile ($FilePath, $Message)
{
    $Credential = Get-Credential -Message $Message
    $Credential | Export-Clixml -Path ($FilePath)
}
clear

#Import needed modules
Import-Module SQLServer
Import-Module Rubrik


$script:Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
$script:Environment = Get-Content -Path $EnvironmentFile | ConvertFrom-Json
# If a trailing backslash is omitted, this will make sure it's added to correct for future path + filename activities
if ($IdentityPath.Substring($IdentityPath.Length - 1) -ne '\') {
    $script:IdentityPath += '\'
}

CheckForCredentials

$Credential = Import-Clixml -Path ($IdentityPath + $Environment.rubrikCred)
$null = Connect-Rubrik -Server $Environment.rubrikServer -Credential $Credential
Write-Verbose -Message "Rubrik Status: Connected to $($rubrikConnection.server)" -Verbose

foreach ($database in $Config.databases)
{
    #Get Source DB Info
    $db = Get-RubrikDatabase -HostName $database.SourceDBServer -Instance $database.SourceDBInstance -Database $database.SourceDBName
    
    #get HostID of Target
    $TargetSQLHostId = (Get-RubrikHost -Name $database.TargetDBServer).id
    
    #get instance id of target
    $TargetSQLInstanceId = ((Invoke-RubrikRESTCall -Endpoint "mssql/instance" -Method GET -Query  (New-Object -TypeName PSObject  -Property @{"root_id"="$TargetSQLHostId"})).Data | where { $_.name -eq "$($database.TargetDBInstance)"}).id
    
    #Live Mount latest full backup
    $request = New-RubrikDatabaseMount -id $db.id -targetInstanceId $TargetSQLInstanceId -mountedDatabaseName `
                $database.TargetDBName -recoveryDateTime (Get-date (Get-RubrikDatabase -id $db.id).latestRecoveryPoint) -Confirm:$false
    #wait for task
    $id = $request.id
    while ((Get-RubrikRequest -id $id -type "mssql").status -eq "RUNNING") { Start-Sleep -Seconds 1 }

    # check if instance is MSSQLSERVER (default instance) - if so don't connect with instance name.
    if ($database.TargetDBInstance -eq "MSSQLSERVER") {$sqlconnection = $database.TargetDBServer}
    else { $sqlconnection = $database.TargetDBServer + "\" + $database.TargetDBInstance }
    
    #Get Credentials for SQL
    $CredFile = $IdentityPath + $database.TargetDBSQLCredentials
    $Creds = Import-Clixml -Path $CredFile

    #Get Logical Filename for Primary File
    $results = Invoke-Sqlcmd -Query "SELECT name FROM sys.database_files WHERE type_desc = 'ROWS';" -ServerInstance `
        $sqlconnection -Database $database.TargetDBName -Credential $Creds
    $logicalfilename = $results.name

    #Take database snapshot
    $dbsnapshot = $database.TargetDBName + "_SS"
    $snapshotfilename = $database.PathToStoreSnapshot + $dbsnapshot + "1.ss"
    $results = Invoke-Sqlcmd -Query "CREATE DATABASE [$dbsnapshot] ON (name=$logicalfilename,filename='$snapshotfilename') AS SNAPSHOT OF $($database.TargetDBName)" -ServerInstance `
        $sqlconnection -Database $database.TargetDBName -Credential $Creds

    #Run dbcc checkdb
    $results = Invoke-Sqlcmd -Query "dbcc checkdb(); select @@spid as SessionID;" -ServerInstance `
        $sqlconnection -Database $dbsnapshot -Credential $Creds
    $spid = "spid" + $results.sessionID
    $logresults = Get-SqlErrorLog -ServerInstance "$sqlconnection" -Credential $Creds | where-object { $_.Source -eq $spid } | ` 
        Sort-Object -Property Date -Descending | Select -First 1

    # Get rid of snapshot
    $results = Invoke-Sqlcmd -Query "DROP DATABASE [$dbsnapshot]" -ServerInstance `
        $sqlconnection -Database "master" -Credential $Creds

    #Get rid of live mount
    $request = Get-RubrikDatabaseMount -MountedDatabaseName $database.TargetDBName | Remove-RubrikDatabaseMount -Confirm:$false

    Write-Host $logresults.Text

}
