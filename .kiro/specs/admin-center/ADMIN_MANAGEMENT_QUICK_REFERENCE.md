# Admin Management Tab - Quick Reference

## Overview
The Admin Management Tab allows Super Admin users to manage administrator accounts and roles within the CloudToLocalLLM Admin Center.

## Access Requirements
- **Role Required**: Super Admin only
- **Location**: Admin Center > Admin Management tab
- **Visibility**: Hidden from non-Super Admin users

## Features

### 1. View Administrators
- Lists all administrators with their roles
- Shows activity summary for each admin
- Displays role badges with color coding

### 2. Add Administrator
- Search for users by email
- Assign Support Admin or Finance Admin role
- Cannot assign Super Admin role (database only)

### 3. Revoke Roles
- Remove Support Admin or Finance Admin roles
- Cannot revoke Super Admin role
- Confirmation required before revocation

### 4. Activity Tracking
- Total actions performed
- Recent actions (last 30 days)
- Last action timestamp

## User Interface

### Admin Card Layout
```
┌─────────────────────────────────────────────────┐
│ [Avatar] email@example.com                      │
│          username                               │
│                                                 │
│ [Super Admin] [Support Admin] [Finance Admin]  │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ Total Actions: 150                          │ │
│ │ Recent (30d): 25                            │ │
│ │ Last Action: 2d ago                         │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Add Admin Dialog
```
┌─────────────────────────────────────┐
│ Add Administrator                   │
│                                     │
│ Email Address                       │
│ [user@example.com              ]    │
│                                     │
│ Select Role                         │
│ [Support Admin ▼               ]    │
│   - User management and support     │
│                                     │
│           [Cancel]  [Add Admin]     │
└─────────────────────────────────────┘
```

## API Endpoints

### GET /api/admin/admins
**Purpose**: List all administrators

**Response**:
```json
{
  "admins": [
    {
      "userId": "uuid",
      "email": "admin@example.com",
      "username": "admin",
      "roles": [
        {
          "role": "super_admin",
          "grantedBy": "uuid",
          "grantedByEmail": "superadmin@example.com",
          "grantedAt": "2025-01-01T00:00:00Z",
          "isActive": true
        }
      ],
      "activitySummary": {
        "totalActions": 150,
        "lastActionAt": "2025-11-14T10:30:00Z",
        "recentActions": 25
      }
    }
  ],
  "total": 1
}
```

### POST /api/admin/admins
**Purpose**: Assign admin role to a user

**Request**:
```json
{
  "email": "user@example.com",
  "role": "support_admin"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Admin role support_admin assigned to user@example.com",
  "admin": {
    "userId": "uuid",
    "email": "user@example.com",
    "username": "user",
    "role": "support_admin",
    "grantedBy": "uuid",
    "grantedByEmail": "superadmin@example.com",
    "grantedAt": "2025-11-16T10:30:00Z"
  }
}
```

### DELETE /api/admin/admins/:userId/roles/:role
**Purpose**: Revoke admin role from a user

**Response**:
```json
{
  "success": true,
  "message": "Admin role support_admin revoked from user@example.com",
  "revokedRole": {
    "userId": "uuid",
    "email": "user@example.com",
    "username": "user",
    "role": "support_admin",
    "revokedBy": "uuid",
    "revokedByEmail": "superadmin@example.com",
    "revokedAt": "2025-11-16T10:35:00Z"
  }
}
```

## Admin Roles

### Super Admin
- **Color**: Purple
- **Permissions**: All permissions
- **Can Assign**: No (database only)
- **Can Revoke**: No (database only)
- **Description**: Full system access

### Support Admin
- **Color**: Blue
- **Permissions**: User management, view payments, view audit logs
- **Can Assign**: Yes
- **Can Revoke**: Yes
- **Description**: User management and support

### Finance Admin
- **Color**: Green
- **Permissions**: Payment management, refunds, reports
- **Can Assign**: Yes
- **Can Revoke**: Yes
- **Description**: Financial operations

## Workflows

### Add New Administrator
1. Click "Add Admin" button
2. Enter user email address
3. Select role (Support Admin or Finance Admin)
4. Click "Add Admin"
5. Verify success message
6. Admin appears in list with assigned role

### Revoke Administrator Role
1. Locate admin in list
2. Click X button on role chip
3. Confirm revocation in dialog
4. Verify success message
5. Role removed from admin's role list

### View Admin Activity
1. Locate admin in list
2. View activity summary card:
   - Total Actions: Lifetime count
   - Recent (30d): Last 30 days
   - Last Action: Relative time

## Error Messages

### Common Errors

**User Not Found**
```
Failed to assign admin role: No user found with email: user@example.com
```
**Solution**: Verify email address is correct and user exists

**Role Already Assigned**
```
Failed to assign admin role: User user@example.com already has the support_admin role
```
**Solution**: User already has this role, no action needed

**Insufficient Permissions**
```
Admin access denied. You do not have permission to perform this action.
```
**Solution**: Only Super Admin can access this tab

**Cannot Revoke Own Super Admin**
```
Failed to revoke role: You cannot revoke your own Super Admin role
```
**Solution**: Another Super Admin must revoke the role

## Best Practices

### Role Assignment
- Assign minimum required role for user's responsibilities
- Support Admin for user support and account management
- Finance Admin for payment and financial operations
- Document reason for role assignment in team notes

### Role Revocation
- Revoke roles when admin leaves team
- Revoke roles when responsibilities change
- Verify revocation in audit logs
- Communicate role changes to affected admin

### Activity Monitoring
- Review admin activity regularly
- Investigate inactive admins
- Monitor recent actions for unusual patterns
- Use audit logs for detailed investigation

## Security Notes

- All admin actions are logged in audit log
- Super Admin role cannot be assigned through UI
- Cannot revoke own Super Admin role
- Email validation prevents invalid inputs
- Confirmation required before revocation
- Backend validates Super Admin role on all operations

## Troubleshooting

### Tab Not Visible
**Issue**: Admin Management tab not showing
**Solution**: Verify you have Super Admin role

### Cannot Add Admin
**Issue**: Add admin button not working
**Solution**: Check network connection and backend API status

### Cannot Revoke Role
**Issue**: Revoke button not working
**Solution**: Verify you're not trying to revoke Super Admin role or your own role

### Activity Not Updating
**Issue**: Activity summary not showing recent actions
**Solution**: Refresh the page or check audit log API

## Related Documentation

- [Admin Center Design](./design.md)
- [Admin Center Requirements](./requirements.md)
- [Admin Center Tasks](./tasks.md)
- [Admin API Documentation](../../services/api-backend/routes/admin/ADMINS_API.md)
- [Audit Log Documentation](./AUDIT_LOG_VIEWER_QUICK_REFERENCE.md)

## Support

For issues or questions:
1. Check audit logs for detailed action history
2. Review backend logs for API errors
3. Verify Super Admin role in database
4. Contact system administrator for role assignments
