# CloudToLocalLLM - Google Kubernetes Engine (GKE) Deployment Guide

This guide provides comprehensive instructions for deploying CloudToLocalLLM to Google Kubernetes Engine (GKE).

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Deployment Process](#deployment-process)
5. [Configuration](#configuration)

## Overview

Google Kubernetes Engine (GKE) is a managed Kubernetes service that simplifies the deployment, management, and scaling of containerized applications.

### Architecture

The CloudToLocalLLM application is deployed as three separate services on a GKE cluster:

1. **Web Service**: Flutter web application (UI)
2. **API Service**: Node.js backend (authentication, API endpoints)
3. **Streaming Service**: WebSocket proxy for real-time communication

## Prerequisites

### Required Tools

*   Google Cloud SDK (`gcloud`)
*   `kubectl`
*   Docker
*   Git

### Google Cloud Requirements

*   A Google Cloud project with billing enabled.
*   A GKE cluster named `cloudtolocalllm-us-central1` in the `us-central1` region.

## Initial Setup

### 1. Create a GKE Cluster

If you don't already have a GKE cluster, create one with the following command:

```bash
gcloud container clusters create cloudtolocalllm-us-central1 \
    --region us-central1 \
    --num-nodes 3 \
    --machine-type n1-standard-2
```

### 2. Configure `kubectl`

Configure `kubectl` to connect to your GKE cluster:

```bash
gcloud container clusters get-credentials cloudtolocalllm-us-central1 --region us-central1
```

## Deployment Process

The deployment process is automated via the `.github/workflows/gke-deploy.yml` GitHub Actions workflow. This workflow is triggered by a push to the `main` branch or can be run manually.

### Workflow Steps

1.  **Build and Push Docker Images:** The workflow builds Docker images for the `web`, `api`, and `streaming` services and pushes them to the Google Container Registry.
2.  **Deploy to GKE:** The workflow then applies the Kubernetes manifests located in the `web/k8s`, `services/api-backend/k8s`, and `services/streaming-proxy/k8s` directories to deploy the services to the GKE cluster.

## Configuration

### Kubernetes Manifests

The Kubernetes manifests for each service are located in their respective directories:

*   `web/k8s/`
*   `services/api-backend/k8s/`
*   `services/streaming-proxy/k8s/`

These manifests define the `Deployment`, `Service`, and `Ingress` resources for each service.

### Secrets

The `api-backend` service requires a Kubernetes secret named `api-secrets` with the following keys:

*   `jwt-secret`
*   `auth0-audience`

Create this secret with the following command:

```bash
kubectl create secret generic api-secrets \
    --from-literal=jwt-secret='your-jwt-secret' \
    --from-literal=auth0-audience='your-auth0-audience'
