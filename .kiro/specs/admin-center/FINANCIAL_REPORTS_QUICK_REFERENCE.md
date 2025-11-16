# Financial Reports Tab - Quick Reference

## Overview

The Financial Reports Tab provides comprehensive revenue and subscription analytics for administrators with proper permissions.

## Access Requirements

- **Permission Required:** `view_reports`
- **Export Permission:** `export_reports` (for CSV/PDF downloads)
- **Location:** Admin Center > Financial Reports

## Features

### 1. Report Types

#### Revenue Report
- **Total Revenue:** Sum of all successful transactions
- **Transaction Count:** Number of completed transactions
- **Average Transaction Value:** Mean transaction amount
- **Revenue by Tier:** Breakdown by Free, Premium, Enterprise

#### Subscription Metrics
- **Monthly Recurring Revenue (MRR):** Total recurring revenue
- **Active Subscriptions:** Current active subscription count
- **Churn Rate:** Percentage of canceled subscriptions
- **Retention Rate:** Percentage of retained subscriptions
- **New Subscriptions:** New subscriptions in period
- **Canceled Subscriptions:** Cancellations in period
- **Subscriptions by Tier:** Detailed breakdown per tier

### 2. Date Range Selection

- **Default Range:** Last 30 days
- **Custom Range:** Use date picker to select any range
- **Format:** Displays as "MMM d, y - MMM d, y"
- **Limitation:** Maximum 1 year range (enforced by backend)

### 3. Export Options

#### CSV Export
- Downloads report data in CSV format
- Filename: `{type}_report_{startDate}_{endDate}.csv`
- Opens in Excel, Google Sheets, etc.

#### PDF Export
- Downloads report data (currently CSV format)
- Filename: `{type}_report_{startDate}_{endDate}.pdf`
- Note: Full PDF formatting coming soon

## Usage Guide

### Viewing Revenue Report

1. Navigate to Admin Center > Financial Reports
2. Select "Revenue Report" from dropdown
3. Choose date range (or use default)
4. View summary metrics:
   - Total Revenue
   - Transaction Count
   - Average Transaction Value
5. Review revenue breakdown by tier in table

### Viewing Subscription Metrics

1. Navigate to Admin Center > Financial Reports
2. Select "Subscription Metrics" from dropdown
3. Choose date range (or use default)
4. View summary metrics:
   - MRR
   - Active Subscriptions
   - Churn Rate
   - Retention Rate
   - New/Canceled Subscriptions
5. Review subscriptions by tier in table

### Exporting Reports

1. Select report type and date range
2. Click "CSV" or "PDF" button
3. File downloads automatically
4. Open in your preferred application

## API Endpoints

### Revenue Report
```
GET /api/admin/reports/revenue
Query Params:
  - startDate: YYYY-MM-DD
  - endDate: YYYY-MM-DD
  - groupBy: true/false
```

### Subscription Metrics
```
GET /api/admin/reports/subscriptions
Query Params:
  - startDate: YYYY-MM-DD
  - endDate: YYYY-MM-DD
  - groupBy: true/false
```

### Export Report
```
GET /api/admin/reports/export
Query Params:
  - type: revenue|subscriptions|transactions
  - format: csv|pdf
  - startDate: YYYY-MM-DD
  - endDate: YYYY-MM-DD
```

## Metrics Explained

### Revenue Metrics

- **Total Revenue:** Sum of all `succeeded` transactions in date range
- **Transaction Count:** Count of all `succeeded` transactions
- **Average Transaction Value:** Total Revenue / Transaction Count
- **Revenue by Tier:** Grouped by user's subscription tier at time of transaction

### Subscription Metrics

- **MRR (Monthly Recurring Revenue):** Total revenue from successful transactions in last 30 days
- **Churn Rate:** (Canceled Subscriptions / Total Subscriptions) × 100
- **Retention Rate:** 100 - Churn Rate
- **Active Subscriptions:** Subscriptions with status = 'active'
- **New Subscriptions:** Subscriptions created in date range
- **Canceled Subscriptions:** Subscriptions canceled in date range

## Troubleshooting

### "You do not have permission to view reports"
- **Cause:** Missing `view_reports` permission
- **Solution:** Contact Super Admin to grant permission

### "You do not have permission to export reports"
- **Cause:** Missing `export_reports` permission
- **Solution:** Contact Super Admin to grant permission

### "Failed to load report"
- **Cause:** Network error or API issue
- **Solution:** Click "Retry" button or refresh page

### "No data available"
- **Cause:** No transactions/subscriptions in selected date range
- **Solution:** Try a different date range

### Export not downloading
- **Cause:** Browser blocking download or network issue
- **Solution:** Check browser download settings, try again

## Best Practices

### Date Range Selection
1. Start with default 30-day range
2. Adjust based on analysis needs
3. Keep ranges reasonable (< 1 year)
4. Use consistent ranges for comparisons

### Report Analysis
1. Review summary metrics first
2. Drill down into tier breakdowns
3. Compare different time periods
4. Export for detailed analysis

### Export Usage
1. Export for offline analysis
2. Share with stakeholders
3. Archive for compliance
4. Import into other tools

## Performance Tips

- **Smaller Date Ranges:** Faster report generation
- **Avoid Frequent Exports:** Use view mode when possible
- **Cache Results:** Reports are cached for 5 minutes
- **Batch Analysis:** Export once, analyze multiple times

## Security Notes

- All report views are logged in audit trail
- All exports are logged with admin user ID
- Sensitive data included in exports (handle securely)
- Do not share exports publicly

## Keyboard Shortcuts

- **Tab:** Navigate between controls
- **Enter:** Confirm date selection
- **Esc:** Close date picker

## Mobile Support

- Responsive layout for tablets
- Horizontal scrolling for tables
- Touch-friendly controls
- Optimized for landscape orientation

## Related Documentation

- [Admin Reports API](../../services/api-backend/routes/admin/REPORTS_API.md)
- [Admin Center Service](../../lib/services/admin_center_service.dart)
- [Financial Reports Tab](../../lib/screens/admin/financial_reports_tab.dart)

## Support

For issues or questions:
1. Check error message for specific details
2. Review audit logs for operation history
3. Verify permissions are correctly configured
4. Contact system administrator

---

**Last Updated:** November 16, 2025
**Version:** 1.0.0
