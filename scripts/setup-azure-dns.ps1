# Setup Azure DNS for CloudToLocalLLM
# This script creates an Azure DNS zone and all required DNS records

$ErrorActionPreference = "Stop"

# Configuration
$RESOURCE_GROUP = "cloudtolocalllm-rg"
$DNS_ZONE_NAME = "cloudtolocalllm.online"
$AKS_CLUSTER_NAME = "cloudtolocalllm-aks"
$TTL = 300

# DNS records to create
$DOMAINS = @(
    "cloudtolocalllm.online",
    "app.cloudtolocalllm.online",
    "api.cloudtolocalllm.online",
    "auth.cloudtolocalllm.online"
)

Write-Host "🔧 Setting up Azure DNS for $DNS_ZONE_NAME..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Get AKS credentials
Write-Host "📋 Step 1: Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_CLUSTER_NAME `
  --overwrite-existing

# Step 2: Get Load Balancer IP
Write-Host ""
Write-Host "📋 Step 2: Getting Load Balancer IP..." -ForegroundColor Yellow
$LB_IP = kubectl get svc -n ingress-nginx ingress-nginx-controller `
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

if (-not $LB_IP) {
    Write-Host "❌ Error: Could not retrieve Load Balancer IP" -ForegroundColor Red
    Write-Host "Please ensure the ingress-nginx controller is deployed and has an external IP" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Load Balancer IP: $LB_IP" -ForegroundColor Green
Write-Host ""

# Step 3: Create Azure DNS zone (if it doesn't exist)
Write-Host "📋 Step 3: Creating Azure DNS zone..." -ForegroundColor Yellow
$zoneExists = az network dns zone show `
  --resource-group $RESOURCE_GROUP `
  --name $DNS_ZONE_NAME 2>$null

if ($zoneExists) {
    Write-Host "✅ DNS zone already exists" -ForegroundColor Green
} else {
    Write-Host "Creating DNS zone..." -ForegroundColor Cyan
    az network dns zone create `
      --resource-group $RESOURCE_GROUP `
      --name $DNS_ZONE_NAME
    Write-Host "✅ DNS zone created" -ForegroundColor Green
}
Write-Host ""

# Step 4: Get nameservers
Write-Host "📋 Step 4: Getting nameservers..." -ForegroundColor Yellow
$zoneInfo = az network dns zone show `
  --resource-group $RESOURCE_GROUP `
  --name $DNS_ZONE_NAME `
  --query "nameServers" -o json | ConvertFrom-Json

Write-Host "Azure DNS Nameservers:" -ForegroundColor Cyan
foreach ($ns in $zoneInfo) {
    Write-Host "  - $ns" -ForegroundColor White
}
Write-Host ""

# Step 5: Create DNS records
Write-Host "📋 Step 5: Creating DNS records..." -ForegroundColor Yellow

foreach ($domain in $DOMAINS) {
    # Extract subdomain name
    if ($domain -eq "cloudtolocalllm.online") {
        $record_name = "@"
    } else {
        $record_name = $domain -replace '\.cloudtolocalllm\.online$', ''
    }
    
    Write-Host "Creating/updating: $domain → $LB_IP" -ForegroundColor Cyan
    
    # Check if record exists
    $recordExists = az network dns record-set a show `
      --resource-group $RESOURCE_GROUP `
      --zone-name $DNS_ZONE_NAME `
      --name $record_name 2>$null
    
    if ($recordExists) {
        # Update existing record
        az network dns record-set a update `
          --resource-group $RESOURCE_GROUP `
          --zone-name $DNS_ZONE_NAME `
          --name $record_name `
          --set "aRecords[0].ipv4Address=$LB_IP" "ttl=$TTL" | Out-Null
        Write-Host "  ✅ Updated" -ForegroundColor Green
    } else {
        # Create new record
        az network dns record-set a create `
          --resource-group $RESOURCE_GROUP `
          --zone-name $DNS_ZONE_NAME `
          --name $record_name `
          --ttl $TTL | Out-Null
        
        az network dns record-set a add-record `
          --resource-group $RESOURCE_GROUP `
          --zone-name $DNS_ZONE_NAME `
          --record-set-name $record_name `
          --ipv4-address $LB_IP | Out-Null
        Write-Host "  ✅ Created" -ForegroundColor Green
    }
}

Write-Host ""

# Step 6: List all records
Write-Host "📋 Step 6: Current DNS records in Azure DNS:" -ForegroundColor Yellow
Write-Host ""
az network dns record-set list `
  --resource-group $RESOURCE_GROUP `
  --zone-name $DNS_ZONE_NAME `
  --output table

Write-Host ""
Write-Host "✅ Azure DNS setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📝 NEXT STEPS - Configure Namecheap:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Go to Namecheap Dashboard → Domain List → Manage" -ForegroundColor White
Write-Host "2. Go to 'Nameservers' section" -ForegroundColor White
Write-Host "3. Select 'Custom DNS'" -ForegroundColor White
Write-Host "4. Enter these nameservers:" -ForegroundColor White
Write-Host ""
foreach ($ns in $zoneInfo) {
    Write-Host "   $ns" -ForegroundColor White
}
Write-Host ""
Write-Host "5. Click 'Save'" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  DNS propagation can take 5 minutes to 48 hours (usually 5-15 minutes)" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 DNS Records Summary:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
foreach ($domain in $DOMAINS) {
    Write-Host "  $domain → $LB_IP (TTL: ${TTL}s)" -ForegroundColor White
}
Write-Host ""

