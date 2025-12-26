## Cloud Run OIDC/WIF (Keyless) Deployment Guide

This document explains how this repository migrated from service account JSON keys to GitHub OIDC + Google Cloud Workload Identity Federation (WIF) for deploying to Cloud Run. It includes prerequisites, exact setup commands, IAM roles, troubleshooting, verification, and security benefits.

---

### 1) Overview

We replaced service account key authentication in GitHub Actions with OIDC/WIF:
- GitHub issues an OIDC token to the workflow
- google-github-actions/auth@v2 exchanges that token with Google for short‑lived credentials via a Workload Identity Pool/Provider
- The workflow uses those temporary credentials to push images to Artifact Registry and deploy to Cloud Run

Benefits: no long‑lived keys in GitHub, least‑privilege and aud/subject scoping, simpler rotation and revocation.

---

### 2) Prerequisites

Google Cloud:
- Project: cloudtolocalllm-468303
- Enabled APIs (at minimum):
  - run.googleapis.com (Cloud Run)
  - artifactregistry.googleapis.com (Artifact Registry)
  - iamcredentials.googleapis.com (Token exchange)
  - Optionally: vpcaccess.googleapis.com, sqladmin.googleapis.com (if needed)
- Permissions for the person running setup:
  - Ability to create Workload Identity Pool/Provider (IAM Workload Identity Federation Admin)
  - Ability to create/modify service accounts and IAM bindings (Project IAM Admin or equivalent scoped roles)
  - Ability to manage Artifact Registry repositories/IAM

GitHub:
- Admin or Maintainer access to set Actions variables
- Ability to merge PRs updating workflow files

Repo variables required (Actions → Variables):
- WIF_PROVIDER = projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider
- WIF_SERVICE_ACCOUNT = cloudtolocalllm-deployer@cloudtolocalllm-468303.iam.gserviceaccount.com
- GCP_PROJECT_ID = cloudtolocalllm-468303
- GCP_REGION = us-east4
- (Optional) FIREBASE_PROJECT_ID = cloudtolocalllm-auth

---

### 3) Step‑by‑step setup

Set convenient environment variables:

```bash
PROJECT_ID=cloudtolocalllm-468303
REGION=us-east4
POOL_ID=github-pool
PROVIDER_ID=github-provider
DEPLOYER_SA_ID=cloudtolocalllm-deployer
RUNTIME_SA_ID=cloudtolocalllm-runner
REPO=CloudToLocalLLM-online/CloudToLocalLLM
AR_REPO=cloud-run-source-deploy

# Set defaults and discover project number
gcloud config set project $PROJECT_ID
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
```

Enable required APIs (idempotent):

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iamcredentials.googleapis.com
```

Create service accounts (deployer and runtime):

```bash
gcloud iam service-accounts create $DEPLOYER_SA_ID \
  --display-name="GitHub Actions Deployer"

gcloud iam service-accounts create $RUNTIME_SA_ID \
  --display-name="Cloud Run Runtime"
```

Create Workload Identity Pool and OIDC Provider:

```bash
gcloud iam workload-identity-pools create $POOL_ID \
  --project "$PROJECT_ID" --location "global" \
  --display-name "GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID \
  --project "$PROJECT_ID" --location "global" \
  --workload-identity-pool "$POOL_ID" \
  --display-name "GitHub Actions OIDC" \
  --issuer-uri "https://token.actions.githubusercontent.com" \
  --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref"
# Optional: restrict to this repo only with an attribute condition
# --attribute-condition "attribute.repository=='CloudToLocalLLM-online/CloudToLocalLLM'"
```

Allow GitHub repo to impersonate the deployer SA via WIF:

```bash
DEPL_EMAIL="$DEPLOYER_SA_ID@$PROJECT_ID.iam.gserviceaccount.com"
RUNTIME_EMAIL="$RUNTIME_SA_ID@$PROJECT_ID.iam.gserviceaccount.com"

# principalSet binding (maps to your repo via attribute.repository)
MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$REPO"

gcloud iam service-accounts add-iam-policy-binding "$DEPL_EMAIL" \
  --role "roles/iam.workloadIdentityUser" \
  --member "$MEMBER" \
  --project "$PROJECT_ID"
```

Grant required IAM roles:

```bash
# Cloud Run deployment (project level)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/run.admin"

# Allow deployer to act as runtime SA (service account level)
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_EMAIL" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/iam.serviceAccountUser" \
  --project "$PROJECT_ID"

# Artifact Registry push (project or repo level)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/artifactregistry.writer"
```

Create Artifact Registry repository (or ensure it exists) and grant repo‑level writer (optional but explicit):

```bash
# Create if missing (idempotent if already exists will error harmlessly)
gcloud artifacts repositories create "$AR_REPO" \
  --repository-format=docker \
  --location "$REGION" \
  --description "Cloud Run images"

# Explicit repository‑level writer
gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" \
  --location "$REGION" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/artifactregistry.writer"
```

Configure GitHub repository variables (Actions → Variables):

- WIF_PROVIDER = projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID
- WIF_SERVICE_ACCOUNT = $DEPLOYER_SA_ID@$PROJECT_ID.iam.gserviceaccount.com
- GCP_PROJECT_ID = $PROJECT_ID
- GCP_REGION = $REGION
- (Optional) FIREBASE_PROJECT_ID = cloudtolocalllm-auth

Workflow configuration (already implemented):
- permissions: id-token: write, contents: read
- Authenticate with google-github-actions/auth@v2 using WIF_PROVIDER and WIF_SERVICE_ACCOUNT
- google-github-actions/setup-gcloud@v2 with project_id
- gcloud auth configure-docker $REGION-docker.pkg.dev

---

### 4) Required IAM roles and exact commands

- roles/run.admin (deployer SA → project):
```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/run.admin"
```

- roles/iam.serviceAccountUser (deployer SA → runtime SA):
```bash
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_EMAIL" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/iam.serviceAccountUser" \
  --project "$PROJECT_ID"
```

- roles/artifactregistry.writer (deployer SA → project or repository):
```bash
# Project level
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/artifactregistry.writer"
# Or repository level
gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" \
  --location "$REGION" \
  --member "serviceAccount:$DEPL_EMAIL" \
  --role "roles/artifactregistry.writer"
```

- roles/iam.workloadIdentityUser (WIF principalSet → deployer SA):
```bash
MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$REPO"
gcloud iam service-accounts add-iam-policy-binding "$DEPL_EMAIL" \
  --role "roles/iam.workloadIdentityUser" \
  --member "$MEMBER" \
  --project "$PROJECT_ID"
```

---

### 5) Troubleshooting

- Error: Permission "artifactregistry.repositories.uploadArtifacts" denied
  - Repository may not exist or deployer SA lacks writer role
  - Fix:
    ```bash
    # Ensure API and repository
    gcloud services enable artifactregistry.googleapis.com
    gcloud artifacts repositories describe "$AR_REPO" --location "$REGION" || \
      gcloud artifacts repositories create "$AR_REPO" --repository-format=docker --location "$REGION" --description "Cloud Run images"
    # Grant writer
    gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" \
      --location "$REGION" \
      --member "serviceAccount:$DEPL_EMAIL" \
      --role "roles/artifactregistry.writer"
    ```

- Error: Caller is not authorized to exchange token
  - WIF binding missing or wrong provider path; workflow missing id-token permission
  - Fix:
    ```bash
    # Check that MEMBER principalSet matches your repo
    MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$REPO"
    gcloud iam service-accounts add-iam-policy-binding "$DEPL_EMAIL" \
      --role "roles/iam.workloadIdentityUser" \
      --member "$MEMBER" \
      --project "$PROJECT_ID"
    # In workflow yaml ensure:
    # permissions: { id-token: write, contents: read }
    # auth@v2 with workload_identity_provider = WIF_PROVIDER and service_account = WIF_SERVICE_ACCOUNT
    ```

- Error: Permission iam.serviceAccounts.actAs denied
  - Deployer SA needs iam.serviceAccountUser on the runtime SA being attached to Cloud Run
  - Fix:
    ```bash
    gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_EMAIL" \
      --member "serviceAccount:$DEPL_EMAIL" \
      --role "roles/iam.serviceAccountUser" \
      --project "$PROJECT_ID"
    ```

---

### 6) Verification steps

- Sanity checks with gcloud (optional locally):
```bash
gcloud auth login
gcloud config set project $PROJECT_ID
gcloud run services list --region $REGION
```

- CI validation (non‑interactive examples we used):
```bash
# Trigger single service
gh workflow run "Deploy to Google Cloud Run" -f service=web -f environment=production
# Find latest run for this workflow
gh run list --workflow "cloudrun-deploy.yml" --limit 1 --json databaseId,status,conclusion,createdAt
# Inspect a specific run
RUN_ID=<from previous output>
gh run view $RUN_ID --json jobs
# If failures
gh run view $RUN_ID --log-failed
```

- In job logs, confirm:
  - "Authenticate to Google Cloud (WIF)" succeeded in Build/Deploy/Verify
  - Docker push to us-east4-docker.pkg.dev/$PROJECT_ID/$AR_REPO/<service>:<sha> succeeded
  - Cloud Run deploy steps succeeded
  - Verify job health checks returned HTTP 200

---

### 7) Security benefits of keyless auth

- Eliminates long‑lived JSON keys in GitHub
- Short‑lived, scoped credentials tied to workflow identity (aud/subject)
- Centralized control with IAM; easy revocation by removing WIF bindings or roles
- Least‑privilege via granular roles (run.admin, artifactregistry.writer, serviceAccountUser)
- Reduced blast radius versus leaked keys; fewer rotation burdens

---

### Appendix: Values used in this repo

- PROJECT_ID: cloudtolocalllm-468303
- REGION: us-east4
- WIF Pool/Provider: github-pool / github-provider (global)
- Deployer SA: cloudtolocalllm-deployer@cloudtolocalllm-468303.iam.gserviceaccount.com
- Runtime SA: cloudtolocalllm-runner@cloudtolocalllm-468303.iam.gserviceaccount.com
- Artifact Registry: us-east4/cloud-run-source-deploy
- GitHub repo: CloudToLocalLLM-online/CloudToLocalLLM
- Workflow requires repo variables: WIF_PROVIDER, WIF_SERVICE_ACCOUNT, GCP_PROJECT_ID, GCP_REGION

