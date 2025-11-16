# Audit Log Viewer - Quick Reference Guide

## Overview

The Audit Log Viewer provides administrators with a comprehensive interface to monitor and review all administrative actions performed in the Admin Center.

## Component Location

```dart
import 'package:your_app/screens/admin/audit_log_viewer_tab.dart';

// Usage
AuditLogViewerTab()
```

## Features

### 1. Audit Log Table

**Columns:**
- Timestamp (with "time ago" indicator)
- Action (with category)
- Resource (type and ID)
- Admin User ID
- Affected User ID
- Severity (color-coded badge)
- IP Address
- Actions (view details button)

**Pagination:**
- 100 logs per page
- Previous/Next navigation
- Page indicator
- Total count display

### 2. Filtering

**Available Filters:**
- **Admin User ID**: Filter by administrator who performed the action
- **Action**: Filter by action type (e.g., user_suspended, refund_processed)
- **Resource Type**: Filter by resource (e.g., user, subscription, transaction)
- **Affected User ID**: Filter by user affected by the action
- **Date Range**: Filter by start and end dates
- **Severity**: Filter by severity level (low, medium, high)

**Filter UI:**
- Filter button with badge showing active filter count
- Filter dialog with all filter options
- Active filter chips for quick removal
- Clear all filters button

### 3. Log Details

**Information Displayed:**
- Log ID
- Timestamp (formatted)
- Action and resource details
- Admin user information (email, username, role, ID)
- Affected user information (if applicable)
- IP address and user agent
- Action details (JSON formatted)

**Access:**
- Click the eye icon in the Actions column
- Modal dialog with formatted information
- Selectable text for easy copying

### 4. Export

**CSV Export:**
- Export filtered logs to CSV file
- Automatic download
- Filename format: `audit-logs-YYYY-MM-DD.csv`
- Respects all active filters

## Severity Levels

### High Severity (Red)
Actions that significantly impact users or data:
- delete
- suspend
- revoke
- refund

### Medium Severity (Orange)
Actions that modify data:
- update
- edit
- create
- assign

### Low Severity (Green)
Read-only actions:
- view
- export
- list
- search

## API Endpoints

### Get Audit Logs
```
GET /api/admin/audit/logs
```

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 100, max: 200)
- `adminUserId`: Filter by admin user ID
- `action`: Filter by action type
- `resourceType`: Filter by resource type
- `affectedUserId`: Filter by affected user ID
- `startDate`: Filter by start date (YYYY-MM-DD)
- `endDate`: Filter by end date (YYYY-MM-DD)
- `sortBy`: Sort field (created_at, action, resource_type)
- `sortOrder`: Sort order (asc, desc)

**Response:**
```json
{
  "success": true,
  "data": {
    "logs": [...],
    "pagination": {
      "page": 1,
      "limit": 100,
      "totalLogs": 250,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPreviousPage": false
    }
  }
}
```

### Get Log Details
```
GET /api/admin/audit/logs/:logId
```

**Response:**
```json
{
  "success": true,
  "data": {
    "log": {
      "id": "uuid",
      "action": "user_suspended",
      "resourceType": "user",
      "resourceId": "user-uuid",
      "details": {...},
      "ipAddress": "192.168.1.1",
      "userAgent": "Mozilla/5.0...",
      "createdAt": "2025-11-16T10:30:00Z",
      "adminUser": {
        "id": "admin-uuid",
        "email": "admin@example.com",
        "username": "admin",
        "role": "super_admin"
      },
      "affectedUser": {
        "id": "user-uuid",
        "email": "user@example.com",
        "username": "user"
      }
    }
  }
}
```

### Export Logs
```
GET /api/admin/audit/export
```

**Query Parameters:**
- Same as Get Audit Logs (except page and limit)

**Response:**
- CSV file stream
- Content-Type: text/csv
- Content-Disposition: attachment; filename="audit-logs-YYYY-MM-DD.csv"

## Service Methods

### AdminCenterService

```dart
// Get audit logs with pagination and filtering
Future<Map<String, dynamic>> getAuditLogs({
  int page = 1,
  int limit = 100,
  String? adminUserId,
  String? action,
  String? resourceType,
  String? affectedUserId,
  DateTime? startDate,
  DateTime? endDate,
  String? sortBy,
  String? sortOrder,
});

// Get audit log details by ID
Future<Map<String, dynamic>> getAuditLogDetails(String logId);

// Export audit logs to CSV
Future<void> exportAuditLogs({
  String? adminUserId,
  String? action,
  String? resourceType,
  String? affectedUserId,
  DateTime? startDate,
  DateTime? endDate,
});
```

## Common Actions

### View Recent Logs
1. Open Audit Log Viewer tab
2. Logs are automatically loaded (most recent first)
3. Navigate through pages as needed

### Filter by Date Range
1. Click "Filters" button
2. Select start date and end date
3. Click "Apply"
4. View filtered results

### Find Specific Admin's Actions
1. Click "Filters" button
2. Enter admin user ID
3. Click "Apply"
4. View admin's actions

### View High Severity Actions
1. Click "Filters" button
2. Select "High" from Severity dropdown
3. Click "Apply"
4. View high-severity actions

### Export Filtered Logs
1. Apply desired filters
2. Click "Export CSV" button
3. CSV file downloads automatically

### View Log Details
1. Find log in table
2. Click eye icon in Actions column
3. View detailed information in modal
4. Copy information as needed

### Clear Filters
- **Individual**: Click X on filter chip
- **All**: Click "Clear" button next to Filters

## Error Handling

### No Logs Found
- Displays empty state message
- Suggests clearing filters if active
- Provides clear filters button

### API Error
- Displays error message
- Shows retry button
- Logs error to console

### Export Error
- Shows error notification
- Provides error details
- Allows retry

## Performance Considerations

- **Pagination**: Loads 100 logs at a time
- **Server-side Filtering**: Most filters applied on backend
- **Client-side Severity Filter**: Applied after fetching for better UX
- **Lazy Loading**: Logs loaded on demand
- **Caching**: No caching (always fresh data)

## Permissions Required

- **View Logs**: `view_audit_logs` permission
- **Export Logs**: `export_audit_logs` permission

**Roles with Access:**
- Super Admin: Full access
- Support Admin: View and export
- Finance Admin: View and export

## Best Practices

1. **Use Date Ranges**: Narrow down results for better performance
2. **Combine Filters**: Use multiple filters for precise results
3. **Export Regularly**: Export logs for compliance and backup
4. **Review High Severity**: Regularly check high-severity actions
5. **Monitor Specific Users**: Track actions on sensitive accounts

## Troubleshooting

### Logs Not Loading
- Check network connection
- Verify admin permissions
- Check browser console for errors
- Try refreshing the page

### Filters Not Working
- Ensure filter values are correct format
- Check date range is valid
- Verify user IDs exist
- Clear filters and try again

### Export Not Downloading
- Check browser download settings
- Verify export permissions
- Check network connection
- Try smaller date range

## Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/admin/audit_log_viewer_tab.dart';
import 'services/admin_center_service.dart';

class AdminCenterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin Center'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Users'),
              Tab(text: 'Payments'),
              Tab(text: 'Subscriptions'),
              Tab(text: 'Reports'),
              Tab(text: 'Audit Logs'), // <-- Audit Log tab
              Tab(text: 'Admins'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DashboardTab(),
            UserManagementTab(),
            PaymentManagementTab(),
            SubscriptionManagementTab(),
            FinancialReportsTab(),
            AuditLogViewerTab(), // <-- Audit Log viewer
            AdminManagementTab(),
          ],
        ),
      ),
    );
  }
}
```

## Related Documentation

- [Admin Center Design Document](design.md)
- [Admin Center Requirements](requirements.md)
- [Admin Audit Log Model](../../lib/models/admin_audit_log_model.dart)
- [Admin Center Service](../../lib/services/admin_center_service.dart)
- [Backend Audit API](../../services/api-backend/routes/admin/audit.js)

---

**Last Updated**: November 16, 2025
**Component Version**: 1.0.0
**Status**: Production Ready
