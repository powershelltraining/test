
# Define parameters
$SourceServer = "SourceServerName"
$DestPathList = "c:\user\yesh\downloads\destservers.txt"
$DestinationServers = Get-Content $DestPathList | Where-Object { $_ -match "(^[^#]\S*)" -and $_ -notmatch "^\s+$" }
 
# Email settings
$EmailParams = @{
    SmtpServer = "your-smtp-server.example.com"
    Port = 25  # Change if using a different port
    From = "SQLReports@yourcompany.com"
    To = "dba@yourcompany.com"  # Can be comma-separated list for multiple recipients

}

# Create empty arrays to store results
$JobsReport = @()
$LinkedServersReport = @()
$LoginsReport = @()

Write-Host "Starting comparison between $SourceServer and destination servers: $($DestinationServers -join ', ')" -ForegroundColor Cyan

# Get SQL Jobs from source server
Write-Host "Getting SQL Agent jobs from source server..." -ForegroundColor Green
$SourceJobs = Get-DbaAgentJob -SqlInstance $SourceServer

# Get Linked Servers from source server
Write-Host "Getting Linked Servers from source server..." -ForegroundColor Green
$SourceLinkedServers = Get-DbaLinkedServer -SqlInstance $SourceServer

# Get Logins from source server
Write-Host "Getting Logins from source server..." -ForegroundColor Green
$SourceLogins = Get-DbaLogin -SqlInstance $SourceServer | Where-Object {
    $_.Name -notlike '##*' -and 
    $_.Name -notlike 'NT SERVICE\*' -and 
    $_.Name -notlike 'NT AUTHORITY\*' -and 
    $_.Name -ne 'sa'
}

# Process each destination server
foreach ($DestServer in $DestinationServers) {
    Write-Host "Processing destination server: $DestServer" -ForegroundColor Yellow
    
    try {
        # Get SQL Jobs from destination server
        Write-Host "  Getting SQL Agent jobs from $DestServer..." -ForegroundColor Green
        $DestJobs = Get-DbaAgentJob -SqlInstance $DestServer -ErrorAction Stop
        
        # Compare Jobs
        Write-Host "  Comparing jobs..." -ForegroundColor Green
        
        # For jobs in source, check if they exist in destination
        foreach ($job in $SourceJobs) {
            $exists = $null -ne ($DestJobs | Where-Object Name -eq $job.Name)
            $JobsReport += [PSCustomObject]@{
                JobName = $job.Name
                SourceServer = $SourceServer
                ExistsOnSource = "Yes"
                DestinationServer = $DestServer
                ExistsOnDestination = if ($exists) { "Yes" } else { "No" }
            }
        }
        
        # For jobs in destination only, add to report
        foreach ($job in $DestJobs) {
            if ($null -eq ($SourceJobs | Where-Object Name -eq $job.Name)) {
                $JobsReport += [PSCustomObject]@{
                    JobName = $job.Name
                    SourceServer = $SourceServer
                    ExistsOnSource = "No"
                    DestinationServer = $DestServer
                    ExistsOnDestination = "Yes"
                }
            }
        }
        
        # Get Linked Servers from destination server
        Write-Host "  Getting Linked Servers from $DestServer..." -ForegroundColor Green
        $DestLinkedServers = Get-DbaLinkedServer -SqlInstance $DestServer -ErrorAction Stop
        
        # Compare Linked Servers
        Write-Host "  Comparing linked servers..." -ForegroundColor Green
        
        # For linked servers in source, check if they exist in destination
        foreach ($linkedServer in $SourceLinkedServers) {
            $exists = $null -ne ($DestLinkedServers | Where-Object Name -eq $linkedServer.Name)
            $LinkedServersReport += [PSCustomObject]@{
                LinkedServerName = $linkedServer.Name
                SourceServer = $SourceServer
                ExistsOnSource = "Yes"
                DestinationServer = $DestServer
                ExistsOnDestination = if ($exists) { "Yes" } else { "No" }
            }
        }
        
        # For linked servers in destination only, add to report
        foreach ($linkedServer in $DestLinkedServers) {
            if ($null -eq ($SourceLinkedServers | Where-Object Name -eq $linkedServer.Name)) {
                $LinkedServersReport += [PSCustomObject]@{
                    LinkedServerName = $linkedServer.Name
                    SourceServer = $SourceServer
                    ExistsOnSource = "No"
                    DestinationServer = $DestServer
                    ExistsOnDestination = "Yes"
                }
            }
        }
        
        # Get Logins from destination server
        Write-Host "  Getting Logins from $DestServer..." -ForegroundColor Green
        $DestLogins = Get-DbaLogin -SqlInstance $DestServer -ErrorAction Stop | Where-Object {
            $_.Name -notlike '##*' -and 
            $_.Name -notlike 'NT SERVICE\*' -and 
            $_.Name -notlike 'NT AUTHORITY\*' -and 
            $_.Name -ne 'sa'
        }
        
        # Compare Logins
        Write-Host "  Comparing logins..." -ForegroundColor Green
        
        # For logins in source, check if they exist in destination
        foreach ($login in $SourceLogins) {
            $destLogin = $DestLogins | Where-Object Name -eq $login.Name
            $exists = $null -ne $destLogin
            $sidMatch = if ($exists) {
                [System.BitConverter]::ToString($login.Sid) -eq [System.BitConverter]::ToString($destLogin.Sid)
            } else { $false }
            
            $LoginsReport += [PSCustomObject]@{
                LoginName = $login.Name
                SourceServer = $SourceServer
                SourceSID = [System.BitConverter]::ToString($login.Sid)
                ExistsOnSource = "Yes"
                DestinationServer = $DestServer
                DestinationSID = if ($exists) { [System.BitConverter]::ToString($destLogin.Sid) } else { $null }
                ExistsOnDestination = if ($exists) { "Yes" } else { "No" }
                SIDsMatch = if ($sidMatch) { "Yes" } else { "No" }
            }
        }
        
        # For logins in destination only, add to report
        foreach ($login in $DestLogins) {
            if ($null -eq ($SourceLogins | Where-Object Name -eq $login.Name)) {
                $LoginsReport += [PSCustomObject]@{
                    LoginName = $login.Name
                    SourceServer = $SourceServer
                    SourceSID = $null
                    ExistsOnSource = "No"
                    DestinationServer = $DestServer
                    DestinationSID = [System.BitConverter]::ToString($login.Sid)
                    ExistsOnDestination = "Yes"
                    SIDsMatch = "No"
                }
            }
        }
    }
    catch {
        Write-Host "Error connecting to $DestServer or processing data: $_" -ForegroundColor Red
    }
}

# Create HTML report
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportDate = Get-Date -Format "MMMM d, yyyy HH:mm:ss"

# Create HTML report content
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>SQL Server Comparison Reports</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; }
        h2 { color: #009933; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 30px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .mismatch { background-color: #ffe6e6; }
        .missing { background-color: #fff2e6; }
        .summary { margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>SQL Server Comparison Reports</h1>
    <p>Source Server: <strong>$SourceServer</strong></p>
    <p>Destination Servers: <strong>$($DestinationServers -join ', ')</strong></p>
    <p>Generated on: <strong>$reportDate</strong></p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Jobs compared: <strong>$($JobsReport.Count)</strong></p>
        <p>Total Linked Servers compared: <strong>$($LinkedServersReport.Count)</strong></p>
        <p>Total Logins compared: <strong>$($LoginsReport.Count)</strong></p>
        <p>Missing Jobs: <strong>$(($JobsReport | Where-Object { $_.ExistsOnSource -eq "No" -or $_.ExistsOnDestination -eq "No" }).Count)</strong></p>
        <p>Missing Linked Servers: <strong>$(($LinkedServersReport | Where-Object { $_.ExistsOnSource -eq "No" -or $_.ExistsOnDestination -eq "No" }).Count)</strong></p>
        <p>Missing Logins: <strong>$(($LoginsReport | Where-Object { $_.ExistsOnSource -eq "No" -or $_.ExistsOnDestination -eq "No" }).Count)</strong></p>
        <p>SID Mismatches: <strong>$(($LoginsReport | Where-Object { $_.ExistsOnSource -eq "Yes" -and $_.ExistsOnDestination -eq "Yes" -and $_.SIDsMatch -eq "No" }).Count)</strong></p>
    </div>
    
    <h2>SQL Agent Jobs Comparison</h2>
    <table>
        <tr>
            <th>Job Name</th>
            <th>Source Server</th>
            <th>Exists On Source</th>
            <th>Destination Server</th>
            <th>Exists On Destination</th>
        </tr>
"@

foreach ($job in ($JobsReport | Sort-Object DestinationServer, JobName)) {
    $rowClass = ""
    if ($job.ExistsOnSource -eq "No" -or $job.ExistsOnDestination -eq "No") {
        $rowClass = " class='missing'"
    }
    
    $htmlReport += @"
        <tr$rowClass>
            <td>$($job.JobName)</td>
            <td>$($job.SourceServer)</td>
            <td>$($job.ExistsOnSource)</td>
            <td>$($job.DestinationServer)</td>
            <td>$($job.ExistsOnDestination)</td>
        </tr>
"@
}

$htmlReport += @"
    </table>
    
    <h2>Linked Servers Comparison</h2>
    <table>
        <tr>
            <th>Linked Server Name</th>
            <th>Source Server</th>
            <th>Exists On Source</th>
            <th>Destination Server</th>
            <th>Exists On Destination</th>
        </tr>
"@

foreach ($linkedServer in ($LinkedServersReport | Sort-Object DestinationServer, LinkedServerName)) {
    $rowClass = ""
    if ($linkedServer.ExistsOnSource -eq "No" -or $linkedServer.ExistsOnDestination -eq "No") {
        $rowClass = " class='missing'"
    }
    
    $htmlReport += @"
        <tr$rowClass>
            <td>$($linkedServer.LinkedServerName)</td>
            <td>$($linkedServer.SourceServer)</td>
            <td>$($linkedServer.ExistsOnSource)</td>
            <td>$($linkedServer.DestinationServer)</td>
            <td>$($linkedServer.ExistsOnDestination)</td>
        </tr>
"@
}

$htmlReport += @"
    </table>
    
    <h2>Logins Comparison</h2>
    <table>
        <tr>
            <th>Login Name</th>
            <th>Source Server</th>
            <th>Exists On Source</th>
            <th>Destination Server</th>
            <th>Exists On Destination</th>
            <th>SIDs Match</th>
            <th>Source SID</th>
            <th>Destination SID</th>
        </tr>
"@

foreach ($login in ($LoginsReport | Sort-Object DestinationServer, LoginName)) {
    $rowClass = ""
    if ($login.ExistsOnSource -eq "No" -or $login.ExistsOnDestination -eq "No") {
        $rowClass = " class='missing'"
    } elseif ($login.SIDsMatch -eq "No") {
        $rowClass = " class='mismatch'"
    }
    
    $htmlReport += @"
        <tr$rowClass>
            <td>$($login.LoginName)</td>
            <td>$($login.SourceServer)</td>
            <td>$($login.ExistsOnSource)</td>
            <td>$($login.DestinationServer)</td>
            <td>$($login.ExistsOnDestination)</td>
            <td>$($login.SIDsMatch)</td>
            <td>$($login.SourceSID)</td>
            <td>$($login.DestinationSID)</td>
        </tr>
"@
}

$htmlReport += @"
    </table>
    
    <p><em>Color coding: Missing objects are highlighted in orange, SID mismatches are highlighted in red.</em></p>
</body>
</html>
"@

# Save HTML report locally (optional)
$outputPath = "$PSScriptRoot\Reports"
if (-not (Test-Path -Path $outputPath)) {
    New-Item -Path $outputPath -ItemType Directory | Out-Null
}
$htmlReportPath = "$outputPath\SQLServerComparisonReport_$timestamp.html"
$htmlReport | Out-File -FilePath $htmlReportPath -Encoding utf8

Write-Host "`nHTML Report saved to:" -ForegroundColor Cyan
Write-Host "$htmlReportPath" -ForegroundColor Yellow

# Send email with HTML report
try {
    $EmailParams["Subject"] = "SQL Server Comparison Report - $reportDate"
    $EmailParams["Body"] = $htmlReport
    $EmailParams["BodyAsHtml"] = $true
    
    Write-Host "`nSending email report..." -ForegroundColor Cyan
    Send-MailMessage @EmailParams
    Write-Host "Email sent successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error sending email: $_" -ForegroundColor Red
    Write-Host "HTML report is still saved locally at: $htmlReportPath" -ForegroundColor Yellow
}

# Display summary in console
Write-Host "`nComparison Summary:" -ForegroundColor Cyan
Write-Host "Total Jobs compared: $($JobsReport.Count)" -ForegroundColor Green
Write-Host "Total Linked Servers compared: $($LinkedServersReport.Count)" -ForegroundColor Green
Write-Host "Total Logins compared: $($LoginsReport.Count)" -ForegroundColor Green
Write-Host "Missing Jobs: $(($JobsReport | Where-Object { $_.ExistsOnSource -eq 'No' -or $_.ExistsOnDestination -eq 'No' }).Count)" -ForegroundColor Yellow
Write-Host "Missing Linked Servers: $(($LinkedServersReport | Where-Object { $_.ExistsOnSource -eq 'No' -or $_.ExistsOnDestination -eq 'No' }).Count)" -ForegroundColor Yellow
Write-Host "Missing Logins: $(($LoginsReport | Where-Object { $_.ExistsOnSource -eq 'No' -or $_.ExistsOnDestination -eq 'No' }).Count)" -ForegroundColor Yellow
Write-Host "SID Mismatches: $(($LoginsReport | Where-Object { $_.ExistsOnSource -eq 'Yes' -and $_.ExistsOnDestination -eq 'Yes' -and $_.SIDsMatch -eq 'No' }).Count)" -ForegroundColor Yellow
