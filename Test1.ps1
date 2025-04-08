# Function to clean result set by removing duplicates and null/blank values
function Clean-ResultSet {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject[]]$InputObject,
        [Parameter(Mandatory = $true)]
        [string]$ColumnName
    )
    begin {
        $results = @()
    }
    process {
        $results += $InputObject
    }
    end {
        # Remove rows where specified column is null or blank
        $filteredResults = $results | Where-Object {
            $null -ne $_.$ColumnName -and
            $_.ColumnName -ne '' -and
            ![string]::IsNullOrWhiteSpace($_.$ColumnName)
        }
        # Remove duplicates based on all properties
        return ($filteredResults | Sort-Object -Property * -Unique)
    }
}

function Remove-NullValues {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject[]]$InputObject
    )
    process {
        foreach ($obj in $InputObject) {
            # Create a new object to store non-null properties
            $cleanObject = @{}
            
            # Get all properties of the current object
            $properties = $obj | Get-Member -MemberType Properties
            
            # Filter out null values
            foreach ($prop in $properties) {
                $propName = $prop.Name
                $propValue = $obj.$propName
                if ($null -ne $propValue) {
                    $cleanObject[$propName] = $propValue
                }
            }
            
            # Output the cleaned object
            [PSCustomObject]$cleanObject
        }
    }
}

function Invoke-SqlReadOnlyQuery {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$SqlServer,
        
        [Parameter(Mandatory = $false)]
        [string]$SqlUser,
        
        [Parameter(Mandatory = $false)]
        [string]$SqlPassword,
        
        [Parameter(Mandatory = $true)]
        [string]$SqlDatabase,
        
        [Parameter(Mandatory = $true)]
        [string]$SqlQuery,
        
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,
        
        [Parameter(Mandatory = $true)]
        [int]$CommandTimeout
    )
    
    Begin {
        Write-Verbose "[$((Get-Date).TimeOfDay) BEGIN] Starting $($MyInvocation.MyCommand)"
        $ErrorActionPreference = "Stop"
        $Error.Clear()
        
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $DebugPreference = 'Continue'
        }
        
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            Write-Verbose "Input parameter: $_"
        }
    }

    Process {
        try {
            Write-Verbose "Building connection string"
            $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
            
            if ([string]::IsNullOrEmpty($SqlUser)) {
                $sqlConnection.ConnectionString = "Server=$SqlServer;Database=$SqlDatabase;Integrated Security=True;Application Name=$ApplicationName;ApplicationIntent=ReadOnly"  
            } else {
                $sqlConnection.ConnectionString = "Server=$SqlServer;Database=$SqlDatabase;Uid=$SqlUser;Pwd=$SqlPassword;Application Name=$ApplicationName;ApplicationIntent=ReadOnly;trusted_connection=true;Encrypt=True;"  
            }
            
            Write-Verbose "[PROCESS] Opening the connection to $SqlServer"
            $sqlConnection.Open()
            
            $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($SqlQuery, $sqlConnection)
            $sqlCommand.CommandTimeout = $CommandTimeout
            
            Write-Verbose "Executing query"
            $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($sqlCommand)
            $dataSet = New-Object System.Data.DataSet
            [void]$sqlAdapter.Fill($dataSet)
            
            Write-Verbose "Closing connection"
            $sqlConnection.Close()
            
            return $dataSet.Tables[0]
        }
        catch {
            Write-Host "Failed to connect to server: $SqlServer"
            Write-Warning "Failed to connect to server: $SqlServer"
            
            $err = $_.Exception
            $errorLineNumber = $_.InvocationInfo.ScriptLineNumber
            Write-Warning $('{0} Trapped error at line [{1}] : [{2}]' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $errorLineNumber, $err.Message)
            
            Write-Error $err.Message
            while ($err.InnerException) {
                $err = $err.InnerException
                Write-Error $err.Message
            }
        }
    }
    
    End {
        Write-Verbose "[END] Closing the connection if it is still open"
        if ($sqlConnection.State -ne [System.Data.ConnectionState]::Closed) {
            $sqlConnection.Close()
        }
        Write-Verbose "[$((Get-Date).TimeOfDay) END] Ending $($MyInvocation.MyCommand)"
    }
}

function Get-AvailabilityGroupTopology {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ServerName
    )
    
    Begin {
        $ErrorActionPreference = "Stop"
        $Error.Clear()
        Write-Verbose "[BEGIN] Starting: $($MyInvocation.MyCommand)"
        
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $DebugPreference = 'Continue'
        }
        
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            Write-Verbose "Input parameter: $_"
        }
    }

    Process {
        try {
            $query = @"
SET NOCOUNT ON;

DECLARE @DetailDomainName VARCHAR(256)
SET @DetailDomainName = NULL

EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE',
                           'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters',
                           'Domain',
                           @DetailDomainName OUTPUT

IF (@DetailDomainName IS NULL OR @DetailDomainName = '')
BEGIN 
    RAISERROR('@DetailDomainName cannot be null', 16, 0)
END

-- Create temp tables for AG data
IF OBJECT_ID('tempdb..#tmpardb_database_replica_states') IS NOT NULL
    DROP TABLE #tmpardb_database_replica_states
    
IF OBJECT_ID('tempdb..#tmpardb_database_replica_cluster_states') IS NOT NULL
    DROP TABLE #tmpardb_database_replica_cluster_states
    
SELECT replica_id,
       group_database_id,
       database_name,
       is_database_joined,
       is_failover_ready,
       is_pending_secondary_suspend,
       recovery_lsn,
       truncation_lsn
INTO #tmpardb_database_replica_cluster_states
FROM master.sys.dm_hadr_database_replica_cluster_states

SELECT HADR.replica_id,
       HADR.group_database_id,
       HADR.synchronization_state,
       HADR.is_suspended,
       database_id
INTO #tmpardb_database_replica_states 
FROM master.sys.dm_hadr_database_replica_states HADR 

-- Check for feature availability
DECLARE @sqltxt NVARCHAR(MAX);
DECLARE @clustertype BIT = 0;
DECLARE @required_synchronized_secondaries_to_commit BIT = 0;
DECLARE @is_contained BIT = 0;

IF EXISTS (
    SELECT 1
    FROM sys.all_columns AS ac
    WHERE ac.object_id = OBJECT_ID(N'sys.availability_groups', N'V')
    AND ac.name = N'cluster_type_desc'
)
BEGIN
    SET @clustertype = 1;
END

IF EXISTS (
    SELECT 1
    FROM sys.all_columns AS ac
    WHERE ac.object_id = OBJECT_ID(N'sys.availability_groups', N'V')
    AND ac.name = N'required_synchronized_secondaries_to_commit'
)
BEGIN
    SET @required_synchronized_secondaries_to_commit = 1;
END

IF EXISTS (
    SELECT 1
    FROM sys.all_columns AS ac
    WHERE ac.object_id = OBJECT_ID(N'sys.availability_groups', N'V')
    AND ac.name = N'is_contained'
)
BEGIN
    SET @is_contained = 1;
END

-- Build dynamic SQL to handle different SQL Server versions
SET @sqltxt = N'
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT DISTINCT
    ag.[name] AS AGName,
    ag.is_distributed AS IsDistributed,
    rp.replica_server_name AS ReplicaServerName,
    CASE 
        WHEN ag.is_distributed = 0 AND rps.role_desc IS NULL THEN ''Primary''
        WHEN ag.is_distributed = 1 AND rps.role_desc IS NULL THEN ''Distributed AG''
        ELSE rps.role_desc 
    END AS [ReplicaRole],
    database_name,
    CASE 
        WHEN rp.replica_server_name = @@SERVERNAME THEN DATABASEPROPERTYEX(DB_NAME(database_id), ''Updateability'')
        ELSE NULL 
    END AS DatabaseState,
    rp.availability_mode_desc AS AvailabilityMode,
    rp.failover_mode_desc AS FailoverMode,
    rps.synchronization_health_desc AS ReplicaHealth,
    rps.connected_state_desc AS ReplicaConnectedState ' + 
    CASE @clustertype
        WHEN 1 THEN N', ag.cluster_type_desc AS ClusterType '
        ELSE N' '
    END + 
    CASE @required_synchronized_secondaries_to_commit
        WHEN 1 THEN N', ag.required_synchronized_secondaries_to_commit '
        ELSE N' '
    END + 
    CASE @is_contained
        WHEN 1 THEN N', ag.is_contained '
        ELSE N' '
    END + 
    N', dtc_support,
    role_desc,
    endpoint_url,
    REPLACE(REPLACE(REPLACE(REPLACE(endpoint_url, ''tcp://'', ''''), ''' + @DetailDomainName + ''', ''''), ''5022'', ''''), ''.:'', '''') AS AOL,
    connected_state_desc,
    operational_state,
    synchronization_health_desc,
    db_failover,
    automated_backup_preference_desc,
    failure_condition_level,
    health_check_timeout,
    primary_role_allow_connections_desc,
    secondary_role_allow_connections_desc,
    backup_priority,
    ISNULL(AGL.port, -1) AS [PortNumber],
    AGL.is_conformant AS [IsConformant],
    ISNULL(AGL.ip_configuration_string_from_cluster, N'''') AS [ClusterIPConfiguration],
    ISNULL(dbrs.is_suspended, 0) AS [IsSuspended],
    ISNULL(dbcs.is_database_joined, 0) AS [IsJoined],
    AGL.dns_name AS Listener_Name, 
    aglip.listener_id, 
    aglip.ip_address, 
    aglip.ip_subnet_mask, 
    aglip.is_dhcp, 
    aglip.network_subnet_ip, 
    aglip.network_subnet_prefix_length, 
    aglip.network_subnet_ipv4_mask, 
    aglip.state, 
    aglip.state_desc
FROM sys.availability_groups ag
LEFT JOIN sys.availability_replicas rp ON ag.group_id = rp.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states rps ON rps.group_id = rp.group_id AND rps.replica_id = rp.replica_id
LEFT JOIN master.sys.availability_group_listeners AS AGL ON AGL.group_id = ag.group_id
LEFT JOIN #tmpardb_database_replica_cluster_states AS dbcs ON rps.replica_id = dbcs.replica_id
LEFT JOIN #tmpardb_database_replica_states AS dbrs ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
LEFT JOIN sys.availability_group_listener_ip_addresses AS aglip ON aglip.listener_id = agl.listener_id
ORDER BY ag.[name], rps.role_desc 
OPTION (MAX_GRANT_PERCENT = 3, MAXDOP 1);'

EXEC sys.sp_executesql @sqltxt;
"@

            try {
                Write-Verbose "Fetching AG data from system_health Extended Events on server: $ServerName"
                $dataParams = @{
                    SqlServer       = $ServerName 
                    SqlDatabase     = "master" 
                    ApplicationName = "AGTopology" 
                    CommandTimeout  = 120
                    SqlQuery        = $query
                    Verbose         = $false
                }
                
                $agData = Invoke-SqlReadOnlyQuery @dataParams 

                if ($agData.Rows.Count -eq 0) {
                    Write-Host "No AG information available on server: $ServerName"
                    return
                }
                
                # Process AG listeners
                $agListeners = @()
                
                if ($agData) {
                    # Get primary listeners
                    $agListeners = $agData | Where-Object { $null -ne $_.Listener_Name } | 
                                   Select-Object -Property Listener_Name
                    
                    # Add AOL listeners
                    $agListeners += $agData | Where-Object { $null -ne $_.Listener_Name } | 
                                   Select-Object @{Name = 'Listener_Name'; Expression = { $_.AOL }}
                    
                    # Add distributed AG listeners
                    $agListeners += $agData | Where-Object { $_.IsDistributed -eq 1 -and $null -ne $_.Listener_Name } | 
                                   Select-Object @{Name = 'Listener_Name'; Expression = { $_.AOL }}
                } 
                
                # Filter and get unique listeners
                $agListeners = $agListeners | 
                              Where-Object { -not [string]::IsNullOrEmpty($_.Listener_Name) -and $_.Listener_Name -ne "" } | 
                              Sort-Object -Property Listener_Name -Unique
                
                $results = @()
                $processedServers = New-Object System.Collections.ArrayList
                $listenerNames = $agListeners.Listener_Name
                $newServerList = @()
                
                # Process all servers in a discovery pattern
                while ($true) {
                    $newServersFound = $false
                    
                    # Create a copy of current servers array to iterate through
                    $currentServers = $listenerNames.Clone()
                    
                    foreach ($listenerName in $currentServers) {
                        # Skip if we've already processed this server
                        if ($processedServers -contains $listenerName) {
                            continue
                        }
                        
                        Write-Host "Processing server: $listenerName"
                        
                        try {
                            # Update SQL Server parameter
                            $dataParams['SqlServer'] = $listenerName
                            
                            # Execute query against this listener
                            $listenerResults = Invoke-SqlReadOnlyQuery @dataParams
                            $results += $listenerResults
                            
                            # Find new servers from the results
                            $newServers = $listenerResults | 
                                         Where-Object { $_ -ne $null -and $_.ToString().Trim() -ne "" } | 
                                         Select-Object @{Name = 'Listener_Name'; Expression = { $_.AOL }} | 
                                         Sort-Object -Property Listener_Name -Unique
                            
                            # Add newly discovered servers if not already in the list
                            foreach ($newServer in $newServers) {
                                $serverName = $newServer.Listener_Name
                                
                                if ($listenerNames -notcontains $serverName) {
                                    Write-Host "New server discovered: $serverName"
                                    $listenerNames += $serverName
                                    $newServersFound = $true
                                }
                            }
                            
                            # Mark this server as processed
                            [void]$processedServers.Add($listenerName)
                        }
                        catch {
                            Write-Warning "Error processing server $listenerName : $_"
                            # Still mark as processed to avoid repeated attempts
                            [void]$processedServers.Add($listenerName)
                        }
                    }
                    
                    # Exit the loop if no new servers were found
                    if (-not $newServersFound) {
                        break
                    }
                }
                
                # Display final results
                Write-Host "`nFinal server list:"
                $listenerNames | Sort-Object | ForEach-Object { Write-Host $_ }
                Write-Host "`nTotal servers found: $($listenerNames.Count)"
                
                return $results
            }
            catch {
                Write-Error "An error occurred: $_"
            }
        }
        catch {
            Write-Host "Failed to connect to server: $ServerName"
            Write-Warning "Failed to connect to server: $ServerName"
            
            $err = $_.Exception
            $errorLineNumber = $_.InvocationInfo.ScriptLineNumber
            Write-Warning $('{0} Trapped error at line [{1}] : [{2}]' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $errorLineNumber, $err.Message)
            
            Write-Error $err.Message
            while ($err.InnerException) {
                $err = $err.InnerException
                Write-Error $err.Message
            }
        }
    }
    
    End {
        Write-Verbose "[END] Ending: $($MyInvocation.MyCommand)"
    }
}

# Main execution code
$data = Get-AvailabilityGroupTopology -ServerName "server1"
 
$cleanedData = $data | Clean-ResultSet -ColumnName "DatabaseState"
$dagData = $data | Where-Object { $_.ReplicaRole -eq "Distributed AG" } | Clean-ResultSet -ColumnName "ReplicaServerName"

# Output results
$cleanedData | Export-Csv -Path "C:\TEMP\tmp\Tools\PS\AGTopology5.csv"
$dagData | Export-Csv -Path "C:\TEMP\tmp\Tools\PS\AGTopology5.csv" -Append
