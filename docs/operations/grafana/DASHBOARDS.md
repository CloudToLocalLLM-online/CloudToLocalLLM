# Admin Center Grafana Dashboards

This directory contains Grafana dashboard definitions for monitoring the Admin Center API and operations.

## Dashboards

### 1. Admin Center Overview (`admin-center-overview.json`)

**Purpose:** High-level overview of Admin Center health and performance

**Key Metrics:**
- API request rate and error rate
- Active admin sessions
- API response time (P95)
- Payment success rate
- Database connection pool status
- Stripe API error rate
- Top API endpoints by request count
- Slowest API endpoints
- Admin actions by type
- Authentication attempts

**Use Cases:**
- Quick health check of Admin Center
- Identify performance issues
- Monitor overall system load
- Track admin activity

**Refresh Rate:** 30 seconds

---

### 2. Payment Gateway Metrics (`admin-payment-gateway.json`)

**Purpose:** Detailed monitoring of payment processing and Stripe integration

**Key Metrics:**
- Payment success/failure rates
- Payment attempts by method (card, PayPal)
- Refund processing rate and time
- Refunds by reason
- Stripe API call rate and response time
- Stripe API errors by type
- Subscription operations

**Use Cases:**
- Monitor payment system health
- Identify payment processing issues
- Track refund patterns
- Monitor Stripe API performance
- Detect payment fraud patterns

**Refresh Rate:** 30 seconds

**Alerts:**
- Payment failure rate >10%
- Stripe API error rate >10%
- Slow refund processing (>5s)

---

### 3. User Management Metrics (`admin-user-management.json`)

**Purpose:** Monitor admin operations on user accounts

**Key Metrics:**
- User management API requests
- User management response times
- Admin actions by type and role
- User suspensions and reactivations
- Subscription changes
- Database query performance (user tables)
- Authentication success rate
- Failed authentication reasons
- Active admin sessions

**Use Cases:**
- Monitor admin activity
- Track user management operations
- Identify authentication issues
- Monitor database performance for user operations
- Detect suspicious admin activity

**Refresh Rate:** 30 seconds

**Alerts:**
- High authentication failure rate
- Slow database queries
- Unusual admin activity patterns

---

## Installation

### Option 1: Manual Import

1. Open Grafana UI
2. Navigate to Dashboards → Import
3. Upload the JSON file or paste the JSON content
4. Select the Prometheus datasource
5. Click Import

### Option 2: Provisioning (Recommended for Production)

1. Copy dashboard JSON files to Grafana provisioning directory:
   ```bash
   cp config/grafana/dashboards/*.json /etc/grafana/provisioning/dashboards/
   ```

2. Create or update provisioning configuration:
   ```yaml
   # /etc/grafana/provisioning/dashboards/admin-center.yml
   apiVersion: 1
   
   providers:
     - name: 'Admin Center'
       orgId: 1
       folder: 'Admin Center'
       type: file
       disableDeletion: false
       updateIntervalSeconds: 30
       allowUiUpdates: true
       options:
         path: /etc/grafana/provisioning/dashboards
         foldersFromFilesStructure: false
   ```

3. Restart Grafana:
   ```bash
   systemctl restart grafana-server
   ```

### Option 3: Kubernetes ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-center-dashboards
  namespace: cloudtolocalllm
data:
  admin-center-overview.json: |
    # Paste dashboard JSON here
  admin-payment-gateway.json: |
    # Paste dashboard JSON here
  admin-user-management.json: |
    # Paste dashboard JSON here
```

Mount the ConfigMap in Grafana deployment:
```yaml
volumeMounts:
  - name: dashboards
    mountPath: /etc/grafana/provisioning/dashboards
volumes:
  - name: dashboards
    configMap:
      name: admin-center-dashboards
```

---

## Prometheus Configuration

Ensure Prometheus is configured to scrape Admin Center metrics:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'admin-api'
    scrape_interval: 10s
    metrics_path: '/metrics'
    static_configs:
      - targets: ['admin-api-backend:3000']
```

See `config/prometheus/admin-center-prometheus.yml` for complete configuration.

---

## Alert Rules

Alert rules are defined in `config/prometheus/admin-center-alerts.yml`.

**Critical Alerts:**
- Admin API high error rate (>5%)
- Payment high failure rate (>10%)
- Stripe API errors
- Database connection issues
- Service down

**Warning Alerts:**
- Slow API responses (>2s)
- Slow database queries
- High authentication failure rate
- Slow refund processing

Configure Alertmanager to send notifications:
```yaml
# alertmanager.yml
route:
  group_by: ['alertname', 'component']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'admin-center-alerts'

receivers:
  - name: 'admin-center-alerts'
    email_configs:
      - to: 'admin@cloudtolocalllm.online'
        from: 'alerts@cloudtolocalllm.online'
        smarthost: 'smtp.example.com:587'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#admin-center-alerts'
```

---

## Metrics Endpoint

The Admin Center API exposes Prometheus metrics at:
```
GET /metrics
```

**Example:**
```bash
curl http://admin-api-backend:3000/metrics
```

**Response Format:** Prometheus text format (version 0.0.4)

---

## Recording Rules

Pre-computed metrics for better dashboard performance:

- `admin:api_requests:rate5m` - API request rate
- `admin:api_error_percentage:rate5m` - API error percentage
- `admin:api_response_time:p95` - P95 response time
- `admin:payment_success_percentage:rate5m` - Payment success rate
- `admin:refund_processing_time:avg` - Average refund time
- `admin:stripe_api_error_percentage:rate5m` - Stripe error rate

See `config/prometheus/admin-center-recording-rules.yml` for complete list.

---

## Troubleshooting

### Dashboard shows "No data"

1. Verify Prometheus is scraping metrics:
   ```bash
   curl http://prometheus:9090/api/v1/targets
   ```

2. Check if metrics endpoint is accessible:
   ```bash
   curl http://admin-api-backend:3000/metrics
   ```

3. Verify datasource configuration in Grafana

### Metrics not updating

1. Check Prometheus scrape interval (default: 10s)
2. Verify Admin API is running and healthy
3. Check Prometheus logs for scrape errors

### Alerts not firing

1. Verify alert rules are loaded in Prometheus:
   ```bash
   curl http://prometheus:9090/api/v1/rules
   ```

2. Check Alertmanager configuration
3. Verify alert thresholds are appropriate

---

## Customization

### Adding New Panels

1. Edit dashboard JSON file
2. Add new panel definition with unique ID
3. Define query using PromQL
4. Set visualization type and options
5. Re-import dashboard

### Modifying Thresholds

Update threshold values in panel options:
```json
"thresholds": {
  "mode": "absolute",
  "steps": [
    { "value": 0, "color": "green" },
    { "value": 5, "color": "yellow" },
    { "value": 10, "color": "red" }
  ]
}
```

### Adding Variables

Add template variables for filtering:
```json
"templating": {
  "list": [
    {
      "name": "endpoint",
      "type": "query",
      "query": "label_values(admin_api_requests_total, endpoint)",
      "refresh": 1
    }
  ]
}
```

---

## Best Practices

1. **Use recording rules** for frequently queried metrics
2. **Set appropriate refresh rates** (30s for real-time, 1m for historical)
3. **Configure alerts** for critical metrics
4. **Use template variables** for filtering large datasets
5. **Document custom panels** with descriptions
6. **Test dashboards** with production-like data
7. **Version control** dashboard JSON files
8. **Monitor dashboard performance** (query execution time)

---

## Support

For issues or questions:
- Documentation: https://docs.cloudtolocalllm.online/operations/monitoring
- Runbook: https://docs.cloudtolocalllm.online/operations/admin-center-troubleshooting
- Support: admin@cloudtolocalllm.online

---

## References

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
