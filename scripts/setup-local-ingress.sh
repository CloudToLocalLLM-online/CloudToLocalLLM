#!/bin/bash
set -e

# Setup Nginx Ingress Controller for Local Development (Docker Desktop / Minikube)

echo "Installing Nginx Ingress Controller..."

# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install Nginx Ingress Controller
# Note: For Docker Desktop, we often need to set controller.service.type=LoadBalancer
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.ports.http=80 \
  --set controller.service.ports.https=443

echo "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "âœ… Nginx Ingress Controller installed successfully!"
echo "You can now apply the local overlay using: kubectl apply -k k8s/overlays/local"
