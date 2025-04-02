
# Define the path to the servers list file
$serversListPath = ".\servers.txt"

# Email configuration  
$emailParams = @{
    SmtpServer = "smtp.gmail.com"
    Port = 25
    From = "sqlmonitoring@gmail.com"
    To = "admin@gmail.com"  # Can be comma-separated list: "admin1@domain.com,admin2@domain.com"
    Subject = "SQL Server SSL Certificate Status Report - $(Get-Date -Format 'yyyy-MM-dd')"
    # UseSsl = $true  # Uncomment if SSL is required
    # Credential = $credential  # Uncomment and set if authentication is required
}

# Check if the servers file exists
if (-not (Test-Path $serversListPath)) {
    Write-Error "Server list file not found at $serversListPath"
    exit 1
}

# Read the list of servers from the file
$servers = Get-Content $serversListPath | Where-Object { $_ -match '\S' }

# Create a timestamp for the report filename
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = ".\SSL_Certificate_Report_$timestamp.csv"

Write-Host "Checking SSL certificates on $(($servers | Measure-Object).Count) SQL Servers..."

# Initialize a collection for results
$results = @()

foreach ($serverName in $servers) {
    Write-Host "Processing server: $serverName" -ForegroundColor Cyan
    
    try {
        # Get SSL certificate information using DbaTools
        $certificates = Get-DbaComputerCertificate -ComputerName $serverName -ErrorAction Stop
        
        # Filter for SQL Server related certificates
        $sqlCertificates = $certificates | Where-Object {
            ($_.Subject -like "*SQL*") -or 
            ($_.FriendlyName -like "*SQL*") -or
            ($_.DnsNameList -like "*SQL*") -or
            ($_.EnhancedKeyUsageList -like "*SQL*")
        }
        
        if ($sqlCertificates.Count -eq 0) {
            Write-Host "  No SQL Server certificates found on $serverName" -ForegroundColor Yellow
            
            # Add a result entry for servers with no certificates
            $results += [PSCustomObject]@{
                ServerName = $serverName
                CertificateName = "No SQL certificates found"
                Thumbprint = "N/A"
                NotBefore = "N/A"
                NotAfter = "N/A"
                IsExpired = "N/A"
                DaysUntilExpiration = "N/A"
                Status = "WARNING: No SQL certificates found"
            }
        }
        else {
            foreach ($cert in $sqlCertificates) {
                # Calculate expiration status
                $now = Get-Date
                $isExpired = $cert.NotAfter -lt $now
                $daysUntilExpiration = ($cert.NotAfter - $now).Days
                
                # Determine status
                $status = if ($isExpired) {
                    "EXPIRED"
                } elseif ($daysUntilExpiration -le 30) {
                    "WARNING: Expires in $daysUntilExpiration days"
                } else {
                    "OK"
                }
                
                # Output certificate information
                if ($isExpired) {
                    Write-Host "  [EXPIRED] $($cert.FriendlyName) - Expired on $($cert.NotAfter)" -ForegroundColor Red
                } elseif ($daysUntilExpiration -le 30) {
                    Write-Host "  [WARNING] $($cert.FriendlyName) - Expires in $daysUntilExpiration days" -ForegroundColor Yellow
                } else {
                    Write-Host "  [OK] $($cert.FriendlyName) - Valid until $($cert.NotAfter)" -ForegroundColor Green
                }
                
                # Add to results collection
                $results += [PSCustomObject]@{
                    ServerName = $serverName
                    CertificateName = $cert.FriendlyName
                    Thumbprint = $cert.Thumbprint
                    Subject = $cert.Subject
                    NotBefore = $cert.NotBefore
                    NotAfter = $cert.NotAfter
                    IsExpired = $isExpired
                    DaysUntilExpiration = $daysUntilExpiration
                    Status = $status
                }
            }
        }
    }
    catch {
        Write-Host "  [ERROR] Failed to check certificates on $serverName. Error: $($_.Exception.Message)" -ForegroundColor Red
        
        # Add error entry to results
        $results += [PSCustomObject]@{
            ServerName = $serverName
            CertificateName = "ERROR"
            Thumbprint = "N/A"
            NotBefore = "N/A"
            NotAfter = "N/A"
            IsExpired = "N/A"
            DaysUntilExpiration = "N/A"
            Status = "ERROR: $($_.Exception.Message)"
        }
    }
}

# Export results to CSV
$results | Export-Csv -Path $reportFile -NoTypeInformation

# Generate HTML report for email
$expiredCount = ($results | Where-Object {$_.Status -eq 'EXPIRED'} | Select-Object -Unique ServerName | Measure-Object).Count
$warningCount = ($results | Where-Object {$_.Status -like 'WARNING*' -and $_.Status -ne 'WARNING: No SQL certificates found'} | Select-Object -Unique ServerName | Measure-Object).Count
$errorCount = ($results | Where-Object {$_.Status -like 'ERROR*'} | Select-Object -Unique ServerName | Measure-Object).Count

# Create HTML report with styling
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #0066cc; }
        table { border-collapse: collapse; width: 100%; }
        th, td { padding: 8px; text-align: left; border: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr.expired { background-color: #ffcccc; }
        tr.warning { background-color: #fff4cc; }
        tr.error { background-color: #f2f2f2; }
        .summary { margin: 20px 0; padding: 10px; background-color: #f2f2f2; border-radius: 5px; }
        .expired { color: red; }
        .warning { color: orange; }
        .error { color: gray; }
    </style>
</head>
<body>
    <h1>SQL Server SSL Certificate Status Report</h1>
    <p>Report generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total servers checked: $(($servers | Measure-Object).Count)</p>
        <p class="expired">Servers with expired certificates: $expiredCount</p>
        <p class="warning">Servers with certificates expiring within 30 days: $warningCount</p>
        <p class="error">Servers with errors: $errorCount</p>
    </div>

    <h2>Certificate Details</h2>
    <table>
        <tr>
            <th>Server Name</th>
            <th>Certificate Name</th>
            <th>Not After</th>
            <th>Days Until Expiration</th>
            <th>Status</th>
        </tr>
"@

foreach ($result in $results) {
    $rowClass = switch -Wildcard ($result.Status) {
        "EXPIRED" { "expired" }
        "WARNING*" { "warning" }
        "ERROR*" { "error" }
        default { "" }
    }
    
    $htmlReport += @"
        <tr class="$rowClass">
            <td>$($result.ServerName)</td>
            <td>$($result.CertificateName)</td>
            <td>$($result.NotAfter)</td>
            <td>$($result.DaysUntilExpiration)</td>
            <td>$($result.Status)</td>
        </tr>
"@
}

$htmlReport += @"
    </table>
    
    <p>For detailed information, please refer to the attached CSV report.</p>
</body>
</html>
"@

# Send email with HTML body and CSV attachment
try {
    Write-Host "`nSending email report..." -ForegroundColor Cyan
    
    # Update email parameters with body and attachment
    $emailParams.Body = $htmlReport
    $emailParams.BodyAsHtml = $true
    $emailParams.Attachments = $reportFile
    
    # Send the email
    Send-MailMessage @emailParams
    
    Write-Host "Email sent successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to send email. Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nResults saved to $reportFile" -ForegroundColor Green
Write-Host "`nSummary:"
Write-Host "- Total servers checked: $(($servers | Measure-Object).Count)"
Write-Host "- Servers with expired certificates: $expiredCount"
Write-Host "- Servers with certificates expiring within 30 days: $warningCount"
Write-Host "- Servers with errors: $errorCount"
