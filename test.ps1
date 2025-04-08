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
			$_.$ColumnName -ne $null -and
			$_.$ColumnName -ne '' -and
			![string]::IsNullOrWhiteSpace($_.$ColumnName)
		}
		# Remove duplicates based on all properties
		$uniqueResults = $filteredResults | Sort-Object -Property * -Unique
		return $uniqueResults
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
Function QueryExecuteRO {
	Param(
		[parameter(Mandatory = $true)]
		[string]$SQLServer,
		[parameter(Mandatory = $false)]
		[string]$SQLUser,
		[parameter(Mandatory = $false)]
		[string]$SQLPassword,
		[parameter(Mandatory = $true)]
		[string]$SQLDatabase,
		[parameter(Mandatory = $true)]
		[string]$SQLQuery,
		[parameter(Mandatory = $true)]
		[string]$ApplicationName,
		[parameter(Mandatory = $true)]
		[string]$CommandTimeout
	)
 Begin {
	 Write-Verbose "[$((Get-Date).TimeOfDay) BEGIN  ] Starting $($MyInvocation.MyCommand)"
		$ErrorActionPreference = "Stop"
		$Error.Clear()
		Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"
		If ($PSBoundParameters.ContainsKey('Verbose')) {
			$DebugPreference = 'Continue'
		}
		$PSBoundParameters.GetEnumerator() | ForEach {
			Write-Verbose " Input parameters "
			Write-Verbose $_
		}
	
	
	
	} #begin

	Process {
		try {
	
			Write-Verbose "Building connection string"
			#Create connection strings
			$private:SqlSourceConnection = New-Object System.Data.SqlClient.SqlConnection
			if ([string]::IsNullOrEmpty($SQLUser)) {
				$private:SqlSourceConnection.ConnectionString = "Server=$SQLServer;Database=$SQLDatabase;Integrated Security=True;Application Name=$ApplicationName;ApplicationIntent=ReadOnly"  
			}
			else {
				$private:SqlSourceConnection.ConnectionString = "Server=$SQLServer;Database=$SQLDatabase;Uid=$SQLUser;Pwd=$SQLPassword;Application Name=$ApplicationName;ApplicationIntent=ReadOnly;trusted_connection=true;Encrypt=True;"  
			}  
			Write-Verbose "[PROCESS] Opening the connection to $SQLServer"
			#Connect to source server and get data
			$private:SqlSourceConnection.Open()
			$private:SqlCmdGet = New-Object System.Data.SqlClient.SqlCommand($SQLQuery, $SqlSourceConnection)
			$private:SqlCmdGet.CommandTimeout = $CommandTimeout
		 Write-Verbose "Performing Query operation"
			Write-Verbose "[PROCESS] Invoking $query"
			$private:SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCmdGet)
			$private:DataSet = New-Object System.Data.DataSet
			[void]$private:SqlAdapter.Fill($DataSet)
		 Write-Verbose "Closing connection"
			$private:SqlSourceConnection.Close()

			$private:DataTable = new-object "System.Data.DataTable"
			$private:DataTable = $DataSet.Tables[0]
			$private:RowCount = $DataTable.rows.Count
		 return $private:DataTable  
		 
			Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
		}
		catch {

			write-Host "Failed to connect to server: $SQLServer "
			Write-Warning "Failed to connect to server: $SQLServer "
			# Handle the error
			$err = $_.Exception
			#Want to save tons of time debugging a #Powershell script? Put this in your catch blocks: 
			$ErrorLineNumber = $_.InvocationInfo.ScriptLineNumber
			write-warning $('{0} Trapped error at line [{1}] : [{2}]' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') , $ErrorLineNumber, $err.Message );

			write-Error $err.Message
			while ( $err.InnerException ) {
    $err = $err.InnerException
    write-error $err.Message
			}

		}
 }
	
	End {
		Write-Verbose "[END    ] Closing the connection if it is still open"
		if ($private:SqlSourceConnection.State -ne [System.Data.ConnectionState]::Closed) {
			$private:SqlServerConnection.Close()
		}
		Write-Verbose "[$((Get-Date).TimeOfDay) END    ] Ending $($MyInvocation.MyCommand)"
	} #end
}

function GetAGTopology {
	[cmdletbinding()]
	param
	(
		[parameter(mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$ServerName
	)
	Begin {
		$ErrorActionPreference = "Stop"
		$Error.Clear()
		Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"
		If ($PSBoundParameters.ContainsKey('Verbose')) {
			$DebugPreference = 'Continue'
		}
		$PSBoundParameters.GetEnumerator() | ForEach {
			Write-Verbose " Input parameters "
			Write-Verbose $_
		}
	
	
	
	} #begin

	Process {
		try {
			$query = @"
set nocount on;

set nocount on;

DECLARE @DetailDomainName		varchar(256)
SET @DetailDomainName = NULL

        EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE'
							        ,'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
							        ,'Domain'
							        ,@DetailDomainName OUTPUT

									if( @DetailDomainName is null or @DetailDomainName='')
									begin 
									RAISERROR('@DetailDomainName cannot be null',16,0)
									end


DROP TABLE

IF EXISTS #tmpardb_database_replica_states
	,#tmpardb_database_replica_cluster_states
	SELECT replica_id
		,group_database_id
		,database_name
		,is_database_joined
		,is_failover_ready
		,is_pending_secondary_suspend
		,recovery_lsn
		,truncation_lsn
	INTO #tmpardb_database_replica_cluster_states
	FROM master.sys.dm_hadr_database_replica_cluster_states 
SELECT HADR.replica_id
	,HADR.group_database_id
	,HADR.synchronization_state
	,HADR.is_suspended
	,database_id
INTO #tmpardb_database_replica_states 
FROM master.sys.dm_hadr_database_replica_states HADR 


DECLARE @sqltxt NVARCHAR(max);
DECLARE @clustertype BIT = 0;
DECLARE @required_synchronized_secondaries_to_commit BIT = 0;
DECLARE @is_contained BIT = 0;

IF EXISTS (
		SELECT  1/0
		FROM sys.all_columns AS ac
		WHERE ac.object_id = OBJECT_ID(N'sys.availability_groups', N'V')
			AND ac.name = N'cluster_type_desc'
		)
BEGIN
	SET @clustertype = 1;
END

IF EXISTS (
		SELECT 1 / 0
		FROM sys.all_columns AS ac
		WHERE ac.object_id = OBJECT_ID(N'sys.availability_groups', N'V')
			AND ac.name = N'required_synchronized_secondaries_to_commit'
		)
BEGIN
	SET @required_synchronized_secondaries_to_commit = 1;
END

IF EXISTS (
		SELECT 1 / 0
		FROM sys.all_columns AS ac
		WHERE ac.object_id = OBJECT_ID(N'sys.availability_groups', N'V')
			AND ac.name = N'is_contained'
		)
BEGIN
	SET @is_contained = 1;
END

SET @sqltxt = '';
SET @sqltxt += N'
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
select   distinct   ag.[name] as AGName
            ,ag.is_distributed as IsDistributed
            ,rp.replica_server_name as ReplicaServerName
            ,case when ag.is_distributed =0 and rps.role_desc is null then ''Primary''
			when ag.is_distributed =1 and rps.role_desc is null then ''Distributed AG''
			else rps.role_desc end as [ReplicaRole]
			,database_name
			, case when rp.replica_server_name = @@servername then 
			DATABASEPROPERTYEX(DB_NAME(database_id), ''Updateability'')  else null end DatabaseState 
			,rp.availability_mode_desc as AvailabilityMode
            ,rp.failover_mode_desc as FailoverMode
            ,rps.synchronization_health_desc as ReplicaHealth
            ,rps.connected_state_desc as ReplicaConnectedState ' + CONVERT(NVARCHAR(MAX), CASE @clustertype
			WHEN 1
				THEN N',ag.cluster_type_desc as ClusterType '
			ELSE N' '
			END) + CONVERT(NVARCHAR(MAX), CASE @required_synchronized_secondaries_to_commit
			WHEN 1
				THEN N',ag.required_synchronized_secondaries_to_commit '
			ELSE N' '
			END) + CONVERT(NVARCHAR(MAX), CASE @required_synchronized_secondaries_to_commit
			WHEN 1
				THEN N',ag.is_contained '
			ELSE N' '
			END) + 
	'		,dtc_support
			,role_desc
			,endpoint_url
				,replace (  replace( replace(  replace(endpoint_url,''tcp://'','''') '+',' +'''' + @DetailDomainName + ''''+ ' ,'''') ,''5022'','''')
,''.:'','''')  AOL
			,connected_state_desc
			,operational_state
			,synchronization_health_desc
			,db_failover
			,automated_backup_preference_desc
			,failure_condition_level
			,health_check_timeout
			,primary_role_allow_connections_desc
			,secondary_role_allow_connections_desc
			,backup_priority
			,ISNULL(AGL.port, -1) AS [PortNumber],
AGL.is_conformant AS [IsConformant],
ISNULL(AGL.ip_configuration_string_from_cluster, N'''') AS [ClusterIPConfiguration]
,ISNULL(dbrs.is_suspended, 0) AS [IsSuspended],
ISNULL(dbcs.is_database_joined, 0) AS [IsJoined],
AGL.dns_name AS Listener_Name, aglip.listener_id, aglip.ip_address, aglip.ip_subnet_mask, aglip.is_dhcp, aglip.network_subnet_ip, 
              aglip.network_subnet_prefix_length, aglip.network_subnet_ipv4_mask, aglip.state, aglip.state_desc

        from  sys.availability_groups ag
        left join   sys.availability_replicas rp
        on          ag.group_id = rp.group_id
        left join  sys.dm_hadr_availability_replica_states rps
        on          rps.group_id = rp.group_id
        and         rps.replica_id = rp.replica_id
		left JOIN master.sys.availability_group_listeners AS AGL ON AGL.group_id=ag.group_id
		left JOIN #tmpardb_database_replica_cluster_states AS dbcs ON rps.replica_id = dbcs.replica_id
		LEFT OUTER JOIN #tmpardb_database_replica_states AS dbrs ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
		        left join	sys.availability_group_listener_ip_addresses AS aglip 
   ON aglip.listener_id = agl.listener_id

        order by   ag.[name], rps.role_desc OPTION (max_grant_percent = 3, MAXDOP 1);'

		
EXEC sys.sp_executesql @sqltxt;


"@

			try {
    Write-verbose "Fetching CPU data from system_health Extended Events on server: $ServerName"
				$DataParams = @{
					SQLServer       = $ServerName 
					SQLDatabase     = "master" 
					ApplicationName = "AGTopology" 
					CommandTimeout  = "120"
					SQLQuery        = $Query
					Verbose         = $false
				}
				$AGData = QueryExecuteRO @DataParams 

    if ($AGData.Rows.Count -eq 0) {
					Write-host "No AG information available on server: $ServerName"
					return
    }
	
				$AGlistenerlist = @()
	
				if ($AGData) {
					$AGlistenerlist = $AGData | Where-Object { $_.Listener_Name -ne $null } | Select-Object Listener_Name
					$AGlistenerlist += $AGData |Where-Object { $_.Listener_Name -ne $null } | Select-Object @{Name = 'Listener_Name' ; Expression = { $_.AOL } }
					$AGlistenerlist += $AGData | Where-Object { $_.IsDistributed -eq 1 -and $_.Listener_Name -ne $null } | Select-Object @{Name = 'Listener_Name' ; Expression = { $_.AOL } }
				} 
				#$AGData| Select-Object ReplicaServerName
				$AGlistenerlist = $AGlistenerlist | Sort-Object Listener_Name -Unique
				#$AGlistenerlist  = 
				#$AGlistenerlist | Where-Object {![string]::IsNullOrWhiteSpace($_.AGlistenerlist)}
				$AGlistenerlist = $AGlistenerlist | Where-Object { -not [string]::IsNullOrEmpty($_.Listener_Name) -and $_.Listener_Name -ne "" }
    #write-host $AGlistenerlist 
				$results = @();
	
	
	
				#foreach ($Listener_Name in $AGlistenerlist) {
				#	#write-host $Listener_Name.Listener_Name
				#	
				#	$DataParams.Remove('SQLServer')
				#	$SQLServer = $Listener_Name.Listener_Name
				#	#write-host $SQLServer
				#	$DataParams.Add("SQLServer", $SQLServer)
				#	#write-host $SQLServer
				#	#$DataParams
				#	$results += QueryExecuteRO @DataParams


				$AGlistenerlist = $AGlistenerlist.Listener_Name

				$processedServers = New-Object System.Collections.ArrayList
				while ($true) {
					$newServersFound = $false
   
					# Create a copy of current servers array to iterate through
					$currentServers = $AGlistenerlist.Clone()
					#$currentServers
					foreach ($Listener_Name in $currentServers) {
						# Skip if we've already processed this server
						if ($processedServers -contains $Listener_Name) {
							continue
						}
						Write-Host "Processing server: $Listener_Name"
						try {
							# Replace this with your actual command that returns server names
		   
							$DataParams.Remove('SQLServer')
		   
		   
							$SQLServer = $Listener_Name
							write-host "sql $SQLServer"
							$DataParams.Add("SQLServer", $SQLServer)
							#write-host $SQLServer
							#$DataParams
		
							#if ([string]::IsNullOrEmpty($SQLServer)) {
				
							$results += QueryExecuteRO @DataParams
				
							$Newserverlist += $results | Where-Object { $_ -ne $null -and $_.ToString().Trim() -ne "" } | Select-Object @{Name = 'Listener_Name' ; Expression = { $_.AOL } } | Sort-Object Listener_Name -Unique
							# Add newly discovered servers to the list if they're not already present
							foreach ($discoveredServers in $Newserverlist) {
								$discoveredServer = $discoveredServers.Listener_Name
								if ($AGlistenerlist -notcontains $discoveredServer) {
									Write-Host "New server discovered: $discoveredServer"
				   
									$AGlistenerlist += $discoveredServer
									$newServersFound = $true
								}
							}
							# Mark this server as processed
							[void]$processedServers.Add($SQLServer)
						}
						catch {
							Write-Warning "Error processing server $server : $_"
							# Still mark as processed to avoid repeated attempts
							[void]$processedServers.Add($SQLServer)
							write-host  "process $processedServers"
						}
					}
					# If no new servers were found in this iteration, we're done
					if (-not $newServersFound) {
						break
					}
				}
				# Display final results
				Write-Host "`nFinal server list:"
				$AGlistenerlist | Sort-Object | ForEach-Object { Write-Host $_ }
				Write-Host "`nTotal servers found: $($AGlistenerlist.Count)"


	
				#}
				$results 
			}
			catch {
    Write-Error "An error occurred: $_"
			}

		}
		catch {

			write-Host "Failed to connect to server: $Server "
			Write-Warning "Failed to connect to server: $Server "
			# Handle the error
			$err = $_.Exception
			#Want to save tons of time debugging a #Powershell script? Put this in your catch blocks: 
			$ErrorLineNumber = $_.InvocationInfo.ScriptLineNumber
			write-warning $('{0} Trapped error at line [{1}] : [{2}]' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') , $ErrorLineNumber, $err.Message );
	
			write-Error $err.Message
			while ( $err.InnerException ) {
    $err = $err.InnerException
    write-error $err.Message
			}

		}
 }
	
	End {
		Write-Verbose "[END    ] Closing the connection"
       
		#$private:SqlServerConnection.Close()
		Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
	} #end
}

$Data = GetAGTopology -ServerName server1
 
$cleanedData = $Data | Clean-ResultSet -ColumnName "DatabaseState"
#$cleanedData
$DAGData = $Data| Where-Object { $_.ReplicaRole -eq "Distributed AG" } |  Clean-ResultSet -ColumnName "ReplicaServerName"
$DAGData
#$Data | Clean-ResultSet -ColumnName "DatabaseState"
$cleanedData | Export-Csv -Path "C:\TEMP\tmp\Tools\PS\AGTopology5.csv" 
$DAGData | Export-Csv -Path "C:\TEMP\tmp\Tools\PS\AGTopology5.csv"  -append
#$Data | Export-Csv -Path "C:\TEMP\tmp\Tools\PS\AGTopology1.csv" 
#get all nodes for passed Server
#get all AG names 
#

