# Admin Management API Documentation

## Overview

The Admin Management API provides secure endpoints for Super Admins to manage administrator accounts and roles. All endpoints require Super Admin authentication and log all actions to the audit trail.

**Base URL:** `/api/admin/admins`

**Authentication:** JWT Bearer token with Super Admin role required

**Rate Limiting:** 100 requests per minute per admin

---

## Endpoints

### 1. List All Administrators

Get a list of all administrators with their roles and activity summary.

**Endpoint:** `GET /api/admin/admins`

**Authentication:** Super Admin required

**Query Parameters:** None

**Response:**

```json
{
  "admins": [
    {
      "userId": "uuid",
      "email": "admin@example.com",
      "username": "admin_user",
      "userCreatedAt": "2025-01-01T00:00:00Z",
      "roles": [
        {
          "role": "super_admin",
          "grantedBy": "uuid",
          "grantedByEmail": "superadmin@example.com",
          "grantedAt": "2025-01-01T00:00:00Z",
          "revokedAt": null,
          "isActive": true
        }
      ],
      "activitySummary": {
        "totalActions": 150,
        "lastActionAt": "2025-11-15T10:30:00Z",
        "recentActions": 25
      }
    }
  ],
  "total": 5
}
```

**Status Codes:**

- `200 OK` - Successfully retrieved administrators
- `401 Unauthorized` - Invalid or missing authentication token
- `403 Forbidden` - User is not a Super Admin
- `500 Internal Server Error` - Server error

**Example Request:**

```bash
curl -X GET https://api.cloudtolocalllm.online/api/admin/admins \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

### 2. Assign Admin Role

Assign an admin role to a user by email.

**Endpoint:** `POST /api/admin/admins`

**Authentication:** Super Admin required

**Request Body:**

```json
{
  "email": "user@example.com",
  "role": "support_admin"
}
```

**Request Fields:**

- `email` (string, required) - Email address of the user to make admin
- `role` (string, required) - Role to assign: `support_admin` or `finance_admin`

**Response:**

```json
{
  "success": true,
  "message": "Admin role support_admin assigned to user@example.com",
  "admin": {
    "userId": "uuid",
    "email": "user@example.com",
    "username": "username",
    "role": "support_admin",
    "grantedBy": "uuid",
    "grantedByEmail": "superadmin@example.com",
    "grantedAt": "2025-11-15T10:30:00Z"
  }
}
```

**Status Codes:**

- `201 Created` - Admin role assigned successfully
- `400 Bad Request` - Missing required fields or invalid role
- `401 Unauthorized` - Invalid or missing authentication token
- `403 Forbidden` - User is not a Super Admin
- `404 Not Found` - User with specified email not found
- `409 Conflict` - User already has the specified role
- `500 Internal Server Error` - Server error

**Example Request:**

```bash
curl -X POST https://api.cloudtolocalllm.online/api/admin/admins \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "role": "support_admin"
  }'
```

**Valid Roles:**

- `support_admin` - Can manage users and view payments
- `finance_admin` - Can manage payments, refunds, and subscriptions

**Notes:**

- Only Super Admins can assign admin roles
- Cannot assign `super_admin` role through this endpoint
- User must already exist in the system
- Action is logged in the audit trail

---

### 3. Revoke Admin Role

Revoke an admin role from a user.

**Endpoint:** `DELETE /api/admin/admins/:userId/roles/:role`

**Authentication:** Super Admin required

**URL Parameters:**

- `userId` (string, required) - ID of the user to revoke role from
- `role` (string, required) - Role to revoke: `super_admin`, `support_admin`, or `finance_admin`

**Response:**

```json
{
  "success": true,
  "message": "Admin role support_admin revoked from user@example.com",
  "revokedRole": {
    "userId": "uuid",
    "email": "user@example.com",
    "username": "username",
    "role": "support_admin",
    "revokedBy": "uuid",
    "revokedByEmail": "superadmin@example.com",
    "revokedAt": "2025-11-15T10:30:00Z"
  }
}
```

**Status Codes:**

- `200 OK` - Admin role revoked successfully
- `400 Bad Request` - Invalid role
- `401 Unauthorized` - Invalid or missing authentication token
- `403 Forbidden` - User is not a Super Admin or attempting to revoke own Super Admin role
- `404 Not Found` - User not found or user does not have the specified active role
- `500 Internal Server Error` - Server error

**Example Request:**

```bash
curl -X DELETE https://api.cloudtolocalllm.online/api/admin/admins/USER_UUID/roles/support_admin \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Notes:**

- Only Super Admins can revoke admin roles
- Cannot revoke your own Super Admin role (safety measure)
- Role is marked as inactive (soft delete) for audit trail
- Action is logged in the audit trail
- User can have multiple roles; this only revokes the specified role

---

## Role Permissions

### Super Admin

- Full access to all admin features
- Can manage other administrators
- Can assign and revoke admin roles
- Cannot be assigned through API (must be set in database)

### Support Admin

- View and manage users
- Suspend/reactivate user accounts
- View payment information (read-only)
- View audit logs
- Cannot process refunds or delete users

### Finance Admin

- View users (read-only)
- Manage payments and refunds
- Manage subscriptions
- View and export financial reports
- View audit logs
- Cannot suspend users or delete accounts

---

## Error Responses

All endpoints return consistent error responses:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "message": "Detailed error description"
}
```

**Common Error Codes:**

- `NO_TOKEN` - No authentication token provided
- `INVALID_TOKEN` - Invalid or expired token
- `ADMIN_ACCESS_REQUIRED` - User is not an admin
- `INSUFFICIENT_ROLE` - User does not have Super Admin role
- `MISSING_FIELDS` - Required fields missing from request
- `INVALID_ROLE` - Invalid role specified
- `USER_NOT_FOUND` - User not found
- `ROLE_ALREADY_ASSIGNED` - User already has the specified role
- `ROLE_NOT_FOUND` - User does not have the specified active role
- `CANNOT_REVOKE_OWN_SUPER_ADMIN` - Cannot revoke own Super Admin role

---

## Audit Logging

All admin management operations are logged to the audit trail with the following information:

- Admin user ID and email
- Action performed (admin_role_assigned, admin_role_revoked)
- Affected user ID and email
- Role assigned or revoked
- Timestamp
- IP address
- User agent

Audit logs can be viewed through the Audit Log API endpoints.

---

## Security Considerations

1. **Super Admin Only**: All endpoints require Super Admin role
2. **Self-Protection**: Cannot revoke your own Super Admin role
3. **Audit Trail**: All actions are logged for compliance
4. **Rate Limiting**: 100 requests per minute per admin
5. **Input Validation**: All inputs are validated and sanitized
6. **Role Restrictions**: Cannot assign Super Admin role through API

---

## Examples

### Complete Workflow: Assign and Revoke Admin Role

```bash
# 1. List all current administrators
curl -X GET https://api.cloudtolocalllm.online/api/admin/admins \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# 2. Assign Support Admin role to a user
curl -X POST https://api.cloudtolocalllm.online/api/admin/admins \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "support@example.com",
    "role": "support_admin"
  }'

# 3. Verify the role was assigned
curl -X GET https://api.cloudtolocalllm.online/api/admin/admins \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# 4. Revoke the role
curl -X DELETE https://api.cloudtolocalllm.online/api/admin/admins/USER_UUID/roles/support_admin \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## Related Documentation

- [Admin Authentication Middleware](../../middleware/admin-auth.js)
- [Audit Logger Utility](../../utils/audit-logger.js)
- [Admin API Overview](./README.md)
- [Audit Log API](./AUDIT_API.md)
