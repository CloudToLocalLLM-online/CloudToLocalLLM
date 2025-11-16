# Admin Center Screen - Quick Reference

## Overview

The AdminCenterScreen is the main interface for the Admin Center feature, providing sidebar navigation and role-based access to administrative functions.

## File Location

```
lib/screens/admin/admin_center_screen.dart
```

## Key Features

### 1. Sidebar Navigation
- Fixed 260px width sidebar
- Role-based navigation filtering
- Active tab highlighting
- Admin user info display
- Exit button to return to main app

### 2. Tab Management
- 8 integrated tab components
- Dynamic content rendering
- Tab switching with state management
- Permission-based visibility

### 3. Role-Based Access Control
- Automatic permission checking
- Navigation items filtered by role
- Integration with AdminCenterService

## Navigation Items

| Tab ID | Label | Icon | Required Permission | Component |
|--------|-------|------|---------------------|-----------|
| `dashboard` | Dashboard | `dashboard` | None (all admins) | Placeholder (Task 16) |
| `users` | User Management | `people` | `viewUsers` | UserManagementTab |
| `payments` | Payment Management | `payment` | `viewPayments` | PaymentManagementTab |
| `subscriptions` | Subscription Management | `subscriptions` | `viewSubscriptions` | SubscriptionManagementTab |
| `reports` | Financial Reports | `bar_chart` | `viewReports` | FinancialReportsTab |
| `audit` | Audit Logs | `history` | `viewAuditLogs` | AuditLogViewerTab |
| `admins` | Admin Management | `admin_panel_settings` | `viewAdmins` | AdminManagementTab |
| `email` | Email Provider | `email` | `viewConfiguration` | EmailProviderConfigTab |

## Usage

### Accessing the Admin Center

1. User must be authenticated
2. User email must be `cmaltais@cloudtolocalllm.online` (or have admin role in database)
3. Navigate to `/admin-center` route
4. Screen automatically checks authorization and loads admin roles

### Navigation Flow

```
1. User clicks "Admin Center" in settings
2. AdminCenterScreen loads
3. Authorization check runs
4. AdminCenterService initializes and loads roles
5. Navigation items filtered by permissions
6. Default tab (dashboard) displayed
7. User can switch between tabs
```

## Code Examples

### Adding a New Navigation Item

```dart
_NavigationItem(
  id: 'my-tab',
  label: 'My Tab',
  icon: Icons.my_icon,
  builder: () => const MyTabWidget(),
  requiredPermissions: [AdminPermission.myPermission],
)
```

### Checking Permissions

```dart
// In AdminCenterScreen
final hasPermission = _adminService.hasPermission(AdminPermission.viewUsers);

// Navigation items are automatically filtered
final visibleItems = _visibleNavigationItems;
```

### Switching Tabs Programmatically

```dart
setState(() {
  _selectedTabId = 'users';
});
```

## State Management

### State Variables

```dart
bool _isCheckingAuth = true;      // Loading state during auth check
bool _isAuthorized = false;       // Authorization result
String? _errorMessage;            // Error message if auth fails
String _selectedTabId = 'dashboard'; // Currently selected tab
late AdminCenterService _adminService; // Admin service instance
late final List<_NavigationItem> _allNavigationItems; // All nav items
```

### Computed Properties

```dart
List<_NavigationItem> get _visibleNavigationItems {
  // Returns filtered navigation items based on permissions
}
```

## UI Components

### Sidebar Structure

```
┌─────────────────────────┐
│ Admin Center Header     │
│ - Icon + Title          │
│ - User Email            │
├─────────────────────────┤
│ Navigation Items        │
│ - Dashboard             │
│ - User Management       │
│ - Payment Management    │
│ - ...                   │
│ (scrollable)            │
├─────────────────────────┤
│ Exit Button             │
└─────────────────────────┘
```

### Main Content Structure

```
┌─────────────────────────────────────┐
│ Header                              │
│ - Tab Icon + Title                  │
│ - Refresh Button                    │
├─────────────────────────────────────┤
│                                     │
│ Tab Content                         │
│ (Dynamic based on selected tab)     │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

## Theming

### Colors Used
- `theme.colorScheme.surface` - Sidebar background
- `theme.colorScheme.primaryContainer` - Selected tab background
- `theme.colorScheme.onPrimaryContainer` - Selected tab text/icon
- `theme.colorScheme.primary` - Header icons
- `theme.dividerColor` - Borders

### Spacing
- Sidebar width: 260px
- Sidebar padding: 20px (header), 16px (footer)
- Navigation item padding: 16px horizontal, 12px vertical
- Header padding: 24px horizontal, 16px vertical

## Integration Points

### Services
- `AdminCenterService` - Role and permission management
- `AuthService` - User authentication and email

### Models
- `AdminRoleModel` - Admin role data
- `AdminPermission` - Permission enum

### Routes
- `/admin-center` - Main admin center route (defined in router.dart)

## Error Handling

### Authorization Failures
- Shows "Access Denied" screen
- Displays error message
- Provides "Return to Home" button

### Loading States
- Shows loading indicator during auth check
- Displays "Verifying admin permissions..." message

### Permission Errors
- Navigation items automatically hidden if no permission
- Dio interceptor catches 403 errors and shows message

## Best Practices

### Adding New Tabs
1. Create tab widget in `lib/screens/admin/`
2. Add navigation item to `_allNavigationItems`
3. Define required permissions
4. Import tab widget at top of file

### Permission Checks
- Always use `AdminCenterService.hasPermission()` for checks
- Define permissions in `AdminPermission` enum
- Map permissions to admin roles in `AdminRoleModel`

### State Updates
- Use `setState()` for tab switching
- Refresh button triggers tab rebuild
- Service state changes trigger UI updates

## Testing

### Manual Testing Checklist
- [ ] Screen loads without errors
- [ ] Authorization check works
- [ ] Sidebar displays correctly
- [ ] All tabs are accessible
- [ ] Tab switching works
- [ ] Permission filtering works
- [ ] Exit button navigates correctly
- [ ] Refresh button works
- [ ] Responsive layout works

### Common Issues
1. **Tab not showing**: Check permission mapping
2. **Service not initialized**: Ensure `initialize()` called
3. **Navigation not working**: Check `_selectedTabId` state
4. **Permission errors**: Verify admin roles loaded

## Future Enhancements

### Planned Features
1. Keyboard shortcuts for tab navigation (Ctrl+1, Ctrl+2, etc.)
2. Breadcrumb navigation for nested views
3. Tab state persistence (remember last tab)
4. Notification badges on navigation items
5. Collapsible sidebar for more screen space
6. Search functionality in sidebar
7. Recent tabs history
8. Customizable sidebar order

### Performance Optimizations
1. Lazy load tab content
2. Cache tab state
3. Virtualize long navigation lists
4. Optimize permission checks

## Related Documentation

- [Task 15 Completion Summary](./TASK_15_COMPLETION_SUMMARY.md)
- [Admin Center Design](./design.md)
- [Admin Center Requirements](./requirements.md)
- [Admin Center Service](../../lib/services/admin_center_service.dart)
- [Admin Role Model](../../lib/models/admin_role_model.dart)

## Support

For issues or questions:
1. Check diagnostics: `flutter analyze lib/screens/admin/admin_center_screen.dart`
2. Review completion summary for implementation details
3. Check AdminCenterService for permission logic
4. Review router.dart for route configuration
