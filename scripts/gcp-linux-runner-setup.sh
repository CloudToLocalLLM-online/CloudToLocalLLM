#!/bin/bash

# This script automates the creation of a GitHub Actions self-hosted runner on a GCP Linux VM.
#
# IMPORTANT: Replace the placeholder values with your actual GCP project details and GitHub runner token.
#
# Usage:
#   1. Ensure you are authenticated with gcloud and have the necessary permissions.
#   2. Make this script executable: chmod +x scripts/gcp-linux-runner-setup.sh
#   3. Run the script: ./scripts/gcp-linux-runner-setup.sh

# --- Configuration Variables ---
GCP_PROJECT_ID="YOUR_GCP_PROJECT_ID"
GCP_REGION="us-central1"
GCP_ZONE="us-central1-a"
VM_NAME="github-runner-linux-$(date +%s)"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
GITHUB_RUNNER_ORG_URL="https://github.com/YOUR_GITHUB_ORG_OR_USER" # e.g., https://github.com/imrightguy
GITHUB_RUNNER_TOKEN="YOUR_GITHUB_RUNNER_TOKEN" # Obtain from GitHub -> Settings -> Actions -> Runners -> New runner

# --- Startup Script for the VM ---
read -r -d '' STARTUP_SCRIPT << EOM
#!/bin/bash
sudo apt-get update
sudo apt-get install -y git curl

mkdir /actions-runner
cd /actions-runner

# Download the runner application
curl -o actions-runner-linux-x64-$(arch).tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-$(arch).tar.gz
tar xzf ./actions-runner-linux-x64-$(arch).tar.gz

# Configure the runner
./config.sh --url ${GITHUB_RUNNER_ORG_URL} --token ${GITHUB_RUNNER_TOKEN} --labels linux,self-hosted --unattended

# Install as a service
sudo ./svc.sh install
sudo ./svc.sh start
EOM

# --- Create the VM Instance ---
echo "Creating GCP VM instance: ${VM_NAME}..."
gcloud compute instances create "${VM_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --zone="${GCP_ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --image-family="${IMAGE_FAMILY}" \
  --image-project="${IMAGE_PROJECT}" \
  --metadata-from-file=startup-script=<(echo "${STARTUP_SCRIPT}") \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=http-server,https-server

echo "VM instance creation initiated. It may take a few minutes for the runner to come online."
echo "Monitor the runner status in GitHub: ${GITHUB_RUNNER_ORG_URL}/settings/actions/runners"
