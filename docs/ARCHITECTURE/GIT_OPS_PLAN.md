# GitOps Architecture Plan for CloudToLocalLLM

This document outlines a new GitOps architecture using Terraform, GitHub Actions, and ArgoCD to achieve consistent, portable, and automated deployments for both Managed (SaaS) and Local (On-Premise) versions of CloudToLocalLLM.

## Table of Contents

1.  [Overview of the New Architecture](#1-overview-of-the-new-architecture)
2.  [Core Components and Their Roles](#2-core-components-and-their-roles)
    *   [Terraform](#terraform)
    *   [GitHub Actions](#github-actions)
    *   [ArgoCD](#argocd)
    *   [Cloudflare Tunnel](#cloudflare-tunnel)
    *   [Nginx Ingress](#nginx-ingress)
3.  [Repository Structure](#3-repository-structure)
4.  [Workflows](#4-workflows)
    *   [A. `provision-cluster.yml` (The "Zero-to-Hero" Workflow)](#a-provision-clusteryml-the-zero-to-hero-workflow)
    *   [B. `orchestrator.yml` (The CI Brain)](#b-orchestratoryml-the-ci-brain)
    *   [C. `build-release.yml` (The Reusable Builder)](#c-build-releaseyml-the-reusable-builder)
5.  [Handling Specific Requirements](#5-handling-specific-requirements)
    *   [Managed (SaaS) vs. Local (On-Premise)](#managed-saas-vs-local-on-premise)
    *   [Dynamic Managed Domains (Wildcard Cloudflare Tunnel + App Logic)](#dynamic-managed-domains-wildcard-cloudflare-tunnel--app-logic)
    *   [Custom Local Domains (Kustomize Parameterization)](#custom-local-domains-kustomize-parameterization)
    *   [Secrets Management](#secrets-management)
6.  [Implementation Steps](#6-implementation-steps)

---

## 1. Overview of the New Architecture

The goal is to move from an "Imperative Push" deployment model to a "Declarative Pull" GitOps model. This allows us to define our infrastructure and applications in Git, with ArgoCD continuously reconciling the cluster state to match. This architecture supports:

*   **Provider Agnosticism:** Deploy to Azure AKS, AWS EKS, GKE, or even local Docker Desktop.
*   **Product Variants:** Support distinct "Managed" (SaaS) and "Local" (On-Premise) product configurations.
*   **Automated Provisioning:** A single workflow to create a new, fully configured cluster from scratch.
*   **Enhanced Security:** Decoupling cluster access from CI jobs and managing secrets securely.

The core principle is:
*   **Terraform:** Manages the **Hardware** (the Kubernetes cluster itself).
*   **GitHub Actions:** Manages **CI** (builds, tests, pushes images) and **Secrets Injection** into the cluster.
*   **ArgoCD:** Manages the **Software** (applications deployed to Kubernetes).

## 2. Core Components and Their Roles

### Terraform
*   **Role:** Infrastructure as Code (IaC) for provisioning and managing the underlying Kubernetes cluster (e.g., Azure AKS, AWS EKS, GKE). It is responsible for creating the cluster, networking, and any cloud-specific resources.
*   **Key Function:** Creates the Kubernetes API endpoint, enabling subsequent tools to interact with the cluster.

### GitHub Actions
*   **Role:** Serves multiple purposes:
    *   **CI Pipeline:** Builds Flutter apps, Node.js services, Docker images, and pushes them to container registries (e.g., Azure Container Registry).
    *   **Orchestration:** Triggers other workflows based on changes, version bumps, and deployment decisions.
    *   **Secrets Injection:** Securely injects GitHub Secrets directly into the provisioned Kubernetes cluster as native Kubernetes Secret objects. This happens *before* ArgoCD is installed to prevent race conditions.
    *   **ArgoCD Installation:** Installs ArgoCD into the newly provisioned cluster (via Helm).

### ArgoCD
*   **Role:** The GitOps controller. Once installed in the cluster, it continuously monitors a Git repository (your `k8s/` folder) for desired state changes.
*   **Key Function:** Pulls Kubernetes manifests (Deployments, Services, ConfigMaps, Ingress, etc.) from Git and applies them to the cluster, ensuring the cluster's actual state matches the declared state in Git. It also provides a UI for visualization, health monitoring, and manual synchronization.

### Cloudflare Tunnel
*   **Role:** Primary networking component for **Managed (SaaS)** deployments. It establishes an outbound-only connection from the cluster to Cloudflare's edge network.
*   **Key Function:** Provides secure, public access to services without exposing ingress IPs. Crucially, it supports wildcard domains (`*.yourdomain.com`) and custom hostnames, enabling dynamic multi-tenancy without reconfiguring Kubernetes.

### Nginx Ingress
*   **Role:** Standard networking component for **Local (On-Premise)** deployments.
*   **Key Function:** Provides HTTP/S routing within the local network, allowing access to services via a custom domain (e.g., `llm.mycompany.com`) or IP address. Requires a separate Nginx Ingress Controller to be installed in the cluster.

## 3. Repository Structure

The repository will be organized to clearly separate infrastructure code from Kubernetes application manifests and CI/CD workflows.

```text
E:\dev\CloudToLocalLLM\
├── infra/
│   └── terraform/                      # Terraform code for cluster provisioning
│       ├── main.tf                     # Defines AKS/EKS/GKE cluster resources
│       ├── variables.tf                # Cluster parameters (e.g., region, node count)
│       └── versions.tf                 # Terraform provider versions
│
├── k8s/
│   ├── base/                           # Universal, provider/product-agnostic Kubernetes manifests
│   │   ├── deployments/                # web, api-backend, streaming-proxy Deployments
│   │   ├── services/                   # web, api-backend, streaming-proxy Services (ClusterIP)
│   │   ├── configmaps/                 # Shared application ConfigMaps (e.g., feature flags)
│   │   └── kustomization.yaml          # Defines base resources
│   │
│   ├── overlays/
│   │   ├── managed/                    # SaaS Product Overlay (Azure AKS + Cloudflare)
│   │   │   ├── cloudflared-tunnel.yaml # Defines Cloudflare Tunnel daemon and routes
│   │   │   ├── env-patch.yaml          # Patches to enable SaaS-specific features (billing, multi-tenancy)
│   │   │   ├── scaling.yaml            # Patches for production-grade scaling (e.g., 3 replicas)
│   │   │   └── kustomization.yaml      # Combines base with managed-specific patches
│   │   │
│   │   └── local/                      # On-Premise Product Overlay (Docker Desktop + Nginx Ingress)
│   │       ├── ingress.yaml            # Nginx Ingress definition (host: PLACEHOLDER_DOMAIN)
│   │       ├── env-patch.yaml          # Patches to disable SaaS-specific features
│   │       ├── storage-patch.yaml      # Patches for local storage (HostPath/LocalPV if needed)
│   │       ├── resource-patch.yaml     # Patches for single-replica/lower resource limits
│   │       └── kustomization.yaml      # Combines base with local-specific patches
│   │
│   └── bootstrap/                      # ArgoCD App of Apps Entrypoint
│       └── root-app-managed.yaml       # ArgoCD Application definition for 'managed' overlay
│       └── root-app-local.yaml         # ArgoCD Application definition for 'local' overlay
│
└── .github/
    └── workflows/
        ├── provision-cluster.yml       # Workflow to provision a new cluster (DR/New Client)
        ├── orchestrator.yml            # Main CI workflow for versioning and triggering builds
        └── build-release.yml           # Reusable workflow for building and deploying apps
```

## 4. Workflows

### A. `provision-cluster.yml` (The "Zero-to-Hero" Workflow)

**Trigger:** `workflow_dispatch` (manual trigger for provisioning new clusters, e.g., for DR, new regional deployments, or initial client setup).

**Purpose:** To create a fully operational Kubernetes cluster from scratch, inject necessary secrets, and install ArgoCD to begin managing applications. This pipeline executes in a strict, linear order to ensure dependencies are met.

**Jobs:**

1.  **`provision_hardware`:**
    *   **Tool:** Terraform.
    *   **Action:** Provisions the Kubernetes cluster (e.g., Azure AKS) and associated cloud resources.
    *   **Outputs:** Cluster details (name, resource group) for subsequent jobs.
    *   **Security:** Uses OIDC (`id-token: write`) for Azure login.
2.  **`inject_secrets`:**
    *   **Tool:** `kubectl`.
    *   **Depends On:** `provision_hardware`.
    *   **Action:** Authenticates to the newly created cluster, creates the application namespace, and injects GitHub Secrets (e.g., `STRIPE_KEY`, `POSTGRES_PASSWORD`) directly into the cluster as Kubernetes Secret objects. This occurs *before* ArgoCD or applications are installed.
    *   **Security:** Uses OIDC for cluster access.
3.  **`install_argocd`:**
    *   **Tool:** `helm`, `kubectl`.
    *   **Depends On:** `inject_secrets` (ensures secrets exist).
    *   **Action:** Installs ArgoCD into the cluster using its Helm chart.
    *   **Action:** Applies the relevant "root" ArgoCD Application (`k8s/bootstrap/root-app-managed.yaml` or `k8s/bootstrap/root-app-local.yaml`) to bootstrap the GitOps process. This tells ArgoCD to start syncing applications defined in the `k8s/overlays/<product-variant>` path.
    *   **Action:** Optionally retrieves and outputs the ArgoCD admin password.

### B. `orchestrator.yml` (The CI Brain)

**Trigger:** `push` to `main`, `workflow_dispatch`.

**Purpose:** Detects code changes, determines new versions, and orchestrates the building and deployment of specific application components.

**Jobs:**

1.  **`ai_analysis`:**
    *   **Tool:** Custom scripts (Gemini) or AI analysis.
    *   **Action:** Analyzes changes in the codebase (Flutter, Node.js, `k8s/`) to determine what has changed and which product variants (managed/local, cloud/desktop/mobile) need updates.
    *   **Outputs:** `new_version`, `docker_version`, `do_managed`, `do_local`, `do_desktop`, `do_mobile`, `reasoning`.
    *   **Action:** Commits version bumps and Git tags (e.g., `v7.12.0`) back to the repository.
2.  **`trigger_build_release`:**
    *   **Depends On:** `ai_analysis`.
    *   **Action:** Calls the reusable `build-release.yml` workflow, passing the version and flags indicating which product variants and platforms to build/deploy.

### C. `build-release.yml` (The Reusable Builder)

**Trigger:** `workflow_call` (called by `orchestrator.yml`).

**Purpose:** Builds Docker images, Flutter artifacts, pushes images to registry, and updates Kubernetes manifest image tags in Git.

**Jobs:**

1.  **`build_and_update_managed_cloud`:**
    *   **If:** `inputs.do_managed` is true.
    *   **Action:** Builds Node.js services (`api-backend`, `streaming-proxy`), Flutter Web, Postgres images.
    *   **Action:** Pushes images to Azure Container Registry (ACR).
    *   **Action:** **Crucially**, it updates the image tags in the `k8s/base/deployments/*.yaml` files and commits these changes back to Git (e.g., `git commit -m "deploy(web): update image to ${{ inputs.docker_version }} [skip ci]"` and `git push`). ArgoCD will then pick up this change.
    *   **Security:** Uses OIDC (`id-token: write`) for Azure login and Docker login to ACR.
2.  **`build_and_update_local_cloud`:**
    *   **If:** `inputs.do_local` is true.
    *   **Action:** (Similar to `managed_cloud` but might build slightly different images or fewer services, e.g., local database images).
    *   **Action:** Updates image tags in `k8s/base/deployments/*.yaml` and commits.
3.  **`desktop_build`:**
    *   **If:** `inputs.do_desktop` is true.
    *   **Action:** Builds Flutter Desktop for Windows (and potentially macOS/Linux).
    *   **Action:** Creates installers/packages.
    *   **Action:** Uploads artifacts to GitHub Releases (handled by a later job).
4.  **`mobile_build`:**
    *   **If:** `inputs.do_mobile` is true.
    *   **Action:** Builds Flutter Mobile for Android/iOS.
    *   **Action:** Uploads artifacts to GitHub Releases.
5.  **`create_github_release`:**
    *   **Depends On:** `build_and_update_managed_cloud`, `desktop_build`, `mobile_build` (waits for all relevant builds).
    *   **Action:** Collects artifacts from desktop/mobile jobs.
    *   **Action:** Creates a new GitHub Release with the new version and attached artifacts.

## 5. Handling Specific Requirements

### Managed (SaaS) vs. Local (On-Premise)

This distinction is primarily handled by **Kustomize Overlays** and **Application-level Feature Flags**.

### Managed Overlay (`k8s/overlays/managed`):
    *   Includes `cloudflared-tunnel.yaml`.
    *   `env-patch.yaml` sets:
        *   `APP_MODE=managed`
        *   `ENABLE_BILLING=true`
        *   `ENABLE_MULTI_TENANCY=true`
        *   `ADMIN_CENTER_ENABLED=true`
        *   `ENABLE_ADMIN_PAYMENTS=true`
    *   `scaling.yaml` sets `replicas: 3` (or higher).

*   **Local Overlay (`k8s/overlays/local`):
    *   Includes `ingress.yaml` (Nginx Ingress).
    *   `env-patch.yaml` sets:
        *   `APP_MODE=local`
        *   `ENABLE_BILLING=false`
        *   `ENABLE_MULTI_TENANCY=false`
        *   `ADMIN_CENTER_ENABLED=true`
        *   `ENABLE_ADMIN_PAYMENTS=false` (Disable Stripe/Billing tabs)
    *   `resource-patch.yaml` sets `replicas: 1`, lower CPU/memory limits.
    *   `storage-patch.yaml` uses `HostPath` or `LocalPV` for persistent storage.

### Dynamic Managed Domains (Wildcard Cloudflare Tunnel + App Logic)

*   **Cloudflare Tunnel:** Configured with a wildcard DNS record (`*.app.cloudtolocalllm.online`) and a catch-all route that points to your web/API services. This is configured in `k8s/overlays/managed/cloudflared-tunnel.yaml`.
*   **Application Logic:** Your Node.js/Flutter backend will inspect the `Host` header of incoming requests.
    *   It will parse the subdomain (e.g., `tenant1.app.cloudtolocalllm.online` $\rightarrow$ `tenant1`).
    *   For custom domains (e.g., `portal.bigcorp.com`), the application will query its database to find which tenant `portal.bigcorp.com` maps to.
    *   This removes the need for K8s ingress changes per tenant.

### Admin Center Integration

The Admin Center is an integrated component of the `api-backend` (routes) and `web` (UI) services, not a standalone microservice. Its deployment is handled via configuration within the standard services.

*   **Database Migrations:** The `admin_roles` and `admin_audit_logs` tables are essential. To ensure they exist before the app starts, we will use a **Kubernetes Init Container** in the `api-backend` deployment.
    *   **Command:** `npm run db:migrate`
    *   **Effect:** Automatically applies `001_admin_center_schema.sql` on deployment.
    *   **Default Admin:** The migration/seed logic is configured to ensure `christopher.maltais@gmail.com` is granted the `super_admin` role if it doesn't exist.

*   **Feature Toggles:**
    *   **Managed:** Full Admin Center enabled (`ENABLE_ADMIN_PAYMENTS=true`).
    *   **Local:** Admin Center enabled but restricted (`ENABLE_ADMIN_PAYMENTS=false`), allowing users to manage their local instance without SaaS billing clutter.

### Custom Local Domains (Kustomize Parameterization)

*   **Nginx Ingress:** The `k8s/overlays/local/ingress.yaml` will use a placeholder (e.g., `PLACEHOLDER_DOMAIN`) for the `host` field.
*   **ArgoCD Application:** When an ArgoCD Application is created for a Local instance, the `spec.source.kustomize.patches` or `spec.source.kustomize.buildOptions` will be used to inject the actual domain provided by the customer at installation time.
    *   Example: `kustomize.patches` can be used to replace the placeholder `PLACEHOLDER_DOMAIN` with `llm.mycompany.com`. This can be done via the ArgoCD UI or CLI when creating the `local-llm` application.

### Secrets Management

*   **GitHub Actions as Injector:** GitHub Secrets are securely passed to the `inject_secrets` job in `provision-cluster.yml`.
*   **Kubernetes Native Secrets:** These secrets are immediately converted into Kubernetes Secret objects within the cluster.
*   **Application Consumption:** Applications running in Kubernetes will consume these secrets via `envFrom.secretRef` or `valueFrom.secretKeyRef` in their Deployment manifests (defined in `k8s/base/deployments`).

## 6. Implementation Steps

1.  **Refactor `k8s/` Folder:**
    *   Create `k8s/base` and move all current deployment, service, configmap YAMLs into it. Ensure services are `ClusterIP`.
    *   Create `k8s/overlays/managed` and `k8s/overlays/local`.
    *   Create `kustomization.yaml` files in `base` and both overlays.
    *   Move `cloudflared.yaml` to `k8s/overlays/managed/cloudflared-tunnel.yaml`.
    *   Create `k8s/overlays/local/ingress.yaml` with an Nginx Ingress definition and `PLACEHOLDER_DOMAIN`.
    *   Create `env-patch.yaml`, `scaling.yaml`, `storage-patch.yaml`, `resource-patch.yaml` in the respective overlays as needed to configure product variants.
    *   Create `k8s/bootstrap/root-app-managed.yaml` and `root-app-local.yaml`.
2.  **Create `infra/terraform` Folder:**
    *   Define `main.tf`, `variables.tf`, `versions.tf` for your AKS cluster using the provided examples.
3.  **Update GitHub Secrets:**
    *   Ensure all necessary secrets (Azure credentials, Docker registry creds, application secrets like `STRIPE_KEY`, `POSTGRES_PASSWORD`, `CLOUDFLARE_TUNNEL_TOKEN`) are configured in your GitHub repository secrets.
4.  **Implement `provision-cluster.yml`:**
    *   Create the workflow as described above, including the `provision_hardware`, `inject_secrets`, and `install_argocd` jobs.
    *   Ensure OIDC is configured for Azure authentication within GitHub Actions.
5.  **Refine `orchestrator.yml` and `build-release.yml`:**
    *   Adjust `orchestrator.yml` to trigger `build-release.yml` with `do_managed` and `do_local` flags (instead of `do_cloud`).
    *   Modify `build-release.yml` to use the new `k8s/base` and `k8s/overlays` structure.
    *   Implement the `git commit` and `git push` steps in `build-release.yml` to update the image tags in `k8s/base/deployments/*.yaml` after successful image builds.
6.  **Install Nginx Ingress Controller (Local Only):** For local environments (e.g., Docker Desktop), the `local-setup.sh` script will need to install an Nginx Ingress Controller (if not already present) before ArgoCD attempts to apply the `local` overlay.
7.  **Test Iteratively:**
    *   Start with provisioning a new cluster (using `provision-cluster.yml`).
    *   Verify ArgoCD is running and has synced the correct application overlay (`managed` or `local`).
    *   Make a small code change and verify the `orchestrator.yml` -> `build-release.yml` flow updates the image tag in Git, and ArgoCD subsequently deploys the new version.
    *   Test both `managed` and `local` scenarios thoroughly.
