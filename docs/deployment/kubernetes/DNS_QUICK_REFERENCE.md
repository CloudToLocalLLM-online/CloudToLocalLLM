# 📋 DNS Quick Reference - CloudToLocalLLM

## Your Domain: cloudtolocalllm.online

### Required DNS Records

After deployment, you need 4 A records pointing to your Load Balancer IP:

```
┌────────────────────────────────────┬──────┬───────────────────┐
│ Hostname                           │ Type │ Value             │
├────────────────────────────────────┼──────┼───────────────────┤
│ cloudtolocalllm.online             │  A   │ <LOAD_BALANCER_IP>│
│ app.cloudtolocalllm.online         │  A   │ <LOAD_BALANCER_IP>│
│ api.cloudtolocalllm.online         │  A   │ <LOAD_BALANCER_IP>│
│ auth.cloudtolocalllm.online        │  A   │ <LOAD_BALANCER_IP>│
└────────────────────────────────────┴──────┴───────────────────┘
```

### Get Your Load Balancer IP

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## DigitalOcean DNS (Recommended)

### Automated Setup

```bash
cd k8s
chmod +x setup-dns.sh
./setup-dns.sh
```

### Manual Setup

```bash
# Get Load Balancer IP
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create DNS zone
doctl compute domain create cloudtolocalllm.online --ip-address $LB_IP

# Add subdomains
doctl compute domain records create cloudtolocalllm.online --record-type A --record-name app --record-data $LB_IP --record-ttl 300
doctl compute domain records create cloudtolocalllm.online --record-type A --record-name api --record-data $LB_IP --record-ttl 300
doctl compute domain records create cloudtolocalllm.online --record-type A --record-name auth --record-data $LB_IP --record-ttl 300
```

### Update Nameservers

At your domain registrar, set nameservers to:
```
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com
```

---

## Alternative: Cloudflare DNS

1. Go to Cloudflare Dashboard
2. Select `cloudtolocalllm.online`
3. Add 4 A records (same as table above)
4. **Important**: Turn OFF proxy (orange cloud) for all records

---

## Alternative: AWS Route 53

```bash
# Replace YOUR_HOSTED_ZONE_ID and YOUR_LB_IP
aws route53 change-resource-record-sets --hosted-zone-id YOUR_HOSTED_ZONE_ID --change-batch '
{
  "Changes": [
    {"Action": "UPSERT", "ResourceRecordSet": {"Name": "cloudtolocalllm.online", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "YOUR_LB_IP"}]}},
    {"Action": "UPSERT", "ResourceRecordSet": {"Name": "app.cloudtolocalllm.online", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "YOUR_LB_IP"}]}},
    {"Action": "UPSERT", "ResourceRecordSet": {"Name": "api.cloudtolocalllm.online", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "YOUR_LB_IP"}]}},
    {"Action": "UPSERT", "ResourceRecordSet": {"Name": "auth.cloudtolocalllm.online", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "YOUR_LB_IP"}}]}
  ]
}'
```

---

## Verification

### Test DNS Resolution

```bash
# Wait 5-15 minutes after creating records, then test:
dig cloudtolocalllm.online +short
dig app.cloudtolocalllm.online +short
dig api.cloudtolocalllm.online +short
dig auth.cloudtolocalllm.online +short

# All should return the same IP (your Load Balancer IP)
```

### Test HTTPS (after cert-manager provisions certificates)

```bash
curl -I https://cloudtolocalllm.online
curl -I https://app.cloudtolocalllm.online
curl -I https://api.cloudtolocalllm.online/health
```

### Check SSL Certificates

```bash
kubectl get certificate -n cloudtolocalllm

# Should show READY=True
```

---

## Troubleshooting

### DNS not resolving?
- Wait longer (up to 48 hours, usually 5-15 min)
- Check nameservers at registrar
- Flush local DNS cache: `ipconfig /flushdns` (Windows)

### SSL certificate not ready?
```bash
kubectl describe certificate -n cloudtolocalllm cloudtolocalllm-tls
kubectl logs -n cert-manager -l app=cert-manager -f
```

Common causes:
- DNS not propagated yet → Wait
- Cloudflare proxy enabled → Disable it
- Port 80 blocked → Check firewall

---

## Domain Propagation Status

Check global DNS propagation:
- https://dnschecker.org/#A/cloudtolocalllm.online
- https://www.whatsmydns.net/#A/cloudtolocalllm.online

---

**For detailed documentation, see `DNS_SETUP.md`**

