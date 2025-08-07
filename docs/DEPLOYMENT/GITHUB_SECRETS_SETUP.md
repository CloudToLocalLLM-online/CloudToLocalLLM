# GitHub Repository Secrets Configuration

This document outlines the required GitHub repository secrets for the CloudToLocalLLM CI/CD pipeline.

## Required Secrets

### Google Cloud Platform Secrets

#### `GOOGLE_CLOUD_CREDENTIALS`
- **Description**: Service account JSON key for Google Cloud authentication
- **Required for**: Cloud Run deployment workflow
- **How to obtain**:
  1. Go to [Google Cloud Console](https://console.cloud.google.com/)
  2. Navigate to IAM & Admin > Service Accounts
  3. Create or select the service account: `cloudtolocalllm-runner@cloudtolocalllm-468303.iam.gserviceaccount.com`
  4. Create a new JSON key
  5. Copy the entire JSON content as the secret value

#### `GCP_PROJECT_ID`
- **Description**: Google Cloud Project ID
- **Required for**: Cloud Run deployment workflow
- **Value**: `cloudtolocalllm-468303`
- **Default**: If not set, workflow will use the hardcoded default

#### `GCP_REGION`
- **Description**: Google Cloud region for deployment
- **Required for**: Cloud Run deployment workflow
- **Value**: `us-east4`
- **Default**: If not set, workflow will use the hardcoded default

#### `FIREBASE_PROJECT_ID`
- **Description**: Firebase project ID for GCIP authentication
- **Required for**: Cloud Run deployment workflow
- **Value**: `cloudtolocalllm-auth`
- **Default**: If not set, workflow will use the hardcoded default

## Service Account Permissions

The service account used for `GOOGLE_CLOUD_CREDENTIALS` must have the following IAM roles:

### Required Roles
- **Cloud Run Admin** (`roles/run.admin`)
  - Deploy and manage Cloud Run services
- **Artifact Registry Writer** (`roles/artifactregistry.writer`)
  - Push container images to Artifact Registry
- **Cloud Build Editor** (`roles/cloudbuild.editor`)
  - Trigger and manage Cloud Build jobs
- **Service Account User** (`roles/iam.serviceAccountUser`)
  - Use service accounts for Cloud Run services
- **Storage Admin** (`roles/storage.admin`)
  - Access Cloud Storage for build artifacts

### Service Account Creation Commands

```bash
# Set project ID
export PROJECT_ID="cloudtolocalllm-468303"

# Create service account
gcloud iam service-accounts create cloudtolocalllm-runner \
    --description="Service account for CloudToLocalLLM CI/CD" \
    --display-name="CloudToLocalLLM Runner"

# Grant required roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:cloudtolocalllm-runner@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:cloudtolocalllm-runner@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:cloudtolocalllm-runner@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudbuild.editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:cloudtolocalllm-runner@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:cloudtolocalllm-runner@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

# Create and download JSON key
gcloud iam service-accounts keys create cloudtolocalllm-runner-key.json \
    --iam-account=cloudtolocalllm-runner@$PROJECT_ID.iam.gserviceaccount.com
```

## Setting Up Secrets in GitHub

### Via GitHub Web Interface

1. Navigate to your repository on GitHub
2. Go to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add each secret with the name and value as specified above

### Via GitHub CLI

```bash
# Set GOOGLE_CLOUD_CREDENTIALS (replace with actual JSON content)
gh secret set GOOGLE_CLOUD_CREDENTIALS < cloudtolocalllm-runner-key.json

# Set other secrets
gh secret set GCP_PROJECT_ID --body "cloudtolocalllm-468303"
gh secret set GCP_REGION --body "us-east4"
gh secret set FIREBASE_PROJECT_ID --body "cloudtolocalllm-auth"
```

## Verification

After setting up the secrets, you can verify they are configured correctly by:

1. **Check Secrets List**: Go to repository Settings > Secrets and variables > Actions
2. **Test Workflow**: Trigger the cloud deployment workflow manually
3. **Check Logs**: Review GitHub Actions logs for authentication errors

## Security Best Practices

### Service Account Security
- **Principle of Least Privilege**: Only grant necessary permissions
- **Regular Rotation**: Rotate service account keys periodically
- **Monitoring**: Monitor service account usage in Google Cloud Console

### Secret Management
- **Never Commit Secrets**: Ensure secrets are never committed to the repository
- **Environment Separation**: Use different service accounts for staging/production
- **Access Control**: Limit who can view/modify repository secrets

## Troubleshooting

### Common Issues

#### Authentication Errors
- **Symptom**: `Error: google-github-actions/setup-gcloud failed`
- **Solution**: Verify `GOOGLE_CLOUD_CREDENTIALS` contains valid JSON

#### Permission Denied
- **Symptom**: `Error: User does not have permission to access project`
- **Solution**: Check service account has required IAM roles

#### Invalid Project ID
- **Symptom**: `Error: Project not found`
- **Solution**: Verify `GCP_PROJECT_ID` matches actual project ID

### Debug Commands

```bash
# Test service account authentication locally
gcloud auth activate-service-account --key-file=cloudtolocalllm-runner-key.json

# List available projects
gcloud projects list

# Test Cloud Run access
gcloud run services list --region=us-east4

# Test Artifact Registry access
gcloud artifacts repositories list --location=us-east4
```

## Next Steps

After configuring these secrets:

1. **Test Cloud Deployment**: Push changes to `main` branch to trigger cloud deployment
2. **Test Desktop Release**: Run the PowerShell script to create a desktop release
3. **Monitor Workflows**: Check GitHub Actions for successful execution
4. **Verify Deployments**: Confirm services are running in Google Cloud Console

For additional help, refer to:
- [Google Cloud IAM Documentation](https://cloud.google.com/iam/docs)
- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [CloudToLocalLLM Deployment Guide](./COMPLETE_DEPLOYMENT_WORKFLOW.md)
