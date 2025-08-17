# Cloud Monitoring Dashboards & Alerts

This document provides instructions and sample configurations for creating Cloud Monitoring dashboards and alerts for the CloudToLocalLLM application.

## Dashboards

### 1. API Backend Dashboard

**Instructions:**

1.  Go to the [Google Cloud Console](https://console.cloud.google.com/).
2.  Navigate to **Monitoring** > **Dashboards**.
3.  Click **Create Dashboard**.
4.  Click **Add Widget** and create the following charts:

**Charts:**

*   **Request Count:**
    *   **Metric:** `run.googleapis.com/request_count`
    *   **Filter:** `resource.labels.service_name = "api-backend"`
    *   **Aggregation:** `sum`
*   **Latency (99th percentile):**
    *   **Metric:** `run.googleapis.com/request_latencies`
    *   **Filter:** `resource.labels.service_name = "api-backend"`
    *   **Aggregation:** `99th percentile`
*   **Error Rate:**
    *   **Metric:** `run.googleapis.com/request_count`
    *   **Filter:** `resource.labels.service_name = "api-backend" AND metric.labels.response_code_class = "5xx"`
    *   **Aggregation:** `sum`
*   **Instance Count:**
    *   **Metric:** `run.googleapis.com/container/instance_count`
    *   **Filter:** `resource.labels.service_name = "api-backend"`
    *   **Aggregation:** `sum`

### 2. Streaming Proxy Dashboard

**Instructions:**

*   Follow the same steps as the API Backend Dashboard, but use `resource.labels.service_name = "streaming-proxy"`.

## Alerts

### 1. High Error Rate Alert

**Instructions:**

1.  Go to **Monitoring** > **Alerting**.
2.  Click **Create Policy**.
3.  **Condition:**
    *   **Metric:** `run.googleapis.com/request_count`
    *   **Filter:** `resource.labels.service_name = "api-backend" AND metric.labels.response_code_class = "5xx"`
    *   **Threshold:** `is above 10`
    *   **For:** `5 minutes`
4.  **Notification Channels:**
    *   Select your preferred notification channels (e.g., email, Slack).

### 2. High Latency Alert

**Instructions:**

1.  Go to **Monitoring** > **Alerting**.
2.  Click **Create Policy**.
3.  **Condition:**
    *   **Metric:** `run.googleapis.com/request_latencies`
    *   **Filter:** `resource.labels.service_name = "api-backend"`
    *   **Aggregation:** `99th percentile`
    *   **Threshold:** `is above 2000ms`
    *   **For:** `10 minutes`
4.  **Notification Channels:**
    *   Select your preferred notification channels.

### 3. Uptime Check

**Instructions:**

1.  Go to **Monitoring** > **Uptime checks**.
2.  Click **Create Uptime Check**.
3.  **Target:**
    *   **Protocol:** `HTTPS`
    *   **Hostname:** `api.cloudtolocalllm.online`
    *   **Path:** `/api/health`
4.  **Alerting:**
    *   Enable alerting and select your notification channels.