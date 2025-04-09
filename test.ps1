function Invoke-Sync {
   
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceServer,
        
        [Parameter(Mandatory = $true)]
        [string[]]$DestinationServers,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    begin {
       
        if (-not (Get-Module -Name dbatools)) {
            try {
                Import-Module dbatools -ErrorAction Stop
            }
            catch {
                Write-Error "The dbatools module is required but could not be imported. Please install it with: Install-Module dbatools -Force"
                return
            }
        }
        
        # Initialize report object
        $report = @{
            LoginsAdded = @()
            LoginsSynced = @()
            LinkedServersAdded = @()
            AgentJobsAdded = @()
            Errors = @()
        }
        
        # Create connection parameters
        $connParams = @{
            SqlInstance = $SourceServer
        }
        
        if ($Credential) {
            $connParams.Add('SqlCredential', $Credential)
        }
        
        try {
            # Test source connection
            $sourceConn = Connect-DbaInstance @connParams -ErrorAction Stop
            Write-Host "Successfully connected to source server: $SourceServer" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to connect to source server: $_"
            return
        }
    }
    
    process {
        foreach ($destServer in $DestinationServers) {
            Write-Host "`n===== Processing destination server: $destServer =====" -ForegroundColor Cyan
            
            # Create destination connection parameters
            $destConnParams = @{
                SqlInstance = $destServer
            }
            
            if ($Credential) {
                $destConnParams.Add('SqlCredential', $Credential)
            }
            
            try {
                # Test destination connection
                $destConn = Connect-DbaInstance @destConnParams -ErrorAction Stop
                Write-Host "Successfully connected to destination server: $destServer" -ForegroundColor Green
                
                
                Write-Host "`nProcessing logins..." -ForegroundColor Yellow
                
                $sourceLogins = Get-DbaLogin -SqlInstance $sourceConn -ExcludeSystemLogins
                
                
                $destLogins = Get-DbaLogin -SqlInstance $destConn -ExcludeSystemLogins
                
                
                $newLogins = $sourceLogins | Where-Object { $destLogins.Name -notcontains $_.Name }
                $existingLogins = $sourceLogins | Where-Object { $destLogins.Name -contains $_.Name }
                
                # Copy new logins
                if ($newLogins) {
                    try {
                        $copyLoginResult = Copy-DbaLogin -Source $sourceConn -Destination $destConn -Login $newLogins.Name -ExcludeSystemLogins
                        $report.LoginsAdded += $copyLoginResult | ForEach-Object {
                            [PSCustomObject]@{
                                Server = $destServer
                                Login = $_.SourceLogin
                                Status = "Added"
                            }
                        }
                        Write-Host "Added $($copyLoginResult.Count) new logins" -ForegroundColor Green
                    }
                    catch {
                        $errorMsg = "Error copying new logins to $destServer`: $_"
                        Write-Warning $errorMsg
                        $report.Errors += [PSCustomObject]@{
                            Server = $destServer
                            Operation = "Copy Logins"
                            Error = $errorMsg
                        }
                    }
                }
                else {
                    Write-Host "No new logins to add" -ForegroundColor DarkYellow
                }
                
                # Sync SIDs for existing logins
                if ($existingLogins) {
                    Write-Host "Checking SIDs for existing logins..." -ForegroundColor Yellow
                    foreach ($login in $existingLogins) {
                        $sourceSid = $login.Sid
                        $destLogin = $destLogins | Where-Object { $_.Name -eq $login.Name }
                        $destSid = $destLogin.Sid
                        
                        if ($sourceSid -ne $destSid) {
                            try {
                                # Sync SID
                                $syncParams = @{
                                    Source = $sourceConn
                                    Destination = $destConn
                                    Login = $login.Name
                                }
                                
                                Sync-DbaLoginPermission @syncParams
                                
                                $report.LoginsSynced += [PSCustomObject]@{
                                    Server = $destServer
                                    Login = $login.Name
                                    Status = "SID Synced"
                                }
                                Write-Host "Synced SID for login: $($login.Name)" -ForegroundColor Green
                            }
                            catch {
                                $errorMsg = "Error syncing SID for login $($login.Name) on $destServer`: $_"
                                Write-Warning $errorMsg
                                $report.Errors += [PSCustomObject]@{
                                    Server = $destServer
                                    Operation = "Sync Login SID"
                                    Login = $login.Name
                                    Error = $errorMsg
                                }
                            }
                        }
                        else {
                            Write-Host "SID already matches for login: $($login.Name)" -ForegroundColor DarkGray
                        }
                    }
                }
                
               
                Write-Host "`nProcessing linked servers..." -ForegroundColor Yellow
                try {
                    $linkedServerParams = @{
                        Source = $sourceConn
                        Destination = $destConn
                    }
                    
                    $sourceLinkedServers = Get-DbaLinkedServer -SqlInstance $sourceConn
                    if ($sourceLinkedServers.Count -gt 0) {
                        $copyLinkedResult = Copy-DbaLinkedServer @linkedServerParams
                        
                        $report.LinkedServersAdded += $copyLinkedResult | ForEach-Object {
                            [PSCustomObject]@{
                                Server = $destServer
                                LinkedServer = $_.Name
                                Status = "Added"
                            }
                        }
                        Write-Host "Added/Updated $($copyLinkedResult.Count) linked servers" -ForegroundColor Green
                    }
                    else {
                        Write-Host "No linked servers found on source server" -ForegroundColor DarkYellow
                    }
                }
                catch {
                    $errorMsg = "Error copying linked servers to $destServer`: $_"
                    Write-Warning $errorMsg
                    $report.Errors += [PSCustomObject]@{
                        Server = $destServer
                        Operation = "Copy Linked Servers"
                        Error = $errorMsg
                    }
                }
                
                #  Copy SQL Agent jobs
                Write-Host "`nProcessing SQL Agent jobs..." -ForegroundColor Yellow
                try {
                    $jobParams = @{
                        Source = $sourceConn
                        Destination = $destConn
                    }
                    
                    $sourceJobs = Get-DbaAgentJob -SqlInstance $sourceConn
                    if ($sourceJobs.Count -gt 0) {
                        $copyJobResult = Copy-DbaAgentJob @jobParams
                        
                        $report.AgentJobsAdded += $copyJobResult | ForEach-Object {
                            [PSCustomObject]@{
                                Server = $destServer
                                Job = $_.Name
                                Status = "Added"
                            }
                        }
                        Write-Host "Added/Updated $($copyJobResult.Count) SQL Agent jobs" -ForegroundColor Green
                    }
                    else {
                        Write-Host "No SQL Agent jobs found on source server" -ForegroundColor DarkYellow
                    }
                }
                catch {
                    $errorMsg = "Error copying SQL Agent jobs to $destServer`: $_"
                    Write-Warning $errorMsg
                    $report.Errors += [PSCustomObject]@{
                        Server = $destServer
                        Operation = "Copy SQL Agent Jobs"
                        Error = $errorMsg
                    }
                }
            }
            catch {
                Write-Error "Failed to connect to destination server $destServer`: $_"
                $report.Errors += [PSCustomObject]@{
                    Server = $destServer
                    Operation = "Connection"
                    Error = "Failed to connect: $_"
                }
            }
        }
    }
    
    end {
        # Generate final report
        Write-Host "`n===== Sync Summary Report =====" -ForegroundColor Cyan
        
        Write-Host "`nLogins Added ($($report.LoginsAdded.Count)):" -ForegroundColor Yellow
        if ($report.LoginsAdded.Count -gt 0) {
            $report.LoginsAdded | Format-Table -AutoSize
        }
        else {
            Write-Host "None" -ForegroundColor DarkGray
        }
        
        Write-Host "`nLogins with SIDs Synced ($($report.LoginsSynced.Count)):" -ForegroundColor Yellow
        if ($report.LoginsSynced.Count -gt 0) {
            $report.LoginsSynced | Format-Table -AutoSize
        }
        else {
            Write-Host "None" -ForegroundColor DarkGray
        }
        
        Write-Host "`nLinked Servers Added ($($report.LinkedServersAdded.Count)):" -ForegroundColor Yellow
        if ($report.LinkedServersAdded.Count -gt 0) {
            $report.LinkedServersAdded | Format-Table -AutoSize
        }
        else {
            Write-Host "None" -ForegroundColor DarkGray
        }
        
        Write-Host "`nSQL Agent Jobs Added ($($report.AgentJobsAdded.Count)):" -ForegroundColor Yellow
        if ($report.AgentJobsAdded.Count -gt 0) {
            $report.AgentJobsAdded | Format-Table -AutoSize
        }
        else {
            Write-Host "None" -ForegroundColor DarkGray
        }
        
        if ($report.Errors.Count -gt 0) {
            Write-Host "`nErrors Encountered ($($report.Errors.Count)):" -ForegroundColor Red
            $report.Errors | Format-Table -AutoSize
        }
        
        # Return the report object
        return $report
    }
}

function Send-SyncReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SyncReport,
        
        [Parameter(Mandatory = $true)]
        [string]$SmtpServer,
        
        [Parameter(Mandatory = $true)]
        [string]$From,
        
        [Parameter(Mandatory = $true)]
        [string[]]$To,
        
        [Parameter(Mandatory = $false)]
        [string]$Subject = "SQL Server Sync Report between servers",
        
        [Parameter(Mandatory = $false)]
        [int]$SmtpPort = 25,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseSsl
    )
    
    # Create HTML table style
    $style = @"
<style>
    body { font-family: Arial, sans-serif; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th { background-color: #4CAF50; color: white; text-align: left; padding: 8px; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    h2 { color: #4CAF50; }
    .summary { font-weight: bold; margin-bottom: 5px; }
    .no-data { color: #888; font-style: italic; }
</style>
"@

    # Create HTML body
    $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    $style
</head>
<body>
    <h1>SQL Server Sync Report</h1>
    
    <h2>Logins Added ($(($SyncReport.LoginsAdded).Count))</h2>
"@

    if ($SyncReport.LoginsAdded.Count -gt 0) {
        $htmlBody += $SyncReport.LoginsAdded | ConvertTo-Html -Fragment | Out-String
    } else {
        $htmlBody += "<p class='no-data'>No logins were added during this Sync.</p>"
    }

    $htmlBody += @"
    
    <h2>Logins with SIDs Synced ($(($SyncReport.LoginsSynced).Count))</h2>
"@

    if ($SyncReport.LoginsSynced.Count -gt 0) {
        $htmlBody += $SyncReport.LoginsSynced | ConvertTo-Html -Fragment | Out-String
    } else {
        $htmlBody += "<p class='no-data'>No login SIDs were synced during this Sync.</p>"
    }

    $htmlBody += @"
    
    <h2>Linked Servers Added ($(($SyncReport.LinkedServersAdded).Count))</h2>
"@

    if ($SyncReport.LinkedServersAdded.Count -gt 0) {
        $htmlBody += $SyncReport.LinkedServersAdded | ConvertTo-Html -Fragment | Out-String
    } else {
        $htmlBody += "<p class='no-data'>No linked servers were added during this Sync.</p>"
    }

    $htmlBody += @"
    
    <h2>SQL Agent Jobs Added ($(($SyncReport.AgentJobsAdded).Count))</h2>
"@

    if ($SyncReport.AgentJobsAdded.Count -gt 0) {
        $htmlBody += $SyncReport.AgentJobsAdded | ConvertTo-Html -Fragment | Out-String
    } else {
        $htmlBody += "<p class='no-data'>No SQL Agent jobs were added during this Sync.</p>"
    }

    if ($SyncReport.Errors.Count -gt 0) {
        $htmlBody += @"
        
        <h2>Errors Encountered ($(($SyncReport.Errors).Count))</h2>
"@
        $htmlBody += $SyncReport.Errors | ConvertTo-Html -Fragment | Out-String
    }

    $htmlBody += @"
    <p>This report was automatically generated after SQL Server Sync of logins ,linked servers and Jobs.</p>
</body>
</html>
"@

    # Create email parameters
    $mailParams = @{
        SmtpServer = $SmtpServer
        From = $From
        To = $To
        Subject = $Subject
        Body = $htmlBody
        BodyAsHtml = $true
        Port = $SmtpPort
    }

    if ($Credential) {
        $mailParams.Add('Credential', $Credential)
    }

    if ($UseSsl) {
        $mailParams.Add('UseSsl', $true)
    }

    # Send the email
    try {
        Send-MailMessage @mailParams
        Write-Host "Sync report email sent successfully to $($To -join ', ')" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send Sync report email: $_"
    }
}













# Example usage:
try
	{
# Invoke-Sync -SourceServer "SourceSQL" -DestinationServers "DestSQL1", "DestSQL2"
}
#Error Handeling
	catch [Exception]
	{
	    write-Host "---------------------------------------------------------"  -ForegroundColor red;
		write-Host "error "  -ForegroundColor red;
		
		# Handle the error
	    $err = $_.Exception;
	    write-Host $err.Message -ForegroundColor red;
	    while( $err.InnerException ) 
	    {
	    	$err = $err.InnerException;
	        write-Host $err.Message -ForegroundColor Magenta;
		}
		
		write-Host "---------------------------------------------------------"  -ForegroundColor red;
	}
	
try
	{	
	
# Send-SyncReport -SyncReport $report -SmtpServer "smtp.company.com" -From "sqlSync@company.com" -To "dba@company.com", "manager@company.com"

}
#Error Handeling
	catch [Exception]
	{
	    write-Host "---------------------------------------------------------"  -ForegroundColor red;
		write-Host "error "  -ForegroundColor red;
		
		# Handle the error
	    $err = $_.Exception;
	    write-Host $err.Message -ForegroundColor red;
	    while( $err.InnerException ) 
	    {
	    	$err = $err.InnerException;
	        write-Host $err.Message -ForegroundColor Magenta;
		}
		
		write-Host "---------------------------------------------------------"  -ForegroundColor red;
	}
