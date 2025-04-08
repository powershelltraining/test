 
# Parameters
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceServer,
    
    [Parameter(Mandatory = $true)]
    [string[]]$TargetServers,
    
    [Parameter(Mandatory = $true)]
    [string]$EmailTo,
    
    [Parameter(Mandatory = $true)]
    [string]$SmtpServer,
    
    [string]$EmailFrom = "SQLAdmin@gmail.com",
    [string]$EmailSubject = "SQL Server Sync Report - Linked Servers and Logins"
)

# Check if dbatools is installed
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Host "dbatools is not installed."

}


# compare and sync linked servers
function Sync-LinkedServers {
    param (
        [string]$source,
        [string]$target
    )
    
    Write-Host "Comparing linked servers between $source and $target..."
    
    # Get linked servers from source and target
    try {
        $sourceLinkedServers = Get-DbaLinkedServer -SqlInstance $source
        $targetLinkedServers = Get-DbaLinkedServer -SqlInstance $target
    }
    catch {
        return "Error retrieving linked servers: $_"
    }
    
    $linkedServersToAdd = @()
    
    # Compare linked servers
    foreach ($sourceLS in $sourceLinkedServers) {
        $matchingTargetLS = $targetLinkedServers | Where-Object { $_.Name -eq $sourceLS.Name }
        
        if (-not $matchingTargetLS) {
            Write-Host "Linked server $($sourceLS.Name) needs to be added to $target"
            
            try {
                # Get linked server product and provider to configure properly
                $providerName = $sourceLS.ProviderName
                $dataSource = $sourceLS.DataSource
                $location = $sourceLS.Location
                $providerString = $sourceLS.ProviderString
                $catalog = $sourceLS.Catalog
                
                # Create the linked server
                $newLinkedServer = New-DbaLinkedServer -SqlInstance $target -LinkedServer $sourceLS.Name -Provider $providerName -DataSource $dataSource -Location $location -ProviderString $providerString -Catalog $catalog
                
                # Copy the linked server login mappings
                $loginMappings = Get-DbaLinkedServerLogin -SqlInstance $source -LinkedServer $sourceLS.Name
                foreach ($mapping in $loginMappings) {
                    if (-not [string]::IsNullOrEmpty($mapping.RemoteUser)) {
                        New-DbaLinkedServerLogin -SqlInstance $target -LinkedServer $sourceLS.Name -LocalLogin $mapping.LocalLogin -RemoteUser $mapping.RemoteUser -RemotePassword $mapping.RemotePassword
                    }
                }
                
                $linkedServersToAdd += "Added linked server $($sourceLS.Name) to $target"
            }
            catch {
                $linkedServersToAdd += "Failed to add linked server $($sourceLS.Name) to $target: $_"
            }
        }
    }
    
    return $linkedServersToAdd
}

# compare and sync logins
function Sync-Logins {
    param (
        [string]$source,
        [string]$target
    )
    
    Write-Host "Comparing logins between $source and $target..."
    
    $loginsToAdd = @()
    
    try {
        # Get logins from both servers (excluding system logins)
        $sourceLogins = Get-DbaLogin -SqlInstance $source | Where-Object { $_.LoginType -ne "SqlLogin" -or ($_.LoginType -eq "SqlLogin" -and $_.IsSystemObject -eq $false) }
        $targetLogins = Get-DbaLogin -SqlInstance $target
        
        # Find logins that exist in source but not in target
        foreach ($login in $sourceLogins) {
            $loginExists = $targetLogins | Where-Object { $_.Name -eq $login.Name }
            
            if (-not $loginExists) {
                Write-Host "Login $($login.Name) needs to be added to $target"
                
                try {
                    # Copy the login to the target server
                    Copy-DbaLogin -Source $source -Destination $target -Login $login.Name -Force
                    $loginsToAdd += "Added login $($login.Name) to $target"
                }
                catch {
                    $loginsToAdd += "Failed to add login $($login.Name) to $target: $_"
                }
            }
        }
    }
    catch {
        return "Error comparing logins: $_"
    }
    
    return $loginsToAdd
}

# Main execution
$reportBody = "SQL Server Sync Report`n`n"
$reportBody += "Source Server: $SourceServer`n"
$reportBody += "Target Servers: $($TargetServers -join ', ')`n`n"

$allLinkedServersAdded = @()
$allLoginsAdded = @()

foreach ($targetServer in $TargetServers) {
    $reportBody += "==== Synchronizing $targetServer ====`n"
    
    # Sync linked servers
    $linkedServersAdded = Sync-LinkedServers -source $SourceServer -target $targetServer
    if ($linkedServersAdded.Count -gt 0) {
        $reportBody += "`nLinked Servers Added:`n"
        $reportBody += ($linkedServersAdded | ForEach-Object { "- $_" }) -join "`n"
        $allLinkedServersAdded += $linkedServersAdded
    } else {
        $reportBody += "`nNo linked servers needed to be added.`n"
    }
    
    # Sync logins
    $loginsAdded = Sync-Logins -source $SourceServer -target $targetServer
    if ($loginsAdded.Count -gt 0) {
        $reportBody += "`nLogins Added:`n"
        $reportBody += ($loginsAdded | ForEach-Object { "- $_" }) -join "`n"
        $allLoginsAdded += $loginsAdded
    } else {
        $reportBody += "`nNo logins needed to be added.`n"
    }
    
    $reportBody += "`n"
}

# Summary
$reportBody += "==== Summary ====`n"
$reportBody += "Total linked servers added: $($allLinkedServersAdded.Count)`n"
$reportBody += "Total logins added: $($allLoginsAdded.Count)`n"

# Display report
Write-Host $reportBody

# Send email report
try {
    Send-MailMessage -From $EmailFrom -To $EmailTo -Subject $EmailSubject -Body $reportBody -SmtpServer $SmtpServer
    Write-Host "Email report sent successfully to $EmailTo"
}
catch {
    Write-Error "Failed to send email report: $_"
}
