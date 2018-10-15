# DBCC CHECKDB With Rubrik Live Mount

This project is designed to provide the framework to perform dbcc checkdb database health checks utilizing Rubrik's Live Mount Technology. By utilizing a Live Mounted database, organizations are able to offload all of the CPU and Disk I/O associated with DBCC CHECKDB.

## Prerequisites
 - Rubrik Powershell Module
 - SQL Server Powershell Module
 
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

The Config folder contains JSON file (databases.json) that describe the source database information (Database to Live Mount) and the target database information (SQL Server/Database to Live Mount to). A sample configuration looks like:

{
    "Databases": [
        {
            "SourceDBName": "MP_AdventureWorks",
            "SourceDBInstance": "MSSQL",
            "SourceDBServer": "MPRESTON-SQL",
            "TargetDBName": "MP_AW_TEMP_LiveMount",
            "TargetDBInstance": "MSSQLSERVER",
            "TargetDBServer": "MPRESTON-WIN",
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
            "TargetDBSQLCredentials": "MPRESTON-SQL-creds.xml",
            "PathToStoreSnapshot": "C:\\snapshot\\"
        }
    ]
}

### Identity

The Identity folder is not included in this repository. It can be placed anywhere in your environment and should host the secure XML files containing the credentials needed to communicate with the Rubrik cluster and source/target SQL Servers.

Secure XML files may be created manually utilizing the Export-Clixml cmdlet, or better yet, let the script create them for you. Before each a check is executed for the existance of the credential files listed in the config/environment JSON files. If the files do not exist, you will be prompted to create them automatically.

Note: Secure XML files can only be decrypted by the user account that created them.

## Usage

Once the Environment, Config, and Identity requirements are met, the script can be executed using the following syntax...

.\ExecuteDBCC.ps1 -ConfigFile .\config\databases.json -EnvironmentFile .\environment\environment.json -IdentityPath .\identity
