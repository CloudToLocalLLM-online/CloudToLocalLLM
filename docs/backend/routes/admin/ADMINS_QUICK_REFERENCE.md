# Admin Management API - Quick Reference

## Base URL

`/api/admin/admins`

## Authentication

All endpoints require **Super Admin** role.

---

## Endpoints

### List Administrators

```
GET /api/admin/admins
```

Returns all administrators with roles and activity summary.

### Assign Admin Role

```
POST /api/admin/admins
Body: { email, role }
```

Assigns `support_admin` or `finance_admin` role to a user.

### Revoke Admin Role

```
DELETE /api/admin/admins/:userId/roles/:role
```

Revokes specified admin role from user.

---

## Valid Roles

| Role            | Can Assign? | Permissions                          |
| --------------- | ----------- | ------------------------------------ |
| `super_admin`   | ❌ No       | Full access, manage admins           |
| `support_admin` | ✅ Yes      | User management, view payments       |
| `finance_admin` | ✅ Yes      | Payment management, refunds, reports |

---

## Quick Examples

### List all admins

```bash
curl -X GET https://api.cloudtolocalllm.online/api/admin/admins \
  -H "Authorization: Bearer TOKEN"
```

### Assign support admin role

```bash
curl -X POST https://api.cloudtolocalllm.online/api/admin/admins \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","role":"support_admin"}'
```

### Revoke admin role

```bash
curl -X DELETE https://api.cloudtolocalllm.online/api/admin/admins/USER_ID/roles/support_admin \
  -H "Authorization: Bearer TOKEN"
```

---

## Status Codes

| Code | Meaning               |
| ---- | --------------------- |
| 200  | Success               |
| 201  | Role assigned         |
| 400  | Invalid input         |
| 401  | Not authenticated     |
| 403  | Not Super Admin       |
| 404  | User/role not found   |
| 409  | Role already assigned |
| 500  | Server error          |

---

## Important Notes

- ⚠️ **Super Admin only** - All endpoints require Super Admin role
- 🔒 **Self-protection** - Cannot revoke your own Super Admin role
- 📝 **Audit logged** - All actions are logged to audit trail
- 🚫 **No Super Admin assignment** - Cannot assign Super Admin through API
- ✅ **User must exist** - User must be registered before assigning role

---

## See Also

- [Full API Documentation](./ADMINS_API.md)
- [Admin Authentication](../../middleware/admin-auth.js)
- [Audit Logging](../../utils/audit-logger.js)
