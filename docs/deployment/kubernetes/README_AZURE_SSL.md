# Platform-Independent SSL Certificate Configuration

This document describes the SSL certificate setup for CloudToLocalLLM on Kubernetes.

## Current Configuration: Wildcard Certificate with cert-manager DNS-01 Challenge

The current setup uses **wildcard certificate (*.cloudtolocalllm.online)** via **cert-manager with DNS-01 challenge**, which is **platform-independent** and works on any Kubernetes cluster:

- ✅ **Platform-Agnostic**: Works on GKE, EKS, AKS, DOKS, on-premises, or any Kubernetes cluster
- ✅ **DNS Provider Agnostic**: Supports Azure DNS, AWS Route53, Cloudflare, Google Cloud DNS, etc.
- ✅ **Standard Kubernetes**: Uses nginx-ingress and cert-manager (industry standards)
- ✅ **Automatic Renewal**: Certificates are automatically provisioned and renewed
- ✅ **Portable**: Can easily migrate between cloud providers or to on-premises

### Current DNS Provider: Azure DNS

We're currently using **Azure DNS** for DNS-01 validation because:
- DNS zone is managed in Azure
- Automatic integration with Azure infrastructure
- Easy to manage via Azure CLI

**However**, this can be easily changed to any other DNS provider by:
1. Updating the ClusterIssuer to use a different DNS provider (Route53, Cloudflare, etc.)
2. Providing credentials for that DNS provider
3. No other changes needed - cert-manager and nginx-ingress remain unchanged

### Architecture

```
Internet
   ↓
[Platform Load Balancer] (Azure LB, AWS ELB, GCP LB, DigitalOcean LB, etc.)
   ↓
[nginx-ingress Controller] (Standard Kubernetes ingress - platform-independent)
   ↓
[cert-manager] (Standard Kubernetes cert-manager - platform-independent)
   ↓
[DNS Provider API] (Currently Azure DNS, but can be any provider)
   ↓
[Let's Encrypt] (Standard ACME CA - same across all providers)
```

### Why Not Azure Application Gateway?

**Azure Application Gateway would break platform independence**:
- ❌ Azure-specific: Only works on Azure
- ❌ Not portable: Can't migrate to GKE, EKS, DOKS, or on-premises
- ❌ Lock-in: Requires Azure-specific infrastructure
- ❌ Higher cost: Additional Azure service required

**Our approach maintains portability**:
- ✅ nginx-ingress: Works anywhere Kubernetes runs
- ✅ cert-manager: Works anywhere Kubernetes runs
- ✅ DNS provider: Easy to switch (just change the issuer config)
- ✅ Certificate authority: Let's Encrypt is provider-independent

---

## How It Works

1. **cert-manager** requests a certificate from Let's Encrypt (platform-independent CA)
2. **Let's Encrypt** requires domain validation via DNS-01 challenge
3. **cert-manager** creates TXT record in Azure DNS zone (or any configured DNS provider)
4. **Let's Encrypt** validates domain ownership via DNS
5. **cert-manager** stores certificate in Kubernetes secret
6. **nginx-ingress** uses the secret for TLS termination

### Wildcard Certificate Benefits

- ✅ **Single Certificate**: One certificate covers all subdomains (*.cloudtolocalllm.online)
- ✅ **Root Domain Included**: Also covers cloudtolocalllm.online
- ✅ **Future-Proof**: Automatically covers any new subdomains you add
- ✅ **Fewer Certificates**: No need to request individual certificates for each subdomain
- ✅ **Easy to Manage**: Single certificate to monitor and renew

### Certificate Lifecycle

- **Provisioning**: Automatic on first deployment (includes root + wildcard)
- **Renewal**: Automatic (cert-manager renews ~30 days before expiry)
- **Validation**: Uses Azure DNS zone DNS-01 challenge (can be changed to any DNS provider)
- **Storage**: Kubernetes secrets (standard Kubernetes - platform-independent)
- **Coverage**: Covers `cloudtolocalllm.online` and `*.cloudtolocalllm.online`

---

## Prerequisites

### Platform-Independent Requirements

1. **Kubernetes cluster** (any provider or on-premises)
2. **nginx-ingress controller** (installed via standard Kubernetes manifests)
3. **cert-manager** (installed via standard Kubernetes manifests)
4. **DNS provider** with API access (currently Azure DNS, but can be any)

### Azure-Specific Configuration (Current Setup)

1. **Azure DNS zone**: `cloudtolocalllm.online`
2. **Service Principal** with **DNS Zone Contributor** role on the DNS zone
3. **Azure CLI credentials** in GitHub Actions workflow

---

## Switching DNS Providers

To switch to a different DNS provider (e.g., AWS Route53, Cloudflare, Google Cloud DNS):

1. **Update ClusterIssuer** (`k8s/cert-manager-azure-dns.yaml`):
   ```yaml
   solvers:
     - dns01:
         route53:  # or cloudflare, clouddns, etc.
           accessKeyID: <AWS_ACCESS_KEY>
           secretAccessKeySecretRef:
             name: route53-credentials
             key: secret-access-key
           region: us-east-1
   ```

2. **Update secrets** in the deployment workflow
3. **No other changes needed** - cert-manager and nginx-ingress remain the same

---

## Platform Portability

This setup can run on:
- ✅ **Azure AKS** (current)
- ✅ **Google GKE**
- ✅ **AWS EKS**
- ✅ **DigitalOcean Kubernetes**
- ✅ **Self-hosted Kubernetes** (on-premises, bare metal, etc.)

**Only requirement**: A DNS provider with API access for DNS-01 challenge.

**No provider lock-in**: All components (nginx-ingress, cert-manager) are standard Kubernetes tools that work everywhere.

---

## Benefits of This Approach

1. **Platform Independence**: Not locked to Azure or any specific provider
2. **Cost Effective**: Uses standard Kubernetes tools (no provider-specific services)
3. **Flexible**: Easy to switch DNS providers or migrate to different cloud
4. **Standard**: Uses industry-standard tools (nginx-ingress, cert-manager)
5. **Portable**: Can move between cloud providers or to on-premises with minimal changes
