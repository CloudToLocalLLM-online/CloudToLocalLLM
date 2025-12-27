# Admin Reports API - Quick Reference

## Endpoints Summary

| Endpoint                           | Method | Permission       | Description                   |
| ---------------------------------- | ------ | ---------------- | ----------------------------- |
| `/api/admin/reports/revenue`       | GET    | `view_reports`   | Generate revenue report       |
| `/api/admin/reports/subscriptions` | GET    | `view_reports`   | Generate subscription metrics |
| `/api/admin/reports/export`        | GET    | `export_reports` | Export report to CSV/PDF      |

---

## Quick Examples

### Revenue Report

```bash
# Basic revenue report
GET /api/admin/reports/revenue?startDate=2025-01-01&endDate=2025-01-31

# With tier breakdown
GET /api/admin/reports/revenue?startDate=2025-01-01&endDate=2025-01-31&groupBy=true
```

**Response:**

- `totalRevenue`: Total revenue in period
- `transactionCount`: Number of successful transactions
- `averageTransactionValue`: Average transaction amount
- `revenueByTier`: Breakdown by subscription tier (if groupBy=true)

---

### Subscription Metrics

```bash
# Last 30 days (default)
GET /api/admin/reports/subscriptions

# Custom date range
GET /api/admin/reports/subscriptions?startDate=2025-01-01&endDate=2025-01-31

# Without tier grouping
GET /api/admin/reports/subscriptions?groupBy=false
```

**Response:**

- `monthlyRecurringRevenue`: Current MRR
- `churnRate`: Cancellation rate percentage
- `retentionRate`: Retention rate percentage
- `activeSubscriptions`: Current active count
- `subscriptionsByTier`: Breakdown by tier (if groupBy=true)

---

### Export Report

```bash
# Export revenue report as CSV
GET /api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31

# Export subscriptions report
GET /api/admin/reports/export?type=subscriptions&format=csv&startDate=2025-01-01&endDate=2025-01-31

# Export transactions report
GET /api/admin/reports/export?type=transactions&format=csv&startDate=2025-01-01&endDate=2025-01-31
```

**Export Types:**

- `revenue`: Transaction details with revenue metrics
- `subscriptions`: Subscription details with user info
- `transactions`: Detailed payment transaction data

**Formats:**

- `csv`: Comma-separated values (ready)
- `pdf`: PDF format (placeholder - returns CSV)

---

## Common Parameters

| Parameter   | Type    | Required | Default     | Description                 |
| ----------- | ------- | -------- | ----------- | --------------------------- |
| `startDate` | string  | Yes\*    | 30 days ago | Start date (ISO 8601)       |
| `endDate`   | string  | Yes\*    | Now         | End date (ISO 8601)         |
| `groupBy`   | boolean | No       | varies      | Group by subscription tier  |
| `type`      | string  | Yes\*\*  | -           | Report type (export only)   |
| `format`    | string  | Yes\*\*  | -           | Export format (export only) |

\* Required for revenue and export endpoints, optional for subscriptions  
\*\* Required only for export endpoint

---

## Date Format

All dates must be in ISO 8601 format:

- `YYYY-MM-DD` (e.g., `2025-01-31`)
- `YYYY-MM-DDTHH:mm:ss.sssZ` (e.g., `2025-01-31T23:59:59.999Z`)

**Constraints:**

- Date range cannot exceed 1 year
- `startDate` must be ≤ `endDate`
- All dates are in UTC timezone

---

## Permissions

### view_reports

- View revenue reports
- View subscription metrics
- Preview report data

**Roles with this permission:**

- Super Admin
- Finance Admin

### export_reports

- Export reports to CSV/PDF
- Download report files
- All export operations are audit logged

**Roles with this permission:**

- Super Admin
- Finance Admin

---

## Response Codes

| Code | Meaning      | Common Causes                             |
| ---- | ------------ | ----------------------------------------- |
| 200  | Success      | Request completed successfully            |
| 400  | Bad Request  | Invalid parameters, date format, or range |
| 401  | Unauthorized | Missing or invalid JWT token              |
| 403  | Forbidden    | Insufficient permissions                  |
| 500  | Server Error | Database or internal error                |

---

## Key Metrics Explained

### Revenue Metrics

- **Total Revenue**: Sum of all successful transactions
- **Transaction Count**: Number of completed payments
- **Average Transaction Value**: Total revenue ÷ transaction count

### Subscription Metrics

- **MRR (Monthly Recurring Revenue)**: Revenue from last 30 days
- **Churn Rate**: (Canceled ÷ Subscriptions at start) × 100
- **Retention Rate**: 100 - Churn Rate
- **Net Change**: New subscriptions - Canceled subscriptions

---

## Error Handling

### Missing Parameters

```json
{
  "error": "Missing required parameters",
  "message": "Both startDate and endDate are required"
}
```

### Invalid Date

```json
{
  "error": "Invalid date format",
  "message": "Dates must be in ISO 8601 format"
}
```

### Date Range Too Large

```json
{
  "error": "Date range too large",
  "message": "Date range cannot exceed 1 year"
}
```

### Insufficient Permissions

```json
{
  "error": "Insufficient permissions",
  "required": ["export_reports"]
}
```

---

## Best Practices

1. **Date Ranges**: Keep under 1 year for performance
2. **Caching**: Cache frequently accessed reports
3. **Exports**: Use for offline analysis, not real-time data
4. **Audit Trail**: All operations are logged automatically
5. **Permissions**: Verify user has required permissions before calling

---

## Integration Tips

### JavaScript/Fetch

```javascript
const response = await fetch(
  `/api/admin/reports/revenue?startDate=${start}&endDate=${end}`,
  { headers: { Authorization: `Bearer ${token}` } }
);
const data = await response.json();
```

### Axios

```javascript
const { data } = await axios.get('/api/admin/reports/subscriptions', {
  params: { startDate, endDate },
  headers: { Authorization: `Bearer ${token}` },
});
```

### Download Export

```javascript
const response = await fetch(
  `/api/admin/reports/export?type=revenue&format=csv&startDate=${start}&endDate=${end}`,
  { headers: { Authorization: `Bearer ${token}` } }
);
const blob = await response.blob();
const url = URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = 'report.csv';
a.click();
```

---

## Related APIs

- [Users API](./README.md) - User management
- [Payments API](./PAYMENTS_API.md) - Payment transactions
- [Subscriptions API](./SUBSCRIPTIONS_API.md) - Subscription management

---

## Support

For detailed documentation, see [REPORTS_API.md](./REPORTS_API.md)
