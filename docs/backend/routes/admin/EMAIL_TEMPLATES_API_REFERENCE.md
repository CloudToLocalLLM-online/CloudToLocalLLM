# Email Template Management API - Quick Reference

## Base URL

```
/api/admin/email/templates
```

---

## Endpoints

### 1. List Templates

```
GET /api/admin/email/templates
```

**Query Parameters:**

- `limit` (optional): 1-100, default 50
- `offset` (optional): default 0

**Response:**

```json
{
  "success": true,
  "data": {
    "templates": [
      {
        "id": "uuid",
        "name": "password_reset",
        "description": "Password reset email",
        "subject": "Reset Your Password",
        "variables": ["resetLink", "expiresIn"],
        "is_system_template": false,
        "is_active": true,
        "created_at": "2025-11-16T10:00:00Z",
        "updated_at": "2025-11-16T10:00:00Z"
      }
    ],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total": 5
    }
  },
  "timestamp": "2025-11-16T10:00:00Z"
}
```

---

### 2. Create/Update Template

```
POST /api/admin/email/templates
```

**Request Body:**

```json
{
  "name": "password_reset",
  "subject": "Reset Your Password",
  "html_body": "<html><body>Click <a href='{{resetLink}}'>here</a> to reset</body></html>",
  "text_body": "Click this link to reset: {{resetLink}}",
  "description": "Password reset email template",
  "variables": ["resetLink", "expiresIn"]
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "template": {
      "id": "uuid",
      "name": "password_reset",
      "description": "Password reset email template",
      "subject": "Reset Your Password",
      "variables": ["resetLink", "expiresIn"],
      "is_active": true,
      "created_at": "2025-11-16T10:00:00Z",
      "updated_at": "2025-11-16T10:00:00Z"
    }
  },
  "message": "Template created/updated successfully",
  "timestamp": "2025-11-16T10:00:00Z"
}
```

**Validation:**

- `name`: Required, non-empty string
- `subject`: Required, non-empty string
- `html_body`: Required, non-empty string
- `text_body`: Optional, string
- `description`: Optional, string
- `variables`: Optional, array of strings

---

### 3. Update Template

```
PUT /api/admin/email/templates/:id
```

**URL Parameters:**

- `id`: Template UUID

**Request Body:** (all optional)

```json
{
  "name": "password_reset_v2",
  "subject": "Reset Your Password - Updated",
  "html_body": "<html><body>Updated content</body></html>",
  "text_body": "Updated text",
  "description": "Updated description",
  "variables": ["resetLink", "expiresIn", "userName"]
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "template": {
      "id": "uuid",
      "name": "password_reset_v2",
      "description": "Updated description",
      "subject": "Reset Your Password - Updated",
      "variables": ["resetLink", "expiresIn", "userName"],
      "is_active": true,
      "created_at": "2025-11-16T10:00:00Z",
      "updated_at": "2025-11-16T10:05:00Z"
    }
  },
  "message": "Template updated successfully",
  "timestamp": "2025-11-16T10:05:00Z"
}
```

**Notes:**

- Only provided fields are updated
- Required fields cannot be emptied
- Partial updates supported

---

### 4. Delete Template

```
DELETE /api/admin/email/templates/:id
```

**URL Parameters:**

- `id`: Template UUID

**Response:**

```json
{
  "success": true,
  "message": "Template deleted successfully",
  "timestamp": "2025-11-16T10:00:00Z"
}
```

---

## Error Responses

### 400 Bad Request

```json
{
  "error": "Template name is required",
  "code": "MISSING_NAME"
}
```

### 404 Not Found

```json
{
  "error": "Template not found",
  "code": "TEMPLATE_NOT_FOUND"
}
```

### 500 Server Error

```json
{
  "error": "Failed to create/update email template",
  "code": "TEMPLATE_SAVE_FAILED",
  "details": "Database error message"
}
```

---

## Common Error Codes

| Code                   | HTTP | Description                             |
| ---------------------- | ---- | --------------------------------------- |
| MISSING_NAME           | 400  | Template name is required               |
| MISSING_SUBJECT        | 400  | Template subject is required            |
| MISSING_HTML_BODY      | 400  | Template HTML body is required          |
| INVALID_VARIABLES      | 400  | Variables must be an array              |
| INVALID_NAME           | 400  | Template name cannot be empty           |
| INVALID_SUBJECT        | 400  | Template subject cannot be empty        |
| INVALID_HTML_BODY      | 400  | Template HTML body cannot be empty      |
| TEMPLATE_NOT_FOUND     | 404  | Template not found                      |
| TEMPLATE_UPDATE_FAILED | 404  | Template not found or cannot be updated |
| TEMPLATES_LIST_FAILED  | 500  | Failed to list email templates          |
| TEMPLATE_SAVE_FAILED   | 500  | Failed to create/update email template  |
| TEMPLATE_UPDATE_ERROR  | 500  | Failed to update email template         |
| TEMPLATE_DELETE_FAILED | 500  | Failed to delete email template         |

---

## Authentication & Authorization

**Required Permissions:**

- `view_email_config`: For GET requests
- `manage_email_config`: For POST/PUT/DELETE requests

**Headers:**

```
Authorization: Bearer <jwt_token>
```

---

## Rate Limiting

- **Read Operations:** Admin read-only limiter
- **Write Operations:** Admin write limiter

---

## Template Variables

Variables use `{{variableName}}` syntax:

```html
<html>
  <body>
    <h1>Hello {{firstName}}</h1>
    <p>Your password reset link: {{resetLink}}</p>
    <p>This link expires in {{expiresIn}} hours</p>
  </body>
</html>
```

**Variable Rendering:**

- Variables are replaced at send time
- Missing variables remain as `{{variableName}}`
- Case-sensitive matching

---

## Examples

### Create Password Reset Template

```bash
curl -X POST http://localhost:3000/api/admin/email/templates \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "password_reset",
    "subject": "Reset Your Password",
    "html_body": "<html><body><a href=\"{{resetLink}}\">Reset Password</a></body></html>",
    "description": "Password reset email",
    "variables": ["resetLink", "expiresIn"]
  }'
```

### List All Templates

```bash
curl -X GET "http://localhost:3000/api/admin/email/templates?limit=10&offset=0" \
  -H "Authorization: Bearer <token>"
```

### Update Template

```bash
curl -X PUT http://localhost:3000/api/admin/email/templates/<template-id> \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "Updated Subject"
  }'
```

### Delete Template

```bash
curl -X DELETE http://localhost:3000/api/admin/email/templates/<template-id> \
  -H "Authorization: Bearer <token>"
```

---

## Audit Logging

All template operations are logged with:

- Admin user ID and role
- Action type (CREATE, UPDATE, DELETE)
- Template name and ID
- Timestamp
- IP address and user agent

Access audit logs via the audit logging API.
