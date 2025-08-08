# Cloud SQL Setup for CloudToLocalLLM

This guide walks through configuring Google Cloud SQL (Postgres) with Cloud Run.

## Enable APIs
```
gcloud services enable sqladmin.googleapis.com vpcaccess.googleapis.com
```

## Create Cloud SQL Instance (Private IP only)
```
INSTANCE_ID=cloudtolocalllm-pg
REGION=us-east4
DB_VERSION=POSTGRES_16

# Create private IP-enabled instance (no public IP)
gcloud sql instances create $INSTANCE_ID \
  --database-version=$DB_VERSION \
  --tier=db-custom-1-3840 \
  --region=$REGION \
  --storage-auto-increase \
  --availability-type=ZONAL \
  --backup \
  --no-assign-ip \
  --network=default
```

## Create Database and User
```
gcloud sql databases create cloudtolocalllm --instance=$INSTANCE_ID

DB_PASSWORD=$(openssl rand -base64 24)
echo -n "$DB_PASSWORD" | gcloud secrets create db-password --data-file=- --replication-policy=automatic

gcloud sql users create cloudtolocalllm --instance=$INSTANCE_ID --password=$DB_PASSWORD
```

## Create Serverless VPC Access Connector (same region as Cloud Run)
```
CONNECTOR=cloudtolocalllm-connector
SUBNET=default  # replace with a dedicated subnet in production

gcloud compute networks vpc-access connectors create $CONNECTOR \
  --region=$REGION \
  --network=default \
  --range=10.8.0.0/28
```

## Configure Cloud Run (API) with Private Cloud SQL Access
```
PROJECT_ID=$(gcloud config get-value project)
INSTANCE_CONN=$(gcloud sql instances describe $INSTANCE_ID --format='value(connectionName)')

# Deploy (example)
gcloud run deploy cloudtolocalllm-api \
  --image=$REGION-docker.pkg.dev/$PROJECT_ID/cloudtolocalllm/api:latest \
  --platform=managed \
  --region=$REGION \
  --allow-unauthenticated \
  --port=8080 \
  --memory=2Gi \
  --cpu=2 \
  --min-instances=0 \
  --max-instances=20 \
  --concurrency=100 \
  --timeout=900 \
  --service-account=cloudtolocalllm-runner@$PROJECT_ID.iam.gserviceaccount.com \
  --add-cloudsql-instances=$INSTANCE_CONN \
  --vpc-connector=$CONNECTOR \
  --set-env-vars="NODE_ENV=production,LOG_LEVEL=info,DB_TYPE=postgres,DB_HOST=/cloudsql/$INSTANCE_CONN,DB_PORT=5432,DB_NAME=cloudtolocalllm,DB_USER=cloudtolocalllm,DB_SSL=true" \
  --set-secrets="DB_PASSWORD=db-password:latest" \
  --quiet

# Note: Instance created with --no-assign-ip | Access is private-only via VPC connector
```

## Notes
- For private IP only, adjust DB_HOST accordingly and ensure routing via VPC connector.
- Ensure `cloudtolocalllm-runner@` has `roles/cloudsql.client`.
- Rotate the `db-password` secret regularly.

