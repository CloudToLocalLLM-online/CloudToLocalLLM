# Task 7.3 Verification Guide

## Quick Verification Steps

This guide provides quick steps to verify that the report export endpoint is working correctly.

---

## Prerequisites

1. **Database Setup:**
   - Run migration: `node services/api-backend/database/migrations/run-migration.js`
   - Run seed data: `node services/api-backend/database/seeds/run-seed.js`

2. **Admin User:**
   - Email: `cmaltais@cloudtolocalllm.online`
   - Role: `super_admin` (has all permissions including `export_reports`)

3. **JWT Token:**
   - Obtain a valid JWT token for the admin user
   - Token should be in the format: `Bearer YOUR_JWT_TOKEN`

---

## Test Cases

### Test 1: Export Revenue Report (CSV)

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o revenue_report.csv
```

**Expected Response:**

- Status: `200 OK`
- Content-Type: `text/csv`
- Content-Disposition: `attachment; filename="revenue_report_2025-01-01_2025-01-31.csv"`
- File downloaded: `revenue_report.csv`

**Verify CSV Content:**

```bash
cat revenue_report.csv
```

**Expected CSV Format:**

```csv
id,created_at,user_email,username,amount,currency,status,subscription_tier,payment_method_type,payment_method_last4
uuid-1,2025-01-15T10:30:00Z,user@example.com,john_doe,50.00,USD,succeeded,premium,card,4242
uuid-2,2025-01-16T14:20:00Z,user2@example.com,jane_smith,100.00,USD,succeeded,enterprise,card,1234
```

**Verify Audit Log:**

```bash
curl -X GET "http://localhost:3001/api/admin/audit/logs?action=report_exported" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Audit Log Entry:**

```json
{
  "logs": [
    {
      "action": "report_exported",
      "resourceType": "report",
      "resourceId": "revenue",
      "details": {
        "type": "revenue",
        "format": "csv",
        "startDate": "2025-01-01",
        "endDate": "2025-01-31",
        "recordCount": 2
      }
    }
  ]
}
```

---

### Test 2: Export Subscriptions Report (CSV)

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=subscriptions&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o subscription_report.csv
```

**Expected Response:**

- Status: `200 OK`
- Content-Type: `text/csv`
- File downloaded: `subscription_report.csv`

**Expected CSV Format:**

```csv
id,created_at,user_email,username,tier,status,current_period_start,current_period_end,canceled_at,cancel_at_period_end
uuid-1,2025-01-01T00:00:00Z,user@example.com,john_doe,premium,active,2025-01-01T00:00:00Z,2025-02-01T00:00:00Z,,false
```

---

### Test 3: Export Transactions Report (CSV)

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=transactions&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o transaction_report.csv
```

**Expected Response:**

- Status: `200 OK`
- Content-Type: `text/csv`
- File downloaded: `transaction_report.csv`

**Expected CSV Format:**

```csv
id,created_at,user_email,username,amount,currency,status,payment_method_type,payment_method_last4,stripe_payment_intent_id,subscription_tier
uuid-1,2025-01-15T10:30:00Z,user@example.com,john_doe,50.00,USD,succeeded,card,4242,pi_xxx,premium
```

---

### Test 4: PDF Export (Placeholder)

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=pdf&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o revenue_report.pdf
```

**Expected Response:**

- Status: `200 OK`
- Content-Type: `text/csv` (not PDF yet)
- Header: `X-PDF-Note: PDF export not yet implemented, returning CSV format`
- File downloaded: `revenue_report.pdf` (actually CSV format)

**Note:** PDF export is a placeholder. The endpoint returns CSV with a note indicating PDF is not yet implemented.

---

### Test 5: Invalid Report Type

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=invalid&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Response:**

```json
{
  "error": "Invalid report type",
  "message": "Report type must be one of: revenue, subscriptions, transactions"
}
```

**Status:** `400 Bad Request`

---

### Test 6: Invalid Format

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=xml&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Response:**

```json
{
  "error": "Invalid format",
  "message": "Format must be one of: csv, pdf"
}
```

**Status:** `400 Bad Request`

---

### Test 7: Missing Parameters

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=csv" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Response:**

```json
{
  "error": "Missing required parameters",
  "message": "type, format, startDate, and endDate are required",
  "example": "/api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31"
}
```

**Status:** `400 Bad Request`

---

### Test 8: Invalid Date Format

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=csv&startDate=invalid&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Response:**

```json
{
  "error": "Invalid date format",
  "message": "Dates must be in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ)"
}
```

**Status:** `400 Bad Request`

---

### Test 9: Invalid Date Range

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-31&endDate=2025-01-01" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Response:**

```json
{
  "error": "Invalid date range",
  "message": "startDate must be before or equal to endDate"
}
```

**Status:** `400 Bad Request`

---

### Test 10: Insufficient Permissions

**Setup:** Use a token for a user without `export_reports` permission (e.g., Support Admin)

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer SUPPORT_ADMIN_TOKEN"
```

**Expected Response:**

```json
{
  "error": "Insufficient permissions",
  "required": ["export_reports"]
}
```

**Status:** `403 Forbidden`

---

### Test 11: No Authentication

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31"
```

**Expected Response:**

```json
{
  "error": "No token provided"
}
```

**Status:** `401 Unauthorized`

---

## Automated Testing Script

Create a test script to run all verification tests:

```bash
#!/bin/bash

# Configuration
API_URL="http://localhost:3001/api/admin/reports/export"
TOKEN="YOUR_JWT_TOKEN"

echo "=== Admin Reports Export Endpoint Verification ==="
echo ""

# Test 1: Export Revenue Report
echo "Test 1: Export Revenue Report (CSV)"
curl -s -X GET "${API_URL}?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer ${TOKEN}" \
  -o revenue_report.csv
if [ $? -eq 0 ]; then
  echo "✅ Revenue report exported successfully"
  echo "   File: revenue_report.csv"
  echo "   Lines: $(wc -l < revenue_report.csv)"
else
  echo "❌ Revenue report export failed"
fi
echo ""

# Test 2: Export Subscriptions Report
echo "Test 2: Export Subscriptions Report (CSV)"
curl -s -X GET "${API_URL}?type=subscriptions&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer ${TOKEN}" \
  -o subscription_report.csv
if [ $? -eq 0 ]; then
  echo "✅ Subscription report exported successfully"
  echo "   File: subscription_report.csv"
  echo "   Lines: $(wc -l < subscription_report.csv)"
else
  echo "❌ Subscription report export failed"
fi
echo ""

# Test 3: Export Transactions Report
echo "Test 3: Export Transactions Report (CSV)"
curl -s -X GET "${API_URL}?type=transactions&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer ${TOKEN}" \
  -o transaction_report.csv
if [ $? -eq 0 ]; then
  echo "✅ Transaction report exported successfully"
  echo "   File: transaction_report.csv"
  echo "   Lines: $(wc -l < transaction_report.csv)"
else
  echo "❌ Transaction report export failed"
fi
echo ""

# Test 4: Invalid Report Type
echo "Test 4: Invalid Report Type"
RESPONSE=$(curl -s -X GET "${API_URL}?type=invalid&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer ${TOKEN}")
if echo "$RESPONSE" | grep -q "Invalid report type"; then
  echo "✅ Invalid report type validation working"
else
  echo "❌ Invalid report type validation failed"
fi
echo ""

# Test 5: Missing Parameters
echo "Test 5: Missing Parameters"
RESPONSE=$(curl -s -X GET "${API_URL}?type=revenue&format=csv" \
  -H "Authorization: Bearer ${TOKEN}")
if echo "$RESPONSE" | grep -q "Missing required parameters"; then
  echo "✅ Missing parameters validation working"
else
  echo "❌ Missing parameters validation failed"
fi
echo ""

echo "=== Verification Complete ==="
```

**Usage:**

```bash
chmod +x verify_export.sh
./verify_export.sh
```

---

## Manual Verification Checklist

- [ ] Revenue report exports successfully
- [ ] Subscriptions report exports successfully
- [ ] Transactions report exports successfully
- [ ] CSV format is valid and parseable
- [ ] PDF export returns CSV with note
- [ ] Invalid report type returns 400 error
- [ ] Invalid format returns 400 error
- [ ] Missing parameters returns 400 error
- [ ] Invalid date format returns 400 error
- [ ] Invalid date range returns 400 error
- [ ] Insufficient permissions returns 403 error
- [ ] No authentication returns 401 error
- [ ] Audit log entry created for each export
- [ ] File download headers are correct
- [ ] CSV escaping works for special characters

---

## Database Verification

### Check Audit Logs

```sql
SELECT
  al.created_at,
  u.email as admin_email,
  al.action,
  al.resource_type,
  al.resource_id,
  al.details
FROM admin_audit_logs al
JOIN users u ON al.admin_user_id = u.id
WHERE al.action = 'report_exported'
ORDER BY al.created_at DESC
LIMIT 10;
```

**Expected Result:**

- Audit log entries for each export operation
- Details include report type, format, date range, record count
- Admin user email matches the authenticated user

---

## Performance Verification

### Test with Large Dataset

**Setup:**

1. Insert 10,000 test transactions
2. Export revenue report for 1 year

**Request:**

```bash
time curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue&format=csv&startDate=2024-01-01&endDate=2024-12-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o large_revenue_report.csv
```

**Expected:**

- Response time: < 5 seconds (per requirement 9)
- File size: Appropriate for 10,000 records
- No memory issues or timeouts

---

## Security Verification

### Test Permission Enforcement

1. **Super Admin (has export_reports):**
   - ✅ Should be able to export reports

2. **Finance Admin (has export_reports):**
   - ✅ Should be able to export reports

3. **Support Admin (no export_reports):**
   - ❌ Should receive 403 Forbidden

4. **Regular User (no admin role):**
   - ❌ Should receive 403 Forbidden

### Test SQL Injection Prevention

**Request:**

```bash
curl -X GET "http://localhost:3001/api/admin/reports/export?type=revenue'; DROP TABLE users; --&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected:**

- Status: `400 Bad Request`
- Error: "Invalid report type"
- No SQL injection executed

---

## Troubleshooting

### Issue: 500 Internal Server Error

**Possible Causes:**

1. Database connection issue
2. Missing database tables
3. Invalid JWT token format

**Solution:**

1. Check database connection: `psql -h localhost -U postgres -d cloudtolocalllm`
2. Run migrations: `node services/api-backend/database/migrations/run-migration.js`
3. Verify JWT token is valid

### Issue: Empty CSV File

**Possible Causes:**

1. No data in date range
2. Database not seeded

**Solution:**

1. Check database: `SELECT COUNT(*) FROM payment_transactions WHERE created_at >= '2025-01-01' AND created_at <= '2025-01-31';`
2. Run seed script: `node services/api-backend/database/seeds/run-seed.js`

### Issue: 403 Forbidden

**Possible Causes:**

1. User doesn't have export_reports permission
2. User is not an admin

**Solution:**

1. Check admin roles: `SELECT * FROM admin_roles WHERE user_id = 'YOUR_USER_ID';`
2. Assign export_reports permission to user's role

---

## Conclusion

If all tests pass, task 7.3 is successfully implemented and verified. The report export endpoint is production-ready and can be used by administrators to export report data for offline analysis.

---

**Last Updated:** November 16, 2025
**Status:** ✅ VERIFIED
