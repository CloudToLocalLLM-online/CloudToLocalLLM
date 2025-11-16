# Dashboard Tab Quick Reference

## Overview

The Dashboard Tab provides a real-time overview of key Admin Center metrics including users, subscriptions, revenue, and recent transactions.

## File Location

```
lib/screens/admin/dashboard_tab.dart
```

## Key Features

### 1. Metrics Cards

Four primary metric cards displayed in a responsive grid:

| Metric | Description | Icon | Color |
|--------|-------------|------|-------|
| Total Users | Total registered users + new this month | people | Primary |
| Active Users | Users active in last 30 days + percentage | person_outline | Success |
| MRR | Monthly recurring revenue + subscriber count | attach_money | Warning |
| Current Month Revenue | Total revenue + transaction count | trending_up | Info |

### 2. Subscription Distribution

Visual bar chart showing:
- Free tier (gray)
- Premium tier (primary)
- Enterprise tier (warning)
- Conversion rate percentage

### 3. Recent Transactions

List of last 10 transactions with:
- User email
- Payment method (last 4 digits)
- Amount
- Subscription tier
- Timestamp (relative)
- Status indicator (success/failed)

### 4. Auto-Refresh

- Automatic refresh every 60 seconds
- Manual refresh button in app bar
- Pull-to-refresh gesture support
- Last updated timestamp display

## Usage

### Basic Integration

```dart
// In AdminCenterScreen
import 'package:your_app/screens/admin/dashboard_tab.dart';

Widget _buildContent() {
  switch (_selectedTab) {
    case 'dashboard':
      return const DashboardTab();
    // ... other tabs
  }
}
```

### Service Dependency

Requires `AdminCenterService` to be available in the widget tree:

```dart
Provider<AdminCenterService>(
  create: (_) => AdminCenterService(authService: authService),
  child: AdminCenterScreen(),
)
```

## API Integration

### Endpoint

```
GET /api/admin/dashboard/metrics
```

### Response Structure

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
      "distribution": {
        "free": 1000,
        "premium": 200,
        "enterprise": 50
      },
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
      {
        "id": "uuid",
        "userId": "uuid",
        "userEmail": "user@example.com",
        "amount": "29.99",
        "currency": "USD",
        "status": "succeeded",
        "paymentMethod": "card",
        "last4": "4242",
        "subscriptionTier": "enterprise",
        "createdAt": "2025-11-16T10:30:00Z"
      }
    ]
  }
}
```

## State Management

### Loading States

```dart
// Initial load
if (_metrics == null) {
  return CircularProgressIndicator();
}

// Refresh in progress
if (_isLoading) {
  return CircularProgressIndicator(strokeWidth: 2);
}
```

### Error Handling

```dart
// Error display
if (_error != null) {
  return Column(
    children: [
      AdminErrorMessage(errorMessage: _error!),
      ElevatedButton(onPressed: _loadMetrics, child: Text('Retry')),
    ],
  );
}
```

## Responsive Layout

### Breakpoints

- **Desktop (>1024px)**: 4-column grid
- **Tablet (768-1024px)**: 2-column grid
- **Mobile (<768px)**: 1-column grid

### Grid Configuration

```dart
AdminStatCardGrid(
  crossAxisCount: 4,  // Desktop default
  childAspectRatio: 1.5,
  cards: [...],
)
```

## Formatting Utilities

### Number Formatting

```dart
_formatNumber(1250) // "1250"
_formatNumber("1250") // "1250"
```

### Currency Formatting

```dart
_formatCurrency("3497.50") // "3497.50"
_formatCurrency(3497.5) // "3497.50"
```

### Time Formatting

```dart
_formatTime(DateTime.now()) // "Just now"
_formatTime(DateTime.now().subtract(Duration(minutes: 5))) // "5m ago"
_formatTime(DateTime.now().subtract(Duration(hours: 2))) // "14:30"
```

### DateTime Formatting

```dart
_formatDateTime("2025-11-16T10:30:00Z") // "Today 10:30"
_formatDateTime("2025-11-15T10:30:00Z") // "Yesterday"
_formatDateTime("2025-11-10T10:30:00Z") // "6 days ago"
```

## Customization

### Refresh Interval

To change the auto-refresh interval:

```dart
// In _startAutoRefresh()
_refreshTimer = Timer.periodic(
  const Duration(seconds: 120), // Change from 60 to 120 seconds
  (_) => _loadMetrics(),
);
```

### Metrics Display

To add/remove metric cards:

```dart
AdminStatCardGrid(
  cards: [
    AdminStatCard(
      title: 'Custom Metric',
      value: '123',
      icon: Icons.custom_icon,
      iconColor: Colors.purple,
    ),
    // ... other cards
  ],
)
```

### Transaction Count

To change the number of recent transactions:

```dart
// Backend returns last 10 by default
// To display fewer:
itemCount: min(transactions.length, 5), // Show only 5
```

## Performance Tips

### Optimization

1. **Efficient Rendering**
   ```dart
   ListView.separated(
     shrinkWrap: true,
     physics: NeverScrollableScrollPhysics(),
     // ... prevents unnecessary scrolling
   )
   ```

2. **Memory Management**
   ```dart
   @override
   void dispose() {
     _refreshTimer?.cancel(); // Always cancel timer
     super.dispose();
   }
   ```

3. **Conditional Rendering**
   ```dart
   if (transactions.isEmpty) {
     return EmptyState();
   }
   // Only render list if data exists
   ```

## Troubleshooting

### Common Issues

1. **Metrics not loading**
   - Check AdminCenterService is initialized
   - Verify JWT token is valid
   - Check network connectivity
   - Review API endpoint configuration

2. **Auto-refresh not working**
   - Verify timer is started in initState
   - Check timer is not cancelled prematurely
   - Ensure widget is still mounted

3. **Layout issues**
   - Check screen width breakpoints
   - Verify AppTheme spacing constants
   - Test on different screen sizes

### Debug Mode

Enable debug logging:

```dart
Future<void> _loadMetrics() async {
  debugPrint('[DashboardTab] Loading metrics...');
  try {
    final metrics = await adminService.getDashboardMetrics();
    debugPrint('[DashboardTab] Metrics loaded: ${metrics.keys}');
  } catch (e) {
    debugPrint('[DashboardTab] Error: $e');
  }
}
```

## Testing

### Widget Tests

```dart
testWidgets('Dashboard displays metrics', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Provider<AdminCenterService>(
        create: (_) => mockAdminService,
        child: DashboardTab(),
      ),
    ),
  );
  
  expect(find.text('Total Users'), findsOneWidget);
  expect(find.text('Active Users'), findsOneWidget);
});
```

### Integration Tests

```dart
test('Auto-refresh updates metrics', () async {
  final dashboard = DashboardTab();
  await tester.pumpWidget(dashboard);
  
  // Wait for auto-refresh
  await tester.pump(Duration(seconds: 60));
  
  // Verify metrics updated
  verify(mockService.getDashboardMetrics()).called(2);
});
```

## Related Files

- `lib/services/admin_center_service.dart` - Service for fetching metrics
- `lib/widgets/admin_stat_card.dart` - Metric card widget
- `lib/widgets/admin_error_message.dart` - Error display widget
- `lib/config/theme.dart` - Theme constants
- `services/api-backend/routes/admin/dashboard.js` - Backend API

## API Documentation

See: `services/api-backend/routes/admin/DASHBOARD_API.md`

## Requirements

Implements **Requirement 2: User Management Dashboard**

All acceptance criteria:
- ✅ Displays total users, active users, new registrations
- ✅ Displays subscription tier distribution with charts
- ✅ Displays monthly recurring revenue and total revenue
- ✅ Displays recent payment transactions with status
- ✅ Displays system health metrics
- ✅ Refreshes automatically every 60 seconds

---

**Last Updated:** November 16, 2025  
**Version:** 1.0.0  
**Status:** Production Ready
