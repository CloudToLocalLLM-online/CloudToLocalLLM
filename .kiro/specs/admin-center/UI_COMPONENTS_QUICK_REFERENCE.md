# Admin Center UI Components - Quick Reference

## Component Overview

| Component | File | Purpose |
|-----------|------|---------|
| AdminCard | `admin_card.dart` | Reusable card container |
| AdminTable | `admin_table.dart` | Data table with pagination |
| AdminSearchBar | `admin_search_bar.dart` | Search input with filters |
| AdminFilterChip | `admin_filter_chip.dart` | Filter selection chips |
| AdminStatCard | `admin_stat_card.dart` | Metric display cards |
| AdminStyles | `admin_styles.dart` | Styling utilities |
| AdminAccessibility | `admin_accessibility.dart` | Accessibility helpers |
| AdminResponsive | `admin_responsive.dart` | Responsive layout helpers |

## Quick Examples

### Display a Card

```dart
AdminCard(
  title: 'User Details',
  child: Text('Content here'),
)
```

### Display a Table

```dart
AdminTable(
  columns: [
    AdminTableColumn(label: 'Email', field: 'email', sortable: true),
    AdminTableColumn(label: 'Status', field: 'status'),
  ],
  rows: users,
  currentPage: 1,
  totalPages: 10,
  totalItems: 500,
  itemsPerPage: 50,
  onPageChanged: (page) => _loadPage(page),
)
```

### Display a Search Bar

```dart
AdminSearchBar(
  controller: _searchController,
  hintText: 'Search users',
  onChanged: (value) => _search(value),
  filters: [
    AdminFilterChip(
      label: 'Active',
      selected: _filter == 'active',
      onSelected: () => _setFilter('active'),
    ),
  ],
)
```

### Display Stat Cards

```dart
AdminStatCardGrid(
  cards: [
    AdminStatCard(
      title: 'Total Users',
      value: '1,234',
      icon: Icons.people,
      trend: 12.5,
    ),
  ],
)
```

### Display Status Badge

```dart
AdminStyles.statusBadge(context, 'active')
```

### Display Tier Badge

```dart
AdminStyles.tierBadge(context, 'premium')
```

### Check Screen Size

```dart
if (AdminResponsive.isMobile(context)) {
  // Mobile layout
} else {
  // Desktop layout
}
```

### Responsive Value

```dart
final columns = AdminResponsive.value(
  context,
  mobile: 1,
  tablet: 2,
  desktop: 4,
);
```

### Responsive Grid

```dart
AdminResponsiveGrid(
  children: cards,
  maxColumns: 4,
)
```

## Color Reference

### Status Colors
- `active` → Green
- `inactive` → Gray
- `suspended` → Orange
- `deleted` → Red
- `pending` → Blue
- `succeeded` → Green
- `failed` → Red

### Tier Colors
- `free` → Gray
- `premium` → Purple
- `enterprise` → Teal

## Spacing Reference

- `AppTheme.spacingXS` → 4px
- `AppTheme.spacingS` → 8px
- `AppTheme.spacingM` → 16px
- `AppTheme.spacingL` → 24px
- `AppTheme.spacingXL` → 32px

## Breakpoints

- Mobile: < 768px
- Tablet: 768px - 1440px
- Desktop: >= 1440px

## Common Patterns

### Loading State

```dart
if (_isLoading) {
  return AdminStyles.loadingIndicator(message: 'Loading...');
}
```

### Empty State

```dart
if (_items.isEmpty) {
  return AdminStyles.emptyState(
    message: 'No items found',
    icon: Icons.inbox,
  );
}
```

### Error State

```dart
if (_error != null) {
  return AdminErrorMessage(
    message: _error!,
    onRetry: () => _retry(),
  );
}
```

### Responsive Layout

```dart
AdminResponsive.builder(
  context: context,
  mobile: MobileView(),
  desktop: DesktopView(),
)
```

### Action Button

```dart
AdminStyles.actionButton(
  context: context,
  label: 'Save',
  icon: Icons.save,
  onPressed: () => _save(),
)
```

### Destructive Action

```dart
AdminStyles.actionButton(
  context: context,
  label: 'Delete',
  icon: Icons.delete,
  onPressed: () => _delete(),
  isDestructive: true,
)
```

## Import Statements

```dart
import 'package:flutter/material.dart';
import '../widgets/admin_card.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_search_bar.dart';
import '../widgets/admin_filter_chip.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_styles.dart';
import '../widgets/admin_accessibility.dart';
import '../widgets/admin_responsive.dart';
import '../config/theme.dart';
```

## Best Practices

1. **Always use AppTheme constants** for colors, spacing, and border radius
2. **Use AdminStyles utilities** for consistent badges and buttons
3. **Check screen size** with AdminResponsive before rendering
4. **Add semantic labels** for accessibility
5. **Test on multiple screen sizes** (mobile, tablet, desktop)
6. **Use AdminCard** for content containers
7. **Use AdminTable** for data lists
8. **Use AdminSearchBar** for search functionality
9. **Use AdminStatCard** for metrics
10. **Follow responsive patterns** for all layouts
