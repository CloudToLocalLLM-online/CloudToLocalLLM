# Admin Center Screen Architecture

## Visual Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Admin Center Screen                          │
├──────────────────┬──────────────────────────────────────────────────┤
│                  │                                                  │
│   SIDEBAR        │              MAIN CONTENT AREA                   │
│   (260px)        │                                                  │
│                  │                                                  │
│ ┌──────────────┐ │ ┌──────────────────────────────────────────────┐│
│ │ Admin Center │ │ │ Header                                       ││
│ │ [Icon] Title │ │ │ [Tab Icon] Tab Title          [Refresh]     ││
│ │ user@email   │ │ └──────────────────────────────────────────────┘│
│ └──────────────┘ │                                                  │
│                  │ ┌──────────────────────────────────────────────┐│
│ Navigation:      │ │                                              ││
│ ┌──────────────┐ │ │                                              ││
│ │► Dashboard   │ │ │                                              ││
│ └──────────────┘ │ │                                              ││
│ ┌──────────────┐ │ │          Tab Content Widget                 ││
│ │  Users       │ │ │          (Dynamic based on                  ││
│ └──────────────┘ │ │           selected tab)                     ││
│ ┌──────────────┐ │ │                                              ││
│ │  Payments    │ │ │                                              ││
│ └──────────────┘ │ │                                              ││
│ ┌──────────────┐ │ │                                              ││
│ │  Subscript.  │ │ │                                              ││
│ └──────────────┘ │ │                                              ││
│ ┌──────────────┐ │ └──────────────────────────────────────────────┘│
│ │  Reports     │ │                                                  │
│ └──────────────┘ │                                                  │
│ ┌──────────────┐ │                                                  │
│ │  Audit Logs  │ │                                                  │
│ └──────────────┘ │                                                  │
│ ┌──────────────┐ │                                                  │
│ │  Admins      │ │                                                  │
│ └──────────────┘ │                                                  │
│ ┌──────────────┐ │                                                  │
│ │  Email       │ │                                                  │
│ └──────────────┘ │                                                  │
│                  │                                                  │
│ ┌──────────────┐ │                                                  │
│ │ Exit Admin   │ │                                                  │
│ │   Center     │ │                                                  │
│ └──────────────┘ │                                                  │
└──────────────────┴──────────────────────────────────────────────────┘
```

## Component Hierarchy

```
AdminCenterScreen (StatefulWidget)
├── Authorization Check (Loading/Error States)
│   ├── Loading: CircularProgressIndicator
│   └── Error: Access Denied Screen
│
└── Main Layout (Row)
    ├── Sidebar (Container - 260px)
    │   ├── Header (Container)
    │   │   ├── Icon + Title
    │   │   └── User Email
    │   │
    │   ├── Navigation Items (ListView)
    │   │   └── NavigationItem (Material + InkWell)
    │   │       ├── Icon
    │   │       └── Label
    │   │
    │   └── Footer (Container)
    │       └── Exit Button
    │
    └── Content Area (Expanded)
        ├── Header (Container)
        │   ├── Tab Icon + Title
        │   └── Refresh Button
        │
        └── Tab Content (Expanded)
            └── Dynamic Widget (based on selected tab)
```

## State Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Screen Initialization                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Check Admin Authorization                       │
│  - Get user email from AuthService                          │
│  - Check if email matches authorized admin                  │
│  - Initialize AdminCenterService                            │
│  - Load admin roles from backend                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                    Authorized?
                    /         \
                  Yes          No
                   │            │
                   ▼            ▼
    ┌──────────────────┐  ┌──────────────┐
    │ Show Admin UI    │  │ Show Error   │
    │ - Build sidebar  │  │ - Access     │
    │ - Load tabs      │  │   Denied     │
    │ - Filter by      │  │ - Return     │
    │   permissions    │  │   Button     │
    └────────┬─────────┘  └──────────────┘
             │
             ▼
    ┌──────────────────┐
    │ User Interaction │
    │ - Click nav item │
    │ - Switch tabs    │
    │ - Refresh data   │
    │ - Exit admin     │
    └────────┬─────────┘
             │
             ▼
    ┌──────────────────┐
    │ Update State     │
    │ - _selectedTabId │
    │ - Rebuild UI     │
    └──────────────────┘
```

## Permission Filtering Flow

```
┌─────────────────────────────────────────────────────────────┐
│              All Navigation Items Defined                    │
│  - Dashboard (no permissions)                               │
│  - Users (viewUsers)                                        │
│  - Payments (viewPayments)                                  │
│  - Subscriptions (viewSubscriptions)                        │
│  - Reports (viewReports)                                    │
│  - Audit Logs (viewAuditLogs)                              │
│  - Admins (viewAdmins)                                      │
│  - Email (viewConfiguration)                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           Get Visible Navigation Items                       │
│  For each navigation item:                                  │
│    1. Check if permissions required                         │
│    2. If no permissions → show to all                       │
│    3. If permissions → check with AdminCenterService        │
│    4. Filter out items without permission                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Render Filtered Navigation                      │
│  - Build sidebar with visible items only                    │
│  - Highlight selected tab                                   │
│  - Show tab content for selected item                       │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌──────────────┐
│ AuthService  │
│ - User email │
│ - JWT token  │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ AdminCenterService   │
│ - Load admin roles   │
│ - Check permissions  │
│ - Dashboard metrics  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ AdminCenterScreen    │
│ - Filter navigation  │
│ - Render UI          │
│ - Handle tab switch  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Tab Components       │
│ - UserManagementTab  │
│ - PaymentTab         │
│ - SubscriptionTab    │
│ - ReportsTab         │
│ - AuditTab           │
│ - AdminTab           │
│ - EmailTab           │
└──────────────────────┘
```

## Role-Based Navigation Example

### Super Admin (All Permissions)
```
Sidebar Navigation:
✓ Dashboard
✓ User Management
✓ Payment Management
✓ Subscription Management
✓ Financial Reports
✓ Audit Logs
✓ Admin Management
✓ Email Provider
```

### Support Admin (Limited Permissions)
```
Sidebar Navigation:
✓ Dashboard
✓ User Management
✓ Payment Management (view only)
✗ Subscription Management
✗ Financial Reports
✓ Audit Logs
✗ Admin Management
✗ Email Provider
```

### Finance Admin (Payment Focus)
```
Sidebar Navigation:
✓ Dashboard
✓ User Management (view only)
✓ Payment Management
✓ Subscription Management
✓ Financial Reports
✓ Audit Logs
✗ Admin Management
✗ Email Provider
```

## Tab Switching Sequence

```
1. User clicks navigation item
   │
   ▼
2. _onTabSelected(tabId) called
   │
   ▼
3. setState() updates _selectedTabId
   │
   ▼
4. Widget rebuilds
   │
   ▼
5. selectedItem computed from _selectedTabId
   │
   ▼
6. Header updates with new tab icon/title
   │
   ▼
7. Content area renders new tab widget
   │
   ▼
8. Tab widget initializes and loads data
```

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Error Scenarios                           │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Auth Failed  │  │ Service Init │  │ Permission   │
│ - Show error │  │   Failed     │  │   Denied     │
│ - Return btn │  │ - Show error │  │ - Hide tab   │
└──────────────┘  │ - Retry btn  │  │ - Show msg   │
                  └──────────────┘  └──────────────┘
```

## Performance Considerations

### Lazy Loading
- Tab content only rendered when selected
- Navigation items filtered once on load
- Service initialization happens once

### State Management
- Minimal state in screen widget
- Service state managed by AdminCenterService
- Tab state managed by individual tab widgets

### Rebuild Optimization
- Only selected tab widget rebuilds on data changes
- Sidebar navigation cached after filtering
- Header updates only on tab switch

## Integration Points

### Services
```
AdminCenterScreen
    ├── AuthService (user authentication)
    └── AdminCenterService (roles & permissions)
            ├── GET /api/admin/auth/roles
            ├── hasRole(role)
            └── hasPermission(permission)
```

### Models
```
AdminCenterScreen
    ├── AdminRoleModel
    │   ├── role: AdminRole
    │   └── permissions: List<AdminPermission>
    └── AdminPermission (enum)
        ├── viewUsers
        ├── viewPayments
        ├── viewSubscriptions
        └── ...
```

### Routes
```
Router (go_router)
    └── /admin-center → AdminCenterScreen
            ├── Authorization check
            └── Tab navigation (internal state)
```

## Future Architecture Enhancements

### Planned Improvements
1. **State Persistence**
   - Save selected tab to local storage
   - Restore tab on screen reload

2. **Nested Navigation**
   - Support sub-tabs within main tabs
   - Breadcrumb navigation

3. **Keyboard Shortcuts**
   - Ctrl+1-8 for tab switching
   - Ctrl+R for refresh

4. **Notification System**
   - Badge counts on navigation items
   - Real-time updates via WebSocket

5. **Customization**
   - User-configurable sidebar order
   - Collapsible sidebar
   - Theme customization

## Related Files

- `lib/screens/admin/admin_center_screen.dart` - Main screen implementation
- `lib/services/admin_center_service.dart` - Service layer
- `lib/models/admin_role_model.dart` - Role and permission models
- `lib/config/router.dart` - Route configuration
- `.kiro/specs/admin-center/design.md` - Design specification
- `.kiro/specs/admin-center/requirements.md` - Requirements document
