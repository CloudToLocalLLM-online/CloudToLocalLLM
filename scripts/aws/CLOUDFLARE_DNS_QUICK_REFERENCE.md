# Cloudflare DNS Integration - Quick Reference

## Quick Start

### Prerequisites
- AWS CLI configured
- kubectl configured for EKS cluster
- Cloudflare API token

### Setup (Windows)
```powershell
$env:CLOUDFLARE_API_TOKEN = 'your_token'
.\setup-cloudflare-dns-aws-eks.ps1
```

### Setup (Linux/macOS)
```bash
export CLOUDFLARE_API_TOKEN='your_token'
./setup-cloudflare-dns-aws-eks.sh
```

## What Gets Configured

### DNS Records
- `cloudtolocalllm.online` → NLB IP
- `app.cloudtolocalllm.online` → NLB IP
- `api.cloudtolocalllm.online` → NLB IP
- `auth.cloudtolocalllm.online` → NLB IP

### SSL/TLS
- Mode: Full (strict)
- Always Use HTTPS: Enabled
- HSTS: Enabled

### Security
- Automatic HTTPS Rewrites: Enabled
- Security Level: High

## Verification

```bash
# Check DNS
dig cloudtolocalllm.online

# Check SSL
curl -I https://cloudtolocalllm.online

# Check app
curl https://cloudtolocalllm.online/health
```

## Troubleshooting

### DNS Not Resolving
1. Wait 5-10 minutes for propagation
2. Clear DNS cache: `ipconfig /flushdns` (Windows)
3. Check Cloudflare dashboard

### SSL Certificate Error
1. Verify SSL mode is "Full (strict)"
2. Wait for certificate to be issued
3. Clear browser cache

### Application Not Accessible
1. Check NLB: `kubectl get svc -n cloudtolocalllm`
2. Check ingress: `kubectl get ingress -n cloudtolocalllm`
3. Check logs: `kubectl logs -n cloudtolocalllm -l app=web`

## Manual DNS Update

If NLB IP changes:
```bash
# Get new IP
kubectl get svc -n cloudtolocalllm

# Run setup script again
./setup-cloudflare-dns-aws-eks.ps1
```

## Environment Variables

```bash
# Required
CLOUDFLARE_API_TOKEN=your_token

# Optional (defaults shown)
AWS_REGION=us-east-1
EKS_CLUSTER_NAME=cloudtolocalllm-eks
NAMESPACE=cloudtolocalllm
ZONE_NAME=cloudtolocalllm.online
```

## Common Commands

```bash
# Get NLB endpoint
kubectl get ingress -n cloudtolocalllm -o wide

# Get NLB IP
kubectl get svc -n cloudtolocalllm -o wide

# Check DNS propagation
dig cloudtolocalllm.online +short

# Check SSL certificate
echo | openssl s_client -servername cloudtolocalllm.online -connect cloudtolocalllm.online:443 2>/dev/null | openssl x509 -noout -dates

# Test application
curl https://cloudtolocalllm.online/health
```

## Support

For detailed documentation, see: `docs/CLOUDFLARE_DNS_AWS_EKS_SETUP.md`

