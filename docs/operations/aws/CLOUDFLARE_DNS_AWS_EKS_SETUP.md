# Cloudflare DNS Integration for AWS EKS

## Overview

This document describes the process of setting up Cloudflare DNS integration for the CloudToLocalLLM application deployed on AWS EKS. The integration updates Cloudflare DNS records to point to the AWS Network Load Balancer (NLB) and configures SSL/TLS settings for secure HTTPS access.

## Prerequisites

Before running the DNS integration setup, ensure you have:

1. **AWS Account & EKS Cluster**
   - AWS EKS cluster deployed (`cloudtolocalllm-eks`)
   - AWS CLI configured with appropriate credentials
   - kubectl configured to access the EKS cluster

2. **Cloudflare Account**
   - Cloudflare zone created for `cloudtolocalllm.online`
   - Cloudflare API token with DNS and zone settings permissions
   - API token stored in `CLOUDFLARE_API_TOKEN` environment variable

3. **Required Tools**
   - AWS CLI (v2+)
   - kubectl (v1.20+)
   - PowerShell 5.0+ (for Windows) or Bash 4.0+ (for Linux/macOS)
   - curl (for API calls)
   - jq (for JSON parsing, Linux/macOS only)
   - dig (for DNS verification)

## Architecture

### DNS Resolution Flow

```
User Request
    ↓
Cloudflare DNS (cloudtolocalllm.online)
    ↓
AWS Network Load Balancer (NLB)
    ↓
Kubernetes Ingress Controller
    ↓
Application Services (Web, API, Streaming Proxy)
```

### Cloudflare Configuration

```
Cloudflare Zone: cloudtolocalllm.online
├── DNS Records (Proxied via Cloudflare)
│   ├── cloudtolocalllm.online → NLB IP
│   ├── app.cloudtolocalllm.online → NLB IP
│   ├── api.cloudtolocalllm.online → NLB IP
│   └── auth.cloudtolocalllm.online → NLB IP
├── SSL/TLS Settings
│   ├── Mode: Full (strict)
│   ├── Always Use HTTPS: Enabled
│   └── HSTS: Enabled
└── Security Features
    ├── Automatic HTTPS Rewrites: Enabled
    └── Security Level: High
```

## Setup Instructions

### Step 1: Set Environment Variables

**Windows (PowerShell):**
```powershell
$env:CLOUDFLARE_API_TOKEN = 'your_cloudflare_api_token'
```

**Linux/macOS (Bash):**
```bash
export CLOUDFLARE_API_TOKEN='your_cloudflare_api_token'
```

### Step 2: Run the Setup Script

**Windows (PowerShell):**
```powershell
cd scripts/aws
.\setup-cloudflare-dns-aws-eks.ps1
```

**Linux/macOS (Bash):**
```bash
cd scripts/aws
chmod +x setup-cloudflare-dns-aws-eks.sh
./setup-cloudflare-dns-aws-eks.sh
```

### Step 3: Verify DNS Resolution

After running the script, wait 5-10 minutes for DNS propagation, then verify:

```bash
# Check DNS resolution
nslookup cloudtolocalllm.online
dig cloudtolocalllm.online

# Check SSL certificate
curl -I https://cloudtolocalllm.online

# Test application accessibility
curl https://cloudtolocalllm.online/health
```

## What the Script Does

### 1. Validates Prerequisites
- Checks for required environment variables
- Verifies AWS CLI, kubectl, and other tools are installed
- Confirms Cloudflare API token is set

### 2. Gets Cloudflare Zone ID
- Queries Cloudflare API for the zone ID
- Validates zone exists and is accessible

### 3. Gets AWS NLB Endpoint
- Updates kubeconfig to access EKS cluster
- Retrieves the ingress endpoint from Kubernetes
- Resolves hostname to IP address if needed

### 4. Updates DNS Records
- For each domain (cloudtolocalllm.online, app.*, api.*, auth.*):
  - Checks if DNS record exists
  - Updates existing record or creates new one
  - Sets TTL to 300 seconds (5 minutes)
  - Enables Cloudflare proxy (orange cloud)

### 5. Configures SSL/TLS
- Sets SSL mode to "Full (strict)"
- Enables "Always Use HTTPS"
- Enables HSTS (HTTP Strict Transport Security)

### 6. Enables Security Features
- Enables Automatic HTTPS Rewrites
- Sets Security Level to "High"

### 7. Purges Cache
- Clears Cloudflare cache to ensure immediate updates

### 8. Verifies DNS Resolution
- Tests DNS resolution for all domains
- Confirms records point to correct IP address

## DNS Records Configuration

### A Records (IPv4)

| Domain | Type | Content | TTL | Proxied |
|--------|------|---------|-----|---------|
| cloudtolocalllm.online | A | NLB IP | 300 | Yes |
| app.cloudtolocalllm.online | A | NLB IP | 300 | Yes |
| api.cloudtolocalllm.online | A | NLB IP | 300 | Yes |
| auth.cloudtolocalllm.online | A | NLB IP | 300 | Yes |

### CNAME Records (Optional)

If you prefer to use CNAME records instead of A records:

| Domain | Type | Content | TTL | Proxied |
|--------|------|---------|-----|---------|
| app.cloudtolocalllm.online | CNAME | cloudtolocalllm.online | 300 | Yes |
| api.cloudtolocalllm.online | CNAME | cloudtolocalllm.online | 300 | Yes |
| auth.cloudtolocalllm.online | CNAME | cloudtolocalllm.online | 300 | Yes |

## SSL/TLS Configuration

### SSL Mode: Full (Strict)

- **Visitor → Cloudflare**: HTTPS (encrypted)
- **Cloudflare → Origin (NLB)**: HTTPS (encrypted)
- **Requirement**: Valid SSL certificate on origin

### Always Use HTTPS

- Automatically redirects HTTP requests to HTTPS
- Prevents mixed content warnings
- Improves security posture

### HSTS (HTTP Strict Transport Security)

- Max Age: 31,536,000 seconds (1 year)
- Include Subdomains: Enabled
- Preload: Enabled
- Tells browsers to always use HTTPS for this domain

## Security Features

### Automatic HTTPS Rewrites

- Rewrites `http://` URLs to `https://` in HTML, CSS, and JavaScript
- Prevents mixed content issues
- Improves security without code changes

### Security Level: High

- Challenges suspicious traffic
- Blocks known malicious IPs
- Provides DDoS protection
- May require CAPTCHA for some visitors

## Troubleshooting

### DNS Not Resolving

**Problem**: DNS queries return no results or old IP address

**Solutions**:
1. Wait 5-10 minutes for DNS propagation
2. Clear local DNS cache:
   - Windows: `ipconfig /flushdns`
   - macOS: `sudo dscacheutil -flushcache`
   - Linux: `sudo systemctl restart systemd-resolved`
3. Verify DNS record in Cloudflare dashboard
4. Check NLB endpoint is correct: `kubectl get ingress -n cloudtolocalllm`

### SSL Certificate Errors

**Problem**: Browser shows SSL certificate error

**Solutions**:
1. Verify SSL mode is set to "Full (strict)"
2. Check that NLB has valid SSL certificate
3. Wait for certificate to be issued (may take 5-10 minutes)
4. Clear browser cache and try again

### Application Not Accessible

**Problem**: HTTPS connection times out or refuses connection

**Solutions**:
1. Verify NLB is running: `kubectl get svc -n cloudtolocalllm`
2. Check ingress configuration: `kubectl get ingress -n cloudtolocalllm`
3. Verify security groups allow traffic on ports 80 and 443
4. Check application logs: `kubectl logs -n cloudtolocalllm -l app=web`

### Cloudflare API Errors

**Problem**: Script fails with Cloudflare API error

**Solutions**:
1. Verify API token is valid and has correct permissions
2. Check API token hasn't expired
3. Verify zone ID is correct
4. Check rate limiting (wait a few minutes and retry)

## Manual DNS Configuration

If you prefer to configure DNS manually:

### 1. Get NLB Endpoint

```bash
# Update kubeconfig
aws eks update-kubeconfig --name cloudtolocalllm-eks --region us-east-1

# Get ingress endpoint
kubectl get ingress -n cloudtolocalllm -o wide

# Get NLB IP
kubectl get svc -n cloudtolocalllm -o wide
```

### 2. Update Cloudflare DNS Records

1. Log in to Cloudflare dashboard
2. Select zone: `cloudtolocalllm.online`
3. Go to DNS records
4. For each domain:
   - Create or update A record
   - Set content to NLB IP address
   - Set TTL to 300 seconds
   - Enable proxy (orange cloud)

### 3. Configure SSL/TLS

1. Go to SSL/TLS settings
2. Set SSL mode to "Full (strict)"
3. Enable "Always Use HTTPS"
4. Enable HSTS with max age 31536000

### 4. Configure Security

1. Go to Security settings
2. Set Security Level to "High"
3. Enable Automatic HTTPS Rewrites

## Verification Checklist

After setup, verify the following:

- [ ] DNS resolves to correct IP: `dig cloudtolocalllm.online`
- [ ] HTTPS works: `curl -I https://cloudtolocalllm.online`
- [ ] HTTP redirects to HTTPS: `curl -I http://cloudtolocalllm.online`
- [ ] SSL certificate is valid: `openssl s_client -connect cloudtolocalllm.online:443`
- [ ] Application is accessible: `curl https://cloudtolocalllm.online/health`
- [ ] All subdomains resolve: `dig app.cloudtolocalllm.online`
- [ ] Cloudflare proxy is enabled (orange cloud in dashboard)
- [ ] SSL mode is "Full (strict)"
- [ ] "Always Use HTTPS" is enabled
- [ ] Security Level is "High"

## Monitoring and Maintenance

### Monitor DNS Health

```bash
# Check DNS propagation
dig cloudtolocalllm.online +short

# Monitor DNS queries
# (Available in Cloudflare dashboard → Analytics)
```

### Monitor SSL Certificate

```bash
# Check certificate expiration
echo | openssl s_client -servername cloudtolocalllm.online -connect cloudtolocalllm.online:443 2>/dev/null | openssl x509 -noout -dates
```

### Update DNS Records

If NLB IP changes:

1. Get new NLB IP: `kubectl get svc -n cloudtolocalllm`
2. Run setup script again: `./setup-cloudflare-dns-aws-eks.ps1`
3. Or manually update in Cloudflare dashboard

## Integration with CI/CD

The DNS setup can be integrated into the GitHub Actions workflow:

```yaml
- name: Setup Cloudflare DNS
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  run: |
    cd scripts/aws
    ./setup-cloudflare-dns-aws-eks.sh
```

## Related Documentation

- [AWS EKS Deployment Guide](./AWS_INFRASTRUCTURE_SETUP_COMPLETE.md)
- [Ingress Configuration](../k8s/ingress-aws-nlb.yaml)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [AWS NLB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/)

## Support

For issues or questions:

1. Check the Troubleshooting section above
2. Review Cloudflare dashboard for DNS and SSL status
3. Check AWS console for NLB status
4. Review application logs: `kubectl logs -n cloudtolocalllm`
5. Contact support with relevant logs and error messages

