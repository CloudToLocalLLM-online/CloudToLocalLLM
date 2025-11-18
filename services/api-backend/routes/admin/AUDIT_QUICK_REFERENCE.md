# Audit Log API - Quick Reference

## Base URL

```
/api/admin/audit
```

## Authentication

All endpoints require JWT Bearer token with admin role and appropriate permissions.

---

## Endpoints Summary

| Method | Endpoint       | Permission          | Description                    |
| ------ | -------------- | ------------------- | ------------------------------ |
| GET    | `/logs`        | `view_audit_logs`   | List audit logs with filtering |
| GET    | `/logs/:logId` | `view_audit_logs`   | Get detailed audit log entry   |
| GET    | `/export`      | `export_audit_logs` | Export audit logs to CSV       |

---

## Quick Examples

### List Recent Audit Logs

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?page=1&limit=50" \
  -H "Authorization: Bearer <jwt_token>"
```

### Filter by Action Type

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?action=user_suspended" \
  -H "Authorization: Bearer <jwt_token>"
```

### Filter by Admin User

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?adminUserId=<uuid>" \
  -H "Authorization: Bearer <jwt_token>"
```

### Filter by Affected User

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?affectedUserId=<uuid>" \
  -H "Authorization: Bearer <jwt_token>"
```

### Filter by Date Range

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>"
```

### Get Specific Log Entry

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs/<log_id>" \
  -H "Authorization: Bearer <jwt_token>"
```

### Export to CSV

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/export?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>" \
  -o audit-logs.csv
```

---

## Common Action Types

- `user_suspended` - User account suspended
- `user_reactivated` - User account reactivated
- `subscription_tier_changed` - Subscription tier modified
- `refund_processed` - Payment refund processed
- `subscription_upgraded` - Subscription upgraded
- `subscription_downgraded` - Subscription downgraded
- `subscription_cancelled` - Subscription cancelled
- `payment_method_removed` - Payment method removed
- `admin_role_granted` - Admin role assigned
- `admin_role_revoked` - Admin role revoked

---

## Common Resource Types

- `user` - User account
- `subscription` - Subscription
- `transaction` - Payment transaction
- `payment_method` - Payment method
- `admin_role` - Admin role assignment

---

## Query Parameters

### List Logs (`GET /logs`)

| Parameter      | Type     | Default    | Description               |
| -------------- | -------- | ---------- | ------------------------- |
| page           | integer  | 1          | Page number               |
| limit          | integer  | 100        | Items per page (max: 200) |
| adminUserId    | UUID     | -          | Filter by admin user      |
| action         | string   | -          | Filter by action type     |
| resourceType   | string   | -          | Filter by resource type   |
| affectedUserId | UUID     | -          | Filter by affected user   |
| startDate      | ISO 8601 | -          | Start date filter         |
| endDate        | ISO 8601 | -          | End date filter           |
| sortBy         | string   | created_at | Sort field                |
| sortOrder      | string   | desc       | Sort order (asc/desc)     |

### Export Logs (`GET /export`)

| Parameter      | Type     | Description             |
| -------------- | -------- | ----------------------- |
| adminUserId    | UUID     | Filter by admin user    |
| action         | string   | Filter by action type   |
| resourceType   | string   | Filter by resource type |
| affectedUserId | UUID     | Filter by affected user |
| startDate      | ISO 8601 | Start date filter       |
| endDate        | ISO 8601 | End date filter         |

---

## Response Format

### Success Response

```json
{
  "success": true,
  "data": {
    "logs": [...],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalLogs": 250,
      "totalPages": 5,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "filters": {...}
  },
  "timestamp": "2025-01-15T10:35:00Z"
}
```

### Error Response

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional details"
}
```

---

## Error Codes

| Code                  | Description                    |
| --------------------- | ------------------------------ |
| `INVALID_LOG_ID`      | Invalid audit log ID format    |
| `LOG_NOT_FOUND`       | Audit log entry not found      |
| `AUDIT_LOGS_FAILED`   | Failed to retrieve audit logs  |
| `LOG_DETAILS_FAILED`  | Failed to retrieve log details |
| `AUDIT_EXPORT_FAILED` | Failed to export audit logs    |

---

## Rate Limits

- **Standard:** 100 requests per 15 minutes
- **Export:** 10 exports per hour

---

## Permissions

| Permission          | Description              |
| ------------------- | ------------------------ |
| `view_audit_logs`   | View audit log entries   |
| `export_audit_logs` | Export audit logs to CSV |

**Role Permissions:**

- **Super Admin:** All permissions
- **Support Admin:** `view_audit_logs`
- **Finance Admin:** `view_audit_logs`

---

## Tips

1. Use date range filters for better performance
2. Export logs regularly for compliance
3. Monitor for suspicious patterns
4. Use specific filters to narrow results
5. Check pagination for large result sets
6. Review logs after critical operations

---

## Related Documentation

- [Full API Reference](./AUDIT_API.md)
- [Admin Authentication](../../middleware/admin-auth.js)
- [Audit Logger Utility](../../utils/audit-logger.js)
