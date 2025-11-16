# Admin Center Monitoring - Quick Reference

## Overview

Complete monitoring solution for Admin Center including Prometheus metrics, Grafana dashboards, and alerting.

**Status:** ✅ COMPLETED (Task 31)

---

## Components

### 1. Prometheus Metrics (`services/api-backend/middleware/admin-metrics.js`)

**Purpose:** Collect and expose metrics for Admin Center API

**Key Metrics:**
- `admin_api_requests_total` - Total API requests (by method, endpoint, status)
- `admin_api_response_time_ms` - API response time histogram
- `admin_payment_attempts_total` - Payment attempts (by status, method)
- `admin_payment_success_rate` - Payment success rate gauge
- `admin_refund_attempts_total` - Refund attempts (by status, reason)
- `admin_refund_processing_time_ms` - Refund processing time histogram
- `admin_stripe_api_calls_total` - Stripe API calls (by operation, status)
- `admin_stripe_api_errors_total` - Stripe API errors (by type)
- `admin_database_queries_total` - Database queries (by operation, table)
- `admin_database_query_time_ms` - Database query time histogram
- `admin_actions_total` - Admin actions (by action, role)
- `admin_auth_attempts_total` - Authentication attempts (by result, reason)
- `admin_error_rate` - Overall error rate gauge
- `admin_db_pool_size` - Database connection pool size
- `admin_active_sessions` - Active admin sessions

**Metrics Endpoint:** `GET /metrics`

**Usage:**
```javascript
import { adminMetricsMiddleware, trackStripeApiCall } from './middleware/admin-metrics.js';

// Add middleware to Express app
app.use('/api/admin', adminMetricsMiddleware);

// Track Stripe API call
const start = Date.now();
const result = await stripe.charges.create(...);
trackStripeApiCall('payment', 'success', Date.now() - start);
```

---

### 2. Metrics Endpoint (`services/api-backend/routes/admin-metrics.js`)

**Purpose:** Expose Prometheus metrics in text format

**Endpoint:** `GET /metrics`

**Response:** Prometheus text format (version 0.0.4)

**Example:**
```bash
curl http://localhost:3000/metrics
```

---

### 3. Prometheus Configuration

**Files:**
- `config/prometheus/admin-center-prometheus.yml` - Main configuration
- `config/prometheus/admin-center-recording-rules.yml` - Pre-computed metrics
- `config/prometheus/admin-center-alerts.yml` - Alert rules

**Scrape Configuration:**
```yaml
scrape_configs:
  - job_name: 'admin-api'
    scrape_interval: 10s
    metrics_path: '/metrics'
    static_configs:
      - targets: ['admin-api-backend:3000']
```

**Recording Rules:**
- `admin:api_requests:rate5m` - API request rate (5m average)
- `admin:api_error_percentage:rate5m` - API error percentage
- `admin:api_response_time:p95` - P95 response time
- `admin:payment_success_percentage:rate5m` - Payment success rate
- `admin:refund_processing_time:avg` - Average refund processing time
- `admin:stripe_api_error_percentage:rate5m` - Stripe API error rate

---

### 4. Grafana Dashboards

**Location:** `config/grafana/dashboards/`

#### Dashboard 1: Admin Center Overview
**File:** `admin-center-overview.json`

**Panels:**
- API Request Rate
- API Error Rate
- Active Admin Sessions
- API Response Time (P95)
- Payment Success Rate
- Database Connection Pool
- Stripe API Error Rate
- Top API Endpoints
- Slowest API Endpoints
- Admin Actions by Type
- Authentication Attempts

**Use Case:** High-level health monitoring

---

#### Dashboard 2: Payment Gateway Metrics
**File:** `admin-payment-gateway.json`

**Panels:**
- Payment Success Rate (gauge)
- Payment Failure Rate
- Payment Attempts (Success vs Failed)
- Payment Attempts by Method
- Refund Processing Rate
- Refund Processing Time (P95)
- Refunds by Reason
- Stripe API Call Rate
- Stripe API Response Time
- Stripe API Errors by Type
- Subscription Operations

**Use Case:** Payment system monitoring and troubleshooting

---

#### Dashboard 3: User Management Metrics
**File:** `admin-user-management.json`

**Panels:**
- User Management API Requests
- User Management Response Time (P95)
- Admin Actions by Type
- Admin Actions by Role
- User Suspensions/Reactivations
- Subscription Changes
- Refunds Processed
- Database Query Performance
- Authentication Success Rate
- Failed Authentication Reasons
- Active Admin Sessions

**Use Case:** Admin activity monitoring and audit

---

### 5. Alert Rules

**File:** `config/prometheus/admin-center-alerts.yml`

#### Critical Alerts

| Alert | Condition | Duration | Impact |
|-------|-----------|----------|--------|
| AdminApiHighErrorRate | Error rate >5% | 5m | Admin Center degraded |
| AdminPaymentHighFailureRate | Payment failures >10% | 5m | Revenue loss |
| AdminPaymentNoSuccessfulPayments | No successful payments | 15m | Complete payment failure |
| AdminDatabaseConnectionIssues | >10 waiting requests | 2m | Severe performance degradation |
| AdminStripeApiHighErrorRate | Stripe errors >10% | 5m | Payment system compromised |
| AdminApiServiceDown | Service unavailable | 2m | Complete outage |

#### Warning Alerts

| Alert | Condition | Duration | Impact |
|-------|-----------|----------|--------|
| AdminApiSlowResponses | P95 >2s | 5m | Degraded performance |
| AdminRefundSlowProcessing | P95 >5s | 5m | Refund delays |
| AdminDatabaseSlowQueries | P95 >100ms | 5m | Performance degradation |
| AdminStripeApiSlowResponses | P95 >5s | 5m | Payment delays |
| AdminAuthHighFailureRate | Auth failures >20% | 5m | Access issues |

---

## Integration Guide

### Step 1: Add Metrics Middleware

```javascript
// services/api-backend/server.js
import { adminMetricsMiddleware, initializeAdminMetrics } from './middleware/admin-metrics.js';
import adminMetricsRouter from './routes/admin-metrics.js';

// Initialize metrics
initializeAdminMetrics();

// Add metrics middleware to admin routes
app.use('/api/admin', adminMetricsMiddleware);

// Add metrics endpoint
app.use('/', adminMetricsRouter);
```

### Step 2: Track Custom Metrics

```javascript
// Track payment processing
import { trackStripeApiCall, trackAdminAction } from './middleware/admin-metrics.js';

// In payment processing code
const start = Date.now();
try {
  const charge = await stripe.charges.create(...);
  trackStripeApiCall('payment', 'success', Date.now() - start);
} catch (error) {
  trackStripeApiCall('payment', 'failed', Date.now() - start);
  trackStripeApiError(error.type);
}

// Track admin actions
trackAdminAction('user_suspend', req.adminRoles[0]);
```

### Step 3: Configure Prometheus

```bash
# Copy Prometheus configuration
cp config/prometheus/admin-center-prometheus.yml /etc/prometheus/prometheus.yml
cp config/prometheus/admin-center-recording-rules.yml /etc/prometheus/rules/
cp config/prometheus/admin-center-alerts.yml /etc/prometheus/rules/

# Reload Prometheus
curl -X POST http://localhost:9090/-/reload
```

### Step 4: Import Grafana Dashboards

**Option A: Manual Import**
1. Open Grafana UI
2. Navigate to Dashboards → Import
3. Upload JSON files from `config/grafana/dashboards/`

**Option B: Provisioning**
```bash
# Copy dashboards
cp config/grafana/dashboards/*.json /etc/grafana/provisioning/dashboards/

# Restart Grafana
systemctl restart grafana-server
```

---

## Kubernetes Deployment

### ConfigMap for Prometheus Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-center-prometheus-config
  namespace: cloudtolocalllm
data:
  prometheus.yml: |
    # Paste admin-center-prometheus.yml content
  recording-rules.yml: |
    # Paste admin-center-recording-rules.yml content
  alerts.yml: |
    # Paste admin-center-alerts.yml content
```

### Service Monitor for Prometheus Operator

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: admin-api-backend
  namespace: cloudtolocalllm
spec:
  selector:
    matchLabels:
      app: admin-api-backend
  endpoints:
    - port: http
      path: /metrics
      interval: 10s
```

### Grafana Dashboard ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-center-dashboards
  namespace: cloudtolocalllm
  labels:
    grafana_dashboard: "1"
data:
  admin-center-overview.json: |
    # Paste dashboard JSON
```

---

## Monitoring Best Practices

### 1. Metric Collection
- ✅ Use middleware for automatic request tracking
- ✅ Track business metrics (payments, refunds, subscriptions)
- ✅ Monitor external dependencies (Stripe, database)
- ✅ Track error rates and types
- ✅ Monitor resource usage (memory, connections)

### 2. Dashboard Design
- ✅ Start with overview dashboard
- ✅ Create focused dashboards for specific areas
- ✅ Use appropriate visualization types
- ✅ Set meaningful thresholds
- ✅ Include context and descriptions

### 3. Alerting
- ✅ Alert on symptoms, not causes
- ✅ Set appropriate thresholds
- ✅ Include runbook links
- ✅ Avoid alert fatigue
- ✅ Test alerts regularly

### 4. Performance
- ✅ Use recording rules for expensive queries
- ✅ Set appropriate scrape intervals
- ✅ Limit cardinality of labels
- ✅ Use histogram buckets wisely
- ✅ Monitor Prometheus performance

---

## Troubleshooting

### No Metrics Appearing

**Check 1: Metrics endpoint accessible**
```bash
curl http://admin-api-backend:3000/metrics
```

**Check 2: Prometheus scraping**
```bash
curl http://prometheus:9090/api/v1/targets
```

**Check 3: Middleware registered**
```javascript
// Verify middleware is added before routes
app.use('/api/admin', adminMetricsMiddleware);
app.use('/api/admin', adminRoutes);
```

### Dashboards Show "No Data"

**Check 1: Datasource configured**
- Grafana → Configuration → Data Sources
- Verify Prometheus URL

**Check 2: Metrics exist in Prometheus**
```bash
curl 'http://prometheus:9090/api/v1/query?query=admin_api_requests_total'
```

**Check 3: Time range**
- Ensure dashboard time range includes data

### Alerts Not Firing

**Check 1: Alert rules loaded**
```bash
curl http://prometheus:9090/api/v1/rules
```

**Check 2: Alertmanager configured**
```bash
curl http://alertmanager:9093/api/v1/status
```

**Check 3: Alert conditions met**
- Check metric values in Prometheus
- Verify threshold values

---

## Metrics Reference

### API Metrics

```promql
# Request rate
rate(admin_api_requests_total[5m])

# Error rate
rate(admin_api_errors_total[5m])

# P95 response time
histogram_quantile(0.95, rate(admin_api_response_time_ms_bucket[5m]))

# Slow requests
rate(admin_slow_requests_total[5m])
```

### Payment Metrics

```promql
# Payment success rate
rate(admin_payment_attempts_total{status="success"}[5m])

# Payment failure percentage
(sum(rate(admin_payment_attempts_total{status="failed"}[5m])) / sum(rate(admin_payment_attempts_total[5m]))) * 100

# Refund processing time
histogram_quantile(0.95, rate(admin_refund_processing_time_ms_bucket[5m]))
```

### Database Metrics

```promql
# Query rate
rate(admin_database_queries_total[5m])

# Query time
histogram_quantile(0.95, rate(admin_database_query_time_ms_bucket[5m]))

# Connection pool usage
admin_db_pool_size - admin_db_pool_idle_connections
```

### Stripe Metrics

```promql
# Stripe API call rate
rate(admin_stripe_api_calls_total[5m])

# Stripe error rate
rate(admin_stripe_api_errors_total[5m])

# Stripe response time
histogram_quantile(0.95, rate(admin_stripe_api_response_time_ms_bucket[5m]))
```

---

## Next Steps

1. ✅ Metrics collection implemented
2. ✅ Prometheus configuration created
3. ✅ Grafana dashboards created
4. ✅ Alert rules defined
5. ⏳ Deploy to production
6. ⏳ Configure Alertmanager
7. ⏳ Set up notification channels
8. ⏳ Create runbook documentation

---

## Files Created

### Metrics & Middleware
- `services/api-backend/middleware/admin-metrics.js` - Prometheus metrics definitions
- `services/api-backend/routes/admin-metrics.js` - Metrics endpoint

### Prometheus Configuration
- `config/prometheus/admin-center-prometheus.yml` - Main configuration
- `config/prometheus/admin-center-recording-rules.yml` - Recording rules
- `config/prometheus/admin-center-alerts.yml` - Alert rules

### Grafana Dashboards
- `config/grafana/dashboards/admin-center-overview.json` - Overview dashboard
- `config/grafana/dashboards/admin-payment-gateway.json` - Payment metrics
- `config/grafana/dashboards/admin-user-management.json` - User management metrics
- `config/grafana/dashboards/README.md` - Dashboard documentation

### Documentation
- `.kiro/specs/admin-center/MONITORING_QUICK_REFERENCE.md` - This file

---

## Support

For questions or issues:
- Documentation: `config/grafana/dashboards/README.md`
- Spec: `.kiro/specs/admin-center/tasks.md` (Task 31)
- Requirements: `.kiro/specs/admin-center/requirements.md` (Requirement 12)
