### 4. SSL.com

**Best for**: Enterprise-grade certificates with free tier

**Features:**
- ✅ Free 90-day certificates available
- ✅ Paid certificates (DV/OV/EV) available
- ✅ ACME v2 protocol (works with cert-manager)
- ✅ DNS-01 challenge supported
- ✅ Higher rate limits than Let's Encrypt
- ✅ Enterprise support
- ✅ No EAB required for free tier

**Limitations:**
- ⚠️ Free tier has some limitations
- ⚠️ Requires account creation

**Configuration:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: sslcom-prod
spec:
  acme:
    server: https://acme.ssl.com/sslcom-dv-rsa
    email: admin@cloudtolocalllm.online
    privateKeySecretRef:
      name: sslcom-prod-key
    solvers:
      - dns01:
          azureDNS:
            clientID: <AZURE_CLIENT_ID>
            clientSecretSecretRef:
              name: azure-dns-config
              key: client-secret
            subscriptionID: <AZURE_SUBSCRIPTION_ID>
            tenantID: <AZURE_TENANT_ID>
            resourceGroupName: cloudtolocalllm-rg
            hostedZoneName: cloudtolocalllm.online
            environment: AzurePublicCloud
```

---

### 5. Actalis (formerly Actalis ACME)

**Best for**: European-based CA with ACME support

**Features:**
- ✅ Unlimited free certificates via ACME
- ✅ 90-day certificate validity
- ✅ ACME v2 protocol
- ✅ DNS-01 challenge supported
- ✅ European-based CA
- ✅ No rate limits mentioned

**Limitations:**
- ⚠️ Less known than major providers
- ⚠️ May require account verification

**Configuration:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: actalis-prod
spec:
  acme:
    server: https://acme.actalis.it/v2/DV90
    email: admin@cloudtolocalllm.online
    privateKeySecretRef:
      name: actalis-prod-key
    solvers:
      - dns01:
          azureDNS:
            clientID: <AZURE_CLIENT_ID>
            clientSecretSecretRef:
              name: azure-dns-config
              key: client-secret
            subscriptionID: <AZURE_SUBSCRIPTION_ID>
            tenantID: <AZURE_TENANT_ID>
            resourceGroupName: cloudtolocalllm-rg
            hostedZoneName: cloudtolocalllm.online
            environment: AzurePublicCloud
```

---

### 6. Google Trust Services (formerly Google Internet Authority G2)

**Best for**: Google's certificate authority with ACME support

**Features:**
- ✅ Free 90-day certificates
- ✅ ACME v2 protocol
- ✅ DNS-01 challenge supported
- ✅ Backed by Google
- ✅ High trust

**Limitations:**
- ⚠️ Requires account creation
- ⚠️ May have rate limits

**Configuration:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: google-prod
spec:
  acme:
    server: https://dv.acme-v02.api.pki.goog/directory
    email: admin@cloudtolocalllm.online
    privateKeySecretRef:
      name: google-prod-key
    solvers:
      - dns01:
          azureDNS:
            clientID: <AZURE_CLIENT_ID>
            clientSecretSecretRef:
              name: azure-dns-config
              key: client-secret
            subscriptionID: <AZURE_SUBSCRIPTION_ID>
            tenantID: <AZURE_TENANT_ID>
            resourceGroupName: cloudtolocalllm-rg
            hostedZoneName: cloudtolocalllm.online
            environment: AzurePublicCloud
```

---

### 7. HiCA (ACME Certificate Authority) ⚠️ **MAY NOT WORK**

**Status**: ⚠️ **ACME endpoint returns 404** - May be discontinued or incompatible with cert-manager

**Best for**: NOT RECOMMENDED - Use SSL.com or Actalis instead

**Features:**
- ✅ Free certificates (if available)
- ✅ No account creation required
- ✅ 180-day certificate validity
- ✅ ACME v2 protocol

**Limitations:**
- ❌ **ACME endpoint unavailable** (acme.hi.cn/directory returns 404)
- ❌ **Requires acme.sh client specifically** - may not work with cert-manager
- ⚠️ Chinese CA - may have trust/accessibility issues
- ⚠️ Not verified to work with cert-manager

**Recommendation**: Use **SSL.com** or **Actalis** instead for reliable certificate issuance

**Configuration:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: hica-prod
spec:
  acme:
    server: https://acme.hi.cn/directory
    email: admin@cloudtolocalllm.online
    privateKeySecretRef:
      name: hica-prod-key
    solvers:
      - dns01:
          azureDNS:
            clientID: <AZURE_CLIENT_ID>
            clientSecretSecretRef:
              name: azure-dns-config
              key: client-secret
            subscriptionID: <AZURE_SUBSCRIPTION_ID>
            tenantID: <AZURE_TENANT_ID>
            resourceGroupName: cloudtolocalllm-rg
            hostedZoneName: cloudtolocalllm.online
            environment: AzurePublicCloud
```

---

### 8. Smallstep / step-ca (Self-Hosted CA)

**Best for**: Organizations wanting full control over certificate issuance

**Features:**
- ✅ Self-hosted certificate authority
- ✅ Full control over certificate lifecycle
- ✅ Custom validity periods
- ✅ ACME v2 protocol
- ✅ No external dependencies
- ✅ Private/internal certificates
- ✅ Free (open source)

**Limitations:**
- ⚠️ Requires self-hosting infrastructure
- ⚠️ More complex setup
- ⚠️ Not trusted by browsers by default (needs custom trust)
- ⚠️ Best for internal/private use

**Use Case**: Internal services, private networks, development environments

**Configuration:**
1. Deploy step-ca server
2. Configure cert-manager ACME issuer to point to your step-ca instance
3. Import step-ca root certificate into trust stores

---

### 9. CAcert (Community-Driven)

**Best for**: Community projects, internal use

**Features:**
- ✅ Free certificates
- ✅ Community-driven
- ✅ ACME support (limited)

**Limitations:**
- ❌ Not trusted by major browsers by default
- ❌ Requires manual trust configuration
- ⚠️ Limited ACME support
- ⚠️ Not suitable for public-facing sites

**Status**: Not recommended for production public websites

---

### 10. Self-Signed Certificate (Temporary)

**Best for**: Development/testing when no CA is available

**Features:**
- ✅ No external dependencies
- ✅ Works immediately
- ✅ No rate limits
- ✅ No DNS challenges

**Limitations:**
- ❌ Browser warnings (not trusted)
- ❌ Not suitable for production
- ❌ Manual renewal required

**Configuration:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cloudtolocalllm-selfsigned
  namespace: cloudtolocalllm
spec:
  dnsNames:
    - cloudtolocalllm.online
    - "*.cloudtolocalllm.online"
  secretName: cloudtolocalllm-wildcard-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
```

---

## Provider Comparison

| Provider | Validity | Rate Limits | Account Required | EAB Required | Trust Level | Setup Complexity |
|----------|----------|-------------|------------------|--------------|-------------|------------------|
| **Let's Encrypt** | 90 days | 5/168h per set | ❌ | ❌ | High | Easy |
| **ZeroSSL** | 90 days | Higher | ✅ | ✅ | High | Medium |
| **SSL.com** | 90 days | Higher | ✅ | ❌ (free) | High | Easy |
| **Actalis** | 90 days | Unlimited? | ✅ | ❌ | High | Easy |
| **Google Trust** | 90 days | Higher | ✅ | ❌ | High | Easy |
| **HiCA** | 90 days | Higher | ❌ | ❌ | Medium | Easy |
| **Smallstep/step-ca** | Custom | None | ❌ | ❌ | Custom | Complex |
| **CAcert** | Custom | Limited | ✅ | ❌ | Low* | Medium |
| **Buypass Go** | 180 days* | N/A* | ❌ | ❌ | N/A | ❌ Discontinued |
| **Self-signed** | Custom | None | ❌ | ❌ | None | Easy |

*Not trusted by default browsers

---

## Quick Setup Options

### Option A: SSL.com (Recommended for immediate use)

1. Sign up at https://www.ssl.com/
2. Create ACME account
3. Apply configuration:
```bash
kubectl apply -f k8s/cert-manager-sslcom-azure-dns.yaml
kubectl patch certificate cloudtolocalllm-wildcard -n cloudtolocalllm -p '{"spec":{"issuerRef":{"name":"sslcom-prod"}}}'
kubectl delete certificate cloudtolocalllm-wildcard -n cloudtolocalllm
```

### Option B: Actalis

1. Sign up at https://www.actalis.com/
2. Apply configuration:
```bash
kubectl apply -f k8s/cert-manager-actalis-azure-dns.yaml
kubectl patch certificate cloudtolocalllm-wildcard -n cloudtolocalllm -p '{"spec":{"issuerRef":{"name":"actalis-prod"}}}'
kubectl delete certificate cloudtolocalllm-wildcard -n cloudtolocalllm
```

### Option C: HiCA (Simplest - no account)

1. Apply configuration:
```bash
kubectl apply -f k8s/cert-manager-hica-azure-dns.yaml
kubectl patch certificate cloudtolocalllm-wildcard -n cloudtolocalllm -p '{"spec":{"issuerRef":{"name":"hica-prod"}}}'
kubectl delete certificate cloudtolocalllm-wildcard -n cloudtolocalllm
```

### Option D: Smallstep (Self-Hosted)

For full control, deploy your own CA:
1. Deploy step-ca server in your cluster
2. Configure ACME issuer pointing to step-ca
3. Import root certificate into trust stores
4. Full control over certificate issuance

**Note**: Requires significant setup and maintenance

See Smallstep documentation for step-ca deployment: https://smallstep.com/docs/step-ca

---

## Recommendation Priority

### For Immediate Use (Public Websites)
1. **SSL.com** ⭐ - Most reliable, enterprise-grade, easy setup, no EAB
2. **Actalis** - Good European option, unlimited free certificates
3. **HiCA** ⭐ - Simplest setup, no account required
4. **Google Trust Services** - Google's CA, high trust
5. **ZeroSSL** - Good alternative (requires EAB setup)

### For Internal/Private Use
1. **Smallstep/step-ca** - Full control, self-hosted
2. **Self-signed** - Quick development/testing

### Fallback Option
6. **Wait for Let's Encrypt** - Automatic retry after rate limit reset (2025-11-19 09:15:41 UTC)

---

## Multi-Issuer Strategy

Configure multiple issuers for redundancy:

```bash
# Add multiple ClusterIssuers
kubectl apply -f k8s/cert-manager-sslcom-azure-dns.yaml
kubectl apply -f k8s/cert-manager-actalis-azure-dns.yaml
kubectl apply -f k8s/cert-manager-hica-azure-dns.yaml

# Switch between them as needed
kubectl patch certificate cloudtolocalllm-wildcard -n cloudtolocalllm -p '{"spec":{"issuerRef":{"name":"sslcom-prod"}}}'
```