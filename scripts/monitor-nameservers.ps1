# Monitor nameservers until they change to Azure DNS nameservers
# Simple, reliable version

$ErrorActionPreference = "Continue"

# Azure DNS nameservers we expect
$expectedNameservers = @(
    "ns1-03.azure-dns.com",
    "ns2-03.azure-dns.net",
    "ns3-03.azure-dns.org",
    "ns4-03.azure-dns.info"
)

$domain = "cloudtolocalllm.online"
$checkInterval = 30 # seconds
$attempt = 0

Write-Host "🔍 Monitoring nameservers for $domain..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Expected Azure DNS nameservers:" -ForegroundColor Yellow
foreach ($ns in $expectedNameservers) {
    Write-Host "  • $ns" -ForegroundColor White
}
Write-Host ""
Write-Host "Checking every $checkInterval seconds..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

function Get-NameServers {
    param([string]$domainName)
    
    try {
        # Use Resolve-DnsName with timeout
        $job = Start-Job -ScriptBlock {
            param($name)
            try {
                Resolve-DnsName -Name $name -Type NS -Server 8.8.8.8 -ErrorAction Stop | 
                    Where-Object { $_.Type -eq "NS" } | 
                    ForEach-Object { $_.NameHost.ToLower().TrimEnd('.') } | 
                    Sort-Object -Unique
            } catch {
                $null
            }
        } -ArgumentList $domainName
        
        $result = $job | Wait-Job -Timeout 10 | Receive-Job
        $job | Remove-Job -Force -ErrorAction SilentlyContinue
        
        if ($result) {
            return $result
        }
    } catch {
        # Silently continue
    }
    
    try {
        # Fallback: Try with 1.1.1.1
        $job = Start-Job -ScriptBlock {
            param($name)
            try {
                Resolve-DnsName -Name $name -Type NS -Server 1.1.1.1 -ErrorAction Stop | 
                    Where-Object { $_.Type -eq "NS" } | 
                    ForEach-Object { $_.NameHost.ToLower().TrimEnd('.') } | 
                    Sort-Object -Unique
            } catch {
                $null
            }
        } -ArgumentList $domainName
        
        $result = $job | Wait-Job -Timeout 10 | Receive-Job
        $job | Remove-Job -Force -ErrorAction SilentlyContinue
        
        return $result
    } catch {
        return $null
    }
}

function Test-AzureNameservers {
    param([array]$current, [array]$expected)
    
    if ($null -eq $current -or $current.Count -eq 0) {
        return $false
    }
    
    # Check if at least 2 Azure nameservers are present
    $azureCount = 0
    foreach ($ns in $current) {
        foreach ($expectedNs in $expected) {
            if ($ns -like "*$expectedNs*" -or $expectedNs -like "*$ns*") {
                $azureCount++
                break
            }
        }
    }
    
    # Need at least 2 matching Azure nameservers
    return $azureCount -ge 2
}

try {
    while ($true) {
        $attempt++
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        Write-Host "[$timestamp] Attempt #$attempt" -ForegroundColor Cyan
        
        # Query nameservers with timeout
        $currentNameservers = Get-NameServers -domainName $domain
        
        if ($null -eq $currentNameservers -or $currentNameservers.Count -eq 0) {
            Write-Host "  ⚠️  Could not retrieve nameservers" -ForegroundColor Yellow
        } else {
            Write-Host "  Current nameservers:" -ForegroundColor White
            $hasAzure = $false
            foreach ($ns in $currentNameservers) {
                $isAzure = $false
                foreach ($expectedNs in $expectedNameservers) {
                    if ($ns -like "*$expectedNs*" -or $expectedNs -like "*$ns*") {
                        Write-Host "    ✅ $ns (Azure DNS)" -ForegroundColor Green
                        $isAzure = $true
                        $hasAzure = $true
                        break
                    }
                }
                if (-not $isAzure) {
                    Write-Host "    ⚠️  $ns" -ForegroundColor Yellow
                }
            }
            
            # Check if Azure nameservers are active
            if (Test-AzureNameservers -current $currentNameservers -expected $expectedNameservers) {
                Write-Host ""
                Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
                Write-Host "✅ SUCCESS! Azure DNS nameservers are now active!" -ForegroundColor Green
                Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
                Write-Host ""
                Write-Host "DNS propagation is in progress. Full propagation may take 5-15 minutes." -ForegroundColor Yellow
                Write-Host ""
                break
            } else {
                Write-Host "  ⏳ Still waiting for Azure DNS nameservers..." -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Start-Sleep -Seconds $checkInterval
    }
} catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host "Monitoring stopped." -ForegroundColor Yellow
} finally {
    # Clean up any background jobs
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
}
