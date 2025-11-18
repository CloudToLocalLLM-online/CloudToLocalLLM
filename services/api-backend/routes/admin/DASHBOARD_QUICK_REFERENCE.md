# Admin Dashboard API - Quick Reference

## Endpoint

```
GET /api/admin/dashboard/metrics
```

## Authentication

```
Authorization: Bearer <JWT_TOKEN>
```

## Response Structure

```json
{
  "success": true,
  "data": {
    "users": {
      "total": 1250,
      "active": 450,
      "newThisMonth": 85,
      "activePercentage": "36.00"
    },
    "subscriptions": {
      "distribution": { "free": 1000, "premium": 200, "enterprise": 50 },
      "totalSubscribed": 250,
      "conversionRate": "20.00"
    },
    "revenue": {
      "mrr": "3497.50",
      "currentMonth": "3850.75",
      "transactionCount": 125,
      "averageTransactionValue": "30.81"
    },
    "recentTransactions": [
      /* last 10 transactions */
    ]
  }
}
```

## Key Metrics

| Metric                | Description                          | Calculation                                                            |
| --------------------- | ------------------------------------ | ---------------------------------------------------------------------- |
| Total Users           | Registered users (excluding deleted) | `COUNT(users WHERE deleted_at IS NULL)`                                |
| Active Users          | Users active in last 30 days         | `COUNT(DISTINCT user_sessions WHERE last_activity >= NOW() - 30 days)` |
| New Users             | Registrations this month             | `COUNT(users WHERE created_at >= current_month_start)`                 |
| MRR                   | Monthly Recurring Revenue            | `(Premium × $9.99) + (Enterprise × $29.99)`                            |
| Current Month Revenue | Total revenue this month             | `SUM(successful_transactions WHERE created_at >= current_month_start)` |
| Conversion Rate       | Paid subscription percentage         | `(Paid Subscribers / Total Users) × 100`                               |

## Quick Test

```bash
curl -X GET http://localhost:3001/api/admin/dashboard/metrics \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Common Use Cases

1. **Dashboard Overview**: Display key metrics on admin dashboard
2. **Performance Monitoring**: Track user growth and revenue trends
3. **Business Intelligence**: Analyze conversion rates and MRR
4. **Real-time Updates**: Refresh metrics every 60 seconds

## Error Codes

- `DASHBOARD_METRICS_FAILED`: Database query error
- `UNAUTHORIZED`: Invalid or missing token
- `FORBIDDEN`: User is not an admin

## Requirements Satisfied

- ✅ Requirement 2: User Management Dashboard
- ✅ Requirement 11: Role-Based Access Control
