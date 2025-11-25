# Setup Cloudflare DNS Integration for AWS EKS
# This script updates Cloudflare DNS records to point to the AWS Network Load Balancer (NLB)
# and configures SSL/TLS settings for the CloudToLocalLLM application
#
# Prerequisites:
# - AWS CLI configured with credentials
# - CLOUDFLARE_API_TOKEN environment variable set
# - EKS cluster deployed with ingress controller
# - Cloudflare zone already created for cloudtolocalllm.online

$ErrorActionPreference = "Stop"

# Configuration
$AWS_REGION = "us-east-1"
$EKS_CLUSTER_NAME = "cloudtolocalllm-eks"
$NAMESPACE = "cloudtolocalllm"
$ZONE_NAME = "cloudtolocalllm.online"
$DOMAINS = @(
    "cloudtolocalllm.online",
    "app.cloudtolocalllm.online",
    "api.cloudtolocalllm.online",
    "auth.cloudtolocalllm.online"
)

# Validate prerequisites
function Validate-Prerequisites {
    Write-Host "🔍 Validating prerequisites..." -ForegroundColor Cyan
    
    # Check if CLOUDFLARE_API_TOKEN is set
    if (-not $env:CLOUDFLARE_API_TOKEN) {
        Write-Host "❌ Error: CLOUDFLARE_API_TOKEN environment variable is not set" -ForegroundColor Red
        Write-Host "Please set it with: `$env:CLOUDFLARE_API_TOKEN='your_token'" -ForegroundColor Yellow
        exit 1
    }
    
    # Check if AWS CLI is available
    try {
        $null = aws --version
    } catch {
        Write-Host "❌ Error: AWS CLI is not installed or not in PATH" -ForegroundColor Red
        exit 1
    }
    
    # Check if kubectl is available
    try {
        $null = kubectl version --client
    } catch {
        Write-Host "❌ Error: kubectl is not installed or not in PATH" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ All prerequisites validated" -ForegroundColor Green
}

# Get Cloudflare Zone ID
function Get-CloudflareZoneId {
    param([string]$ZoneName)
    
    Write-Host "🔍 Getting Cloudflare Zone ID for $ZoneName..." -ForegroundColor Cyan
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones?name=$ZoneName" `
            -Method GET `
            -Headers @{
                "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            }
        
        if ($response.success -and $response.result.Count -gt 0) {
            $zoneId = $response.result[0].id
            Write-Host "✅ Zone ID: $zoneId" -ForegroundColor Green
            return $zoneId
        } else {
            Write-Host "❌ Zone not found: $ZoneName" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "❌ Error getting Cloudflare Zone ID: $_" -ForegroundColor Red
        exit 1
    }
}

# Get AWS NLB endpoint
function Get-NLBEndpoint {
    Write-Host "🔍 Getting AWS NLB endpoint..." -ForegroundColor Cyan
    
    try {
        # Update kubeconfig
        Write-Host "Updating kubeconfig..." -ForegroundColor Gray
        aws eks update-kubeconfig `
            --name $EKS_CLUSTER_NAME `
            --region $AWS_REGION | Out-Null
        
        # Get the ingress endpoint
        Write-Host "Retrieving ingress endpoint..." -ForegroundColor Gray
        $ingress = kubectl get ingress -n $NAMESPACE -o json | ConvertFrom-Json
        
        if ($ingress.items.Count -eq 0) {
            Write-Host "❌ No ingress found in namespace $NAMESPACE" -ForegroundColor Red
            exit 1
        }
        
        # Get the load balancer hostname or IP
        $nlbEndpoint = $ingress.items[0].status.loadBalancer.ingress[0].hostname
        
        if (-not $nlbEndpoint) {
            $nlbEndpoint = $ingress.items[0].status.loadBalancer.ingress[0].ip
        }
        
        if (-not $nlbEndpoint) {
            Write-Host "❌ Could not determine NLB endpoint" -ForegroundColor Red
            Write-Host "Ingress status:" -ForegroundColor Yellow
            $ingress.items[0].status | ConvertTo-Json
            exit 1
        }
        
        Write-Host "✅ NLB Endpoint: $nlbEndpoint" -ForegroundColor Green
        return $nlbEndpoint
    } catch {
        Write-Host "❌ Error getting NLB endpoint: $_" -ForegroundColor Red
        exit 1
    }
}

# Resolve NLB hostname to IP if needed
function Resolve-NLBHostname {
    param([string]$Hostname)
    
    Write-Host "🔍 Resolving NLB hostname to IP address..." -ForegroundColor Cyan
    
    try {
        # If it's already an IP, return it
        if ($Hostname -match '^\d+\.\d+\.\d+\.\d+$') {
            Write-Host "✅ NLB IP: $Hostname" -ForegroundColor Green
            return $Hostname
        }
        
        # Resolve hostname to IP
        $ipAddress = [System.Net.Dns]::GetHostAddresses($Hostname) | Select-Object -First 1 -ExpandProperty IPAddressToString
        
        if ($ipAddress) {
            Write-Host "✅ NLB IP: $ipAddress" -ForegroundColor Green
            return $ipAddress
        } else {
            Write-Host "❌ Could not resolve hostname: $Hostname" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "❌ Error resolving hostname: $_" -ForegroundColor Red
        exit 1
    }
}

# Update Cloudflare DNS records
function Update-CloudflareDNSRecords {
    param(
        [string]$ZoneId,
        [string]$NLBEndpoint,
        [string[]]$Domains
    )
    
    Write-Host "🔄 Updating Cloudflare DNS records..." -ForegroundColor Cyan
    
    foreach ($domain in $Domains) {
        Write-Host "  Updating DNS record for: $domain" -ForegroundColor Gray
        
        try {
            # Get existing DNS record
            $recordResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records?name=$domain" `
                -Method GET `
                -Headers @{
                    "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                    "Content-Type" = "application/json"
                }
            
            if ($recordResponse.success -and $recordResponse.result.Count -gt 0) {
                # Update existing record
                $recordId = $recordResponse.result[0].id
                $recordType = $recordResponse.result[0].type
                
                Write-Host "    Found existing $recordType record (ID: $recordId)" -ForegroundColor Gray
                
                # Update the record
                $updateResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records/$recordId" `
                    -Method PUT `
                    -Headers @{
                        "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                        "Content-Type" = "application/json"
                    } `
                    -Body (@{
                        type = $recordType
                        name = $domain
                        content = $NLBEndpoint
                        ttl = 300
                        proxied = $true
                    } | ConvertTo-Json)
                
                if ($updateResponse.success) {
                    Write-Host "    ✅ Updated DNS record for $domain" -ForegroundColor Green
                } else {
                    Write-Host "    ❌ Failed to update DNS record for $domain" -ForegroundColor Red
                    $updateResponse.errors | ConvertTo-Json
                    exit 1
                }
            } else {
                # Create new A record
                Write-Host "    Creating new A record for $domain" -ForegroundColor Gray
                
                $createResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records" `
                    -Method POST `
                    -Headers @{
                        "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                        "Content-Type" = "application/json"
                    } `
                    -Body (@{
                        type = "A"
                        name = $domain
                        content = $NLBEndpoint
                        ttl = 300
                        proxied = $true
                    } | ConvertTo-Json)
                
                if ($createResponse.success) {
                    Write-Host "    ✅ Created DNS record for $domain" -ForegroundColor Green
                } else {
                    Write-Host "    ❌ Failed to create DNS record for $domain" -ForegroundColor Red
                    $createResponse.errors | ConvertTo-Json
                    exit 1
                }
            }
        } catch {
            Write-Host "    ❌ Error updating DNS record for $domain : $_" -ForegroundColor Red
            exit 1
        }
    }
}

# Configure Cloudflare SSL/TLS settings
function Configure-CloudflareSSL {
    param([string]$ZoneId)
    
    Write-Host "🔐 Configuring Cloudflare SSL/TLS settings..." -ForegroundColor Cyan
    
    try {
        # Set SSL mode to "Full" (strict)
        Write-Host "  Setting SSL mode to 'Full (strict)'..." -ForegroundColor Gray
        $sslResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/settings/ssl" `
            -Method PATCH `
            -Headers @{
                "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            } `
            -Body (@{
                value = "full"
            } | ConvertTo-Json)
        
        if ($sslResponse.success) {
            Write-Host "  ✅ SSL mode set to 'Full (strict)'" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to set SSL mode" -ForegroundColor Red
            $sslResponse.errors | ConvertTo-Json
            exit 1
        }
        
        # Enable "Always Use HTTPS"
        Write-Host "  Enabling 'Always Use HTTPS'..." -ForegroundColor Gray
        $httpsResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/settings/always_use_https" `
            -Method PATCH `
            -Headers @{
                "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            } `
            -Body (@{
                value = "on"
            } | ConvertTo-Json)
        
        if ($httpsResponse.success) {
            Write-Host "  ✅ 'Always Use HTTPS' enabled" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to enable 'Always Use HTTPS'" -ForegroundColor Red
            $httpsResponse.errors | ConvertTo-Json
            exit 1
        }
        
        # Enable HSTS (HTTP Strict Transport Security)
        Write-Host "  Enabling HSTS..." -ForegroundColor Gray
        $hstsResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/settings/security_header" `
            -Method PATCH `
            -Headers @{
                "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            } `
            -Body (@{
                value = @{
                    enabled = $true
                    max_age = 31536000
                    include_subdomains = $true
                    preload = $true
                }
            } | ConvertTo-Json)
        
        if ($hstsResponse.success) {
            Write-Host "  ✅ HSTS enabled" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Warning: Could not enable HSTS (may not be available on this plan)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ Error configuring SSL/TLS settings: $_" -ForegroundColor Red
        exit 1
    }
}

# Enable Cloudflare security features
function Enable-CloudflareSecurityFeatures {
    param([string]$ZoneId)
    
    Write-Host "🛡️  Enabling Cloudflare security features..." -ForegroundColor Cyan
    
    try {
        # Enable Automatic HTTPS Rewrites
        Write-Host "  Enabling Automatic HTTPS Rewrites..." -ForegroundColor Gray
        $rewriteResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/settings/automatic_https_rewrites" `
            -Method PATCH `
            -Headers @{
                "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            } `
            -Body (@{
                value = "on"
            } | ConvertTo-Json)
        
        if ($rewriteResponse.success) {
            Write-Host "  ✅ Automatic HTTPS Rewrites enabled" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Warning: Could not enable Automatic HTTPS Rewrites" -ForegroundColor Yellow
        }
        
        # Set Security Level to "High"
        Write-Host "  Setting Security Level to 'High'..." -ForegroundColor Gray
        $securityResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/settings/security_level" `
            -Method PATCH `
            -Headers @{
                "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            } `
            -Body (@{
                value = "high"
            } | ConvertTo-Json)
        
        if ($securityResponse.success) {
            Write-Host "  ✅ Security Level set to 'High'" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Warning: Could not set Security Level" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ Error enabling security features: $_" -ForegroundColor Red
        exit 1
    }
}

# Verify DNS resolution
function Verify-DNSResolution {
    param([string[]]$Domains)
    
    Write-Host "✅ Verifying DNS resolution..." -ForegroundColor Cyan
    
    $allResolved = $true
    
    foreach ($domain in $Domains) {
        Write-Host "  Checking DNS resolution for: $domain" -ForegroundColor Gray
        
        try {
            # Wait a moment for DNS to propagate
            Start-Sleep -Seconds 2
            
            # Resolve the domain
            $resolved = [System.Net.Dns]::GetHostAddresses($domain) | Select-Object -First 1 -ExpandProperty IPAddressToString
            
            if ($resolved) {
                Write-Host "    ✅ $domain resolves to $resolved" -ForegroundColor Green
            } else {
                Write-Host "    ⚠️  $domain could not be resolved (DNS may still be propagating)" -ForegroundColor Yellow
                $allResolved = $false
            }
        } catch {
            Write-Host "    ⚠️  Error resolving $domain : $_" -ForegroundColor Yellow
            $allResolved = $false
        }
    }
    
    if ($allResolved) {
        Write-Host "✅ All domains resolved successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some domains could not be resolved (DNS may still be propagating, please wait a few minutes)" -ForegroundColor Yellow
    }
}

# Purge Cloudflare cache
function Purge-CloudflareCache {
    param([string]$ZoneId)
    
    Write-Host "🔄 Purging Cloudflare cache..." -ForegroundColor Cyan
    
    try {
        $purgeResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$ZoneId/purge_cache" `
            -Method POST `
            -Headers @{
                "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            } `
            -Body (@{
                purge_everything = $true
            } | ConvertTo-Json)
        
        if ($purgeResponse.success) {
            Write-Host "✅ Cloudflare cache purged" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Warning: Could not purge Cloudflare cache" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Warning: Error purging Cloudflare cache: $_" -ForegroundColor Yellow
    }
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Cloudflare DNS Integration for AWS EKS                        ║" -ForegroundColor Cyan
    Write-Host "║  CloudToLocalLLM Deployment                                   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Validate prerequisites
    Validate-Prerequisites
    Write-Host ""
    
    # Get Cloudflare Zone ID
    $zoneId = Get-CloudflareZoneId -ZoneName $ZONE_NAME
    Write-Host ""
    
    # Get AWS NLB endpoint
    $nlbEndpoint = Get-NLBEndpoint
    Write-Host ""
    
    # Resolve NLB hostname to IP if needed
    $nlbIp = Resolve-NLBHostname -Hostname $nlbEndpoint
    Write-Host ""
    
    # Update Cloudflare DNS records
    Update-CloudflareDNSRecords -ZoneId $zoneId -NLBEndpoint $nlbIp -Domains $DOMAINS
    Write-Host ""
    
    # Configure SSL/TLS settings
    Configure-CloudflareSSL -ZoneId $zoneId
    Write-Host ""
    
    # Enable security features
    Enable-CloudflareSecurityFeatures -ZoneId $zoneId
    Write-Host ""
    
    # Purge cache
    Purge-CloudflareCache -ZoneId $zoneId
    Write-Host ""
    
    # Verify DNS resolution
    Verify-DNSResolution -Domains $DOMAINS
    Write-Host ""
    
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✅ Cloudflare DNS Integration Complete!                      ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  - Zone ID: $zoneId" -ForegroundColor White
    Write-Host "  - NLB Endpoint: $nlbIp" -ForegroundColor White
    Write-Host "  - Domains Updated: $($DOMAINS.Count)" -ForegroundColor White
    Write-Host "  - SSL Mode: Full (strict)" -ForegroundColor White
    Write-Host "  - Always Use HTTPS: Enabled" -ForegroundColor White
    Write-Host "  - Security Level: High" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Wait 5-10 minutes for DNS propagation" -ForegroundColor White
    Write-Host "  2. Visit https://cloudtolocalllm.online to verify" -ForegroundColor White
    Write-Host "  3. Check SSL certificate status" -ForegroundColor White
    Write-Host "  4. Monitor application logs for any issues" -ForegroundColor White
    Write-Host ""
}

# Run main function
Main
