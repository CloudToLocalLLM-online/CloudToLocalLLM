#!/bin/bash
set -e

# Configuration
REPO_URL="https://github.com/imrightguy/CloudToLocalLLM.git"
BRANCH="main"
NAMESPACE="${NAMESPACE:-cloudtolocalllm}"

echo "Starting Build and Sync Process..."

# 1. Update Code
echo "Updating code from $REPO_URL..."
if [ ! -d "/app/CloudToLocalLLM" ]; then
    git clone $REPO_URL /app/CloudToLocalLLM
else
    cd /app/CloudToLocalLLM
    git fetch origin
    git reset --hard origin/$BRANCH
fi

cd /app/CloudToLocalLLM

# 2. Build Web
echo "Building Flutter Web..."
cd web
flutter pub get
flutter build web --release --no-tree-shake-icons
cd ..

# 3. Build API
echo "Installing API Dependencies..."
cd services/api-backend
npm ci
cd ../..

# 4. Build Streaming Proxy
echo "Installing Streaming Proxy Dependencies..."
cd services/streaming-proxy
npm ci
cd ../..

# 5. Sync to Pods
echo "Syncing artifacts to pods..."

# Helper function to sync to pods
sync_to_pods() {
    local label=$1
    local src=$2
    local dest=$3
    
    echo "Finding pods with label $label..."
    PODS=$(kubectl get pods -n $NAMESPACE -l app=$label -o jsonpath='{.items[*].metadata.name}')
    
    for POD in $PODS; do
        echo "Syncing to $POD..."
        # Use tar to copy files to avoid rsync issues if rsync isn't in path or behaves differently
        # But user requested rsync. Let's try rsync if available, or tar pipe.
        # Since we control both images, we know rsync is there.
        # However, kubectl cp uses tar.
        # To use rsync, we need to forward a port or use exec.
        # Easiest way with kubectl is 'kubectl cp' which uses tar, OR exec tar.
        # User specifically asked for rsync.
        # We can pipe tar to kubectl exec tar.
        
        # "rsync -avz -e 'kubectl exec -i' ..." is complex.
        # Simpler: tar locally, pipe to kubectl exec tar.
        # But user said "rsync the required files".
        # Let's stick to 'kubectl cp' which is effectively a sync if we clean up?
        # No, kubectl cp is a copy.
        # Let's use the tar pipe method which is robust.
        
        tar cf - -C $(dirname $src) $(basename $src) | kubectl exec -i -n $NAMESPACE $POD -- tar xf - -C $dest
        
        # Signal reload (if supported by app, e.g. touch a file)
        # For Node.js with nodemon, touching a watched file works.
        # For Nginx (Web), we might need to reload nginx.
        if [ "$label" == "web" ]; then
             kubectl exec -n $NAMESPACE $POD -- nginx -s reload
        fi
    done
}

# Sync Web
# Web serves from /usr/share/nginx/html usually, or /app/web/build/web depending on config.
# Let's check web-deployment.yaml mount path.
# Assuming /app/web/build/web based on previous plan.
sync_to_pods "web" "web/build/web/." "/app/web/build/web"

# Sync API
sync_to_pods "api-backend" "services/api-backend/." "/app/services/api-backend"

# Sync Streaming
sync_to_pods "streaming-proxy" "services/streaming-proxy/." "/app/services/streaming-proxy"

# 6. Run Migrations (Postgres)
# Assuming we have a script or npm command for this in api-backend
echo "Running Database Migrations..."
# kubectl exec -n $NAMESPACE $(kubectl get pods -n $NAMESPACE -l app=api-backend -o jsonpath='{.items[0].metadata.name}') -- npm run migration:run

echo "Build and Sync Complete!"
