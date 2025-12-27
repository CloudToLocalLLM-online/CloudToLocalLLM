# DNS Configuration for CloudToLocalLLM on DigitalOcean

## Required DNS Records

After deploying to Kubernetes, you'll need to configure DNS records pointing to your DigitalOcean Load Balancer.

### 📋 DNS Records Overview

You need **4 A records** pointing to your Kubernetes Load Balancer IP:

| Hostname | Type | Value | Purpose |
|----------|------|-------|---------|
| `cloudtolocalllm.online` | A | `<LOAD_BALANCER_IP>` | Main website/web app |
| `app.cloudtolocalllm.online` | A | `<LOAD_BALANCER_IP>` | Web application |
| `api.cloudtolocalllm.online` | A | `<LOAD_BALANCER_IP>` | API backend |
| `auth.cloudtolocalllm.online` | A | `<LOAD_BALANCER_IP>` | Authentication (SuperTokens) |

### 🔍 Finding Your Load Balancer IP

After deploying to Kubernetes, get the Load Balancer IP:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Output will show:
# NAME                       TYPE           EXTERNAL-IP      PORT(S)
# ingress-nginx-controller   LoadBalancer   159.89.123.456   80:30080/TCP,443:30443/TCP
```

The `EXTERNAL-IP` (e.g., `159.89.123.456`) is your Load Balancer IP.

---

## Option 1: DigitalOcean DNS (Recommended)

### Why Use DigitalOcean DNS?

✅ **Pros:**
- **Free**: No additional cost
- **Fast**: Globally distributed DNS servers
- **Integrated**: Easy to manage with doctl CLI
- **Reliable**: 100% uptime SLA
- **Simple**: Automatic propagation

### Setting Up DigitalOcean DNS

#### Step 1: Add Domain to DigitalOcean

```bash
# Create DNS zone for your domain
doctl compute domain create cloudtolocalllm.online --ip-address <LOAD_BALANCER_IP>
```

#### Step 2: Update Nameservers at Domain Registrar

DigitalOcean's nameservers are:
```
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com
```

**Instructions by Registrar:**

- **Namecheap**: Dashboard → Domain List → Manage → Nameservers → Custom DNS
- **GoDaddy**: My Products → Domains → DNS → Nameservers → Change
- **Google Domains**: My Domains → DNS → Name servers → Custom name servers
- **Cloudflare**: Transfer domain or add as external domain

#### Step 3: Create DNS Records

```bash
# Get your Load Balancer IP first
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Load Balancer IP: $LB_IP"

# Create DNS records
doctl compute domain records create cloudtolocalllm.online --record-type A --record-name @ --record-data $LB_IP --record-ttl 300

doctl compute domain records create cloudtolocalllm.online --record-type A --record-name app --record-data $LB_IP --record-ttl 300

doctl compute domain records create cloudtolocalllm.online --record-type A --record-name api --record-data $LB_IP --record-ttl 300

doctl compute domain records create cloudtolocalllm.online --record-type A --record-name auth --record-data $LB_IP --record-ttl 300
```

#### Step 4: Verify DNS Records

```bash
# List all DNS records
doctl compute domain records list cloudtolocalllm.online

# Test DNS resolution (wait 5-10 minutes after creating records)
nslookup cloudtolocalllm.online
nslookup app.cloudtolocalllm.online
nslookup api.cloudtolocalllm.online
nslookup auth.cloudtolocalllm.online
```

### Automated Setup Script

I've created `setup-dns.sh` to automate this process. See below!

---

## Option 2: External DNS Provider (Cloudflare, Route53, etc.)

If you prefer using your existing DNS provider:

### Cloudflare

1. Log in to Cloudflare Dashboard
2. Select your domain
3. Click "DNS" tab
4. Add 4 A records:

```
Type: A, Name: @, Content: <LOAD_BALANCER_IP>, Proxy: OFF
Type: A, Name: app, Content: <LOAD_BALANCER_IP>, Proxy: OFF
Type: A, Name: api, Content: <LOAD_BALANCER_IP>, Proxy: OFF
Type: A, Name: auth, Content: <LOAD_BALANCER_IP>, Proxy: OFF
```

**Important**: Turn OFF Cloudflare proxy (orange cloud) for cert-manager to work!

### AWS Route 53

1. Open Route 53 Console
2. Select Hosted Zone for `cloudtolocalllm.online`
3. Create 4 A records:

```bash
aws route53 change-resource-record-sets --hosted-zone-id Z123456 --change-batch '{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "cloudtolocalllm.online",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<LOAD_BALANCER_IP>"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "app.cloudtolocalllm.online",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<LOAD_BALANCER_IP>"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "api.cloudtolocalllm.online",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<LOAD_BALANCER_IP>"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "auth.cloudtolocalllm.online",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<LOAD_BALANCER_IP>"}]
      }
    }
  ]
}'
```

### Google Cloud DNS

1. Open Cloud DNS Console
2. Select zone for `cloudtolocalllm.online`
3. Add 4 A records via console or CLI:

```bash
gcloud dns record-sets create cloudtolocalllm.online. --zone=cloudtolocalllm --type=A --ttl=300 --rrdatas=<LOAD_BALANCER_IP>
gcloud dns record-sets create app.cloudtolocalllm.online. --zone=cloudtolocalllm --type=A --ttl=300 --rrdatas=<LOAD_BALANCER_IP>
gcloud dns record-sets create api.cloudtolocalllm.online. --zone=cloudtolocalllm --type=A --ttl=300 --rrdatas=<LOAD_BALANCER_IP>
gcloud dns record-sets create auth.cloudtolocalllm.online. --zone=cloudtolocalllm --type=A --ttl=300 --rrdatas=<LOAD_BALANCER_IP>
```

---

## Verification Checklist

After setting up DNS (wait 5-15 minutes for propagation):

### 1. DNS Resolution Test

```bash
# Should return your Load Balancer IP
dig cloudtolocalllm.online +short
dig app.cloudtolocalllm.online +short
dig api.cloudtolocalllm.online +short
dig auth.cloudtolocalllm.online +short
```

### 2. HTTP Test (Before SSL)

```bash
# Should return HTTP 308 (redirect to HTTPS) or 200
curl -I http://cloudtolocalllm.online
```

### 3. HTTPS Test (After cert-manager provisions certificates)

```bash
# Should return HTTP/2 200
curl -I https://cloudtolocalllm.online
curl -I https://app.cloudtolocalllm.online
curl -I https://api.cloudtolocalllm.online/health
```

### 4. Certificate Check

```bash
# Check SSL certificate
openssl s_client -connect cloudtolocalllm.online:443 -servername cloudtolocalllm.online < /dev/null | grep -A2 "Verify return code"

# Should show: Verify return code: 0 (ok)
```

### 5. Kubernetes Certificate Status

```bash
# Check cert-manager certificate
kubectl get certificate -n cloudtolocalllm

# Should show: READY=True
```

---

## Troubleshooting

### DNS Not Resolving

**Problem**: `dig cloudtolocalllm.online` returns no results

**Solutions**:
1. **Wait longer**: DNS propagation can take up to 48 hours (usually 5-15 minutes)
2. **Check nameservers**: Verify nameservers are correctly set at registrar
3. **Flush DNS cache**: `ipconfig /flushdns` (Windows) or `sudo dscacheutil -flushcache` (macOS)
4. **Try different DNS server**: `dig @8.8.8.8 cloudtolocalllm.online` (use Google DNS)

### SSL Certificate Not Provisioning

**Problem**: Certificate shows `READY=False`

**Solutions**:
```bash
# Check certificate status
kubectl describe certificate -n cloudtolocalllm cloudtolocalllm-tls

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Common issues:
# 1. DNS not propagated yet → Wait 15 minutes
# 2. Cloudflare proxy enabled → Disable orange cloud
# 3. Firewall blocking port 80 → Check DigitalOcean firewall rules
```

### Load Balancer IP Changes

If your Load Balancer IP changes (rare, but possible):

```bash
# Get new IP
NEW_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Update DNS records (DigitalOcean DNS)
doctl compute domain records list cloudtolocalllm.online

# For each record ID:
doctl compute domain records update cloudtolocalllm.online --record-id <RECORD_ID> --record-data $NEW_IP
```

---

## DNS Propagation Timeline

| Time | Status |
|------|--------|
| 0 min | DNS records created |
| 1-5 min | DigitalOcean DNS servers updated |
| 5-15 min | Most ISPs see new records |
| 30-60 min | Global propagation complete |
| 24-48 hours | Maximum propagation time (rare) |

---

## Security Best Practices

1. **Enable DNSSEC**: Add DNSSEC to your domain for additional security
2. **Use CAA Records**: Restrict which CAs can issue certificates
   ```bash
   doctl compute domain records create cloudtolocalllm.online \
     --record-type CAA \
     --record-name @ \
     --record-data "0 issue \"letsencrypt.org\"" \
     --record-ttl 3600
   ```
3. **Monitor DNS**: Set up alerts for unauthorized DNS changes
4. **Lock Domain**: Enable domain lock at your registrar

---

## Next Steps

After DNS is configured and propagated:

1. ✅ **Verify SSL certificates**: `kubectl get certificate -n cloudtolocalllm`
2. ✅ **Test web app**: Open https://cloudtolocalllm.online
3. ✅ **Test API**: `curl https://api.cloudtolocalllm.online/health`
4. ✅ **Monitor logs**: `kubectl logs -n cloudtolocalllm -l app=api-backend -f`

---

**Your DNS is ready!** 🚀 Proceed to deployment verification.

