# DBCC CHECKDB With Rubrik Live Mount

This project is designed to provide the framework to perform dbcc checkdb database health checks utilizing Rubrik's Live Mount Technology. By utilizing a Live Mounted database, organizations are able to offload all of the CPU and Disk I/O associated with DBCC CHECKDB.

## Prerequisites
 - [Rubrik Powershell Module](https://github.com/rubrikinc/PowerShell-Module)
 - SQL Server Powershell Module (Install-Module -Name SqlServer)
 
## Configuration

There are three main points of configuration: Environment JSON files, Config JSON files, and Identity XML files.

### Environment JSON File

The Environment folder contains a JSON file that describe the Rubrik Clusterinformation. A sample configuration looks like:
```javascript
{
    "rubrikServer": "172.17.28.11",
    "rubrikCred": "rubrikCred.xml"
}
```
### Config JSON File

The Config folder contains JSON file (databases.json) that describe the source database information (Database to Live Mount) and the target database information (SQL Server/Database to Live Mount to). 

Note: TargetDBServer is the name of the SQL Server within the Rubrik CDM while TargetDBConnectionString is the name of the SQL Server/Instance as you would connect to it via SQL Server Management Studio. While I could possibly programatically figure this out, there are times where the name within Rubrik differs from the actual connection string used.  

A sample configuration looks like:
```javascript
{
    "Databases": [
        {
            "SourceDBName": "MP_AdventureWorks",
            "SourceDBInstance": "MSSQL",
            "SourceDBServer": "MPRESTON-SQL",
            "TargetDBName": "MP_AW_TEMP_LiveMount",
            "TargetDBInstance": "MSSQLSERVER",
            "TargetDBServer": "MPRESTON-WIN",
            "TargetDBConnectionString": "MPRESTON-WIN.rubrik.us\\MSSQL",
            "TargetDBSQLCredentials": "MPRESTON-WIN-creds.xml",
            "PathToStoreSnapshot": "C:\\snapshot\\"
        },
        {
            "SourceDBName": "MP_AdventureWorks",
            "SourceDBInstance": "MSSQL",
            "SourceDBServer": "MPRESTON-SQL",
            "TargetDBName": "AnotherLiveMount",
            "TargetDBInstance": "MSSQL",
            "TargetDBServer": "MPRESTON-SQL",
            "TargetDBConnectionString": "MPRESTON-SQL.rubrik.us",
            "TargetDBSQLCredentials": "MPRESTON-SQL-creds.xml",
            "PathToStoreSnapshot": "C:\\snapshot\\"
        }
    ]
}
```
### Identity

The Identity folder is not included in this repository. It can be placed anywhere in your environment and should host the secure XML files containing the credentials needed to communicate with the Rubrik cluster and source/target SQL Servers.

Secure XML files may be created manually utilizing the Export-Clixml cmdlet, or better yet, let the script create them for you. Before each a check is executed for the existance of the credential files listed in the config/environment JSON files. If the files do not exist, you will be prompted to create them automatically.

Note: Secure XML files can only be decrypted by the user account that created them.

## Usage

Once the Environment, Config, and Identity requirements are met, the script can be executed using the following syntax...
```javascript
.\ExecuteDBCC.ps1 -ConfigFile .\config\databases.json -EnvironmentFile .\environment\environment.json -IdentityPath .\identity
```
Output from script may be logged to a file by piping the entire script to Out-File as follows:
```javascript
.\ExecuteDBCC.ps1 -ConfigFile .\config\databases.json -EnvironmentFile .\environment\environment.json -IdentityPath .\identity | Out-File C:\scriptoutput.txt
```
