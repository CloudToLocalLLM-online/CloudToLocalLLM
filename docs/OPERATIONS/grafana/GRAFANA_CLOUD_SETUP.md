# Grafana Cloud Integration Guide

To complete the monitoring setup for CloudToLocalLLM, follow these steps to connect your Kubernetes cluster to your Grafana Cloud instance.

## 1. Get Connection Details
Login to your [Grafana.com Portal](https://grafana.com) and navigate to **My Account**.

### Prometheus Remote Write
1.  Find the **Prometheus** card and click **Send Metrics**.
2.  Copy the following values:
    *   **Remote Write URL**: (e.g., `https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push`)
    *   **Username**: (A 6-digit number)
    *   **Password/API Token**: Create a new token with `MetricsPublisher` role.

## 2. Update Cluster Secrets
Run the following commands (or ask me to do it for you) to update the secrets:

```bash
# Set your values
$URL = "your_remote_write_url"
$USER = "your_username"
$TOKEN = "your_token"

# Patch the secret
kubectl patch secret cloudtolocalllm-secrets -n cloudtolocalllm --type=merge -p "{\"stringData\":{\"grafana-cloud-prometheus-url\":\"$URL\",\"grafana-cloud-prometheus-user\":\"$USER\",\"grafana-cloud-prometheus-token\":\"$TOKEN\"}}"
```

## 3. Import the Dashboard
1.  Log in to your Grafana instance at `https://cloudtolocalllm.grafana.net/`.
2.  Go to **Dashboards** -> **New** -> **Import**.
3.  Upload the `llm-performance-dashboard.json` file located in the project root.
4.  Select your **GrafanaCloud-Prometheus** data source.

## 4. Set Up Sentry Integration
1.  In Grafana Cloud, go to **Connections** -> **Data Sources** -> **Add new data source**.
2.  Search for **Sentry**.
3.  Provide your Sentry Organization Slug and Auth Token (from Sentry settings).
4.  This will allow you to overlay backend errors on top of performance metrics.

## 5. Verify Metrics
Once connected, Prometheus will start pushing metrics. You can verify this by searching for these metrics in the Grafana Explore view:
*   `llm_request_duration_seconds_count`
*   `llm_tokens_total`
*   `llm_errors_total`
