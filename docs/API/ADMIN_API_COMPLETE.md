# Admin Center API Documentation - Complete Reference

## Overview

The Admin Center API provides secure administrative endpoints for managing CloudToLocalLLM users, subscriptions, payments, and system operations. All endpoints require admin authentication with role-based permissions.

**Version:** 1.0.0  
**Last Updated:** November 2025

## Base URL

```
Production: https://api.cloudtolocalllm.online/api/admin
Staging: https://staging-api.cloudtolocalllm.online/api/admin
Development: http://localhost:3001/api/admin
```

## Authentication

All admin endpoints require a valid JWT token with admin privileges.

### Headers

```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

### Admin Roles and Permissions

The Admin Center implements role-based access control (RBAC) with three distinct roles:

#### Super Admin
**Full access to all admin operations**

Permissions:
- All user management operations (view, edit, suspend, delete)
- All payment operations (view, process refunds)
- All subscription operations (view, edit, cancel)
- All reporting operations (view, export)
- Admin management (create, edit, delete admins)
- Configuration management
- Audit log access (view, export)

#### Support Admin
**User support and account management**

Permissions:
- View users
- Edit users (subscription changes)
- Suspend/reactivate users
- View sessions
- Terminate sessions
- View payments (read-only)
- View audit logs (read-only)

#### Finance Admin
**Financial operations and reporting**

Permissions:
- View users (read-only)
- View payments
- Process refunds
- View subscriptions
- Edit subscriptions
- View reports
- Export reports
- View audit logs (read-only)

### Authentication Flow

1. User logs in to main application via Supabase Auth
2. JWT token issued with user claims
3. Admin role verified from `admin_roles` table
4. Token passed to Admin Center via session inheritance
5. Each API request validates token and checks permissions

### Token Format

```json
{
  "sub": "supabase-auth|123456789",
  "email": "admin@cloudtolocalllm.online",
  "iat": 1705843200,
  "exp": 1705929600
}
```

## Rate Limiting

Admin API endpoints implement rate limiting to prevent abuse and ensure system stability.

### Rate Limit Configuration

| Endpoint Type | Requests/Minute | Burst Allowance | Window |
|---------------|-----------------|-----------------|--------|
| Standard Operations | 100 | 20 | 60 seconds |
| Expensive Operations | 20 | 5 | 60 seconds |
| Report Generation | 10 | 2 | 60 seconds |
| Export Operations | 5 | 1 | 60 seconds |

### Expensive Operations

The following endpoints have stricter rate limits:
- `GET /api/admin/reports/*` - Report generation
- `GET /api/admin/audit/export` - Audit log export
- `GET /api/admin/reports/export` - Report export
- `POST /api/admin/payments/refunds` - Refund processing

### Rate Limit Headers

All responses include rate limit information:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705843260
X-RateLimit-Window: 60
```

### Rate Limit Exceeded Response

**Status Code:** `429 Too Many Requests`

```json
{
  "error": "Rate limit exceeded",
  "code": "RATE_LIMIT_EXCEEDED",
  "details": {
    "limit": 100,
    "window": 60,
    "retryAfter": 45
  },
  "retryAfter": 45
}
```

### Best Practices

1. **Monitor rate limit headers** to avoid hitting limits
2. **Implement exponential backoff** for retries
3. **Cache responses** when appropriate
4. **Batch operations** to reduce API calls
5. **Use pagination** for large result sets



## Payment Management Endpoints

### List Payment Transactions

Retrieve a paginated list of payment transactions with filtering and sorting.

**Endpoint:** `GET /api/admin/payments/transactions`

**Permissions Required:** `view_payments`

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number (min: 1) |
| limit | integer | 100 | Items per page (min: 1, max: 200) |
| startDate | string | - | Filter by date (ISO 8601 format) |
| endDate | string | - | Filter by date (ISO 8601 format) |
| status | string | - | Filter by status (pending, succeeded, failed, refunded, partially_refunded, disputed) |
| userId | UUID | - | Filter by user ID |
| minAmount | number | - | Minimum transaction amount |
| maxAmount | number | - | Maximum transaction amount |
| sortBy | string | created_at | Sort field (created_at, amount, status) |
| sortOrder | string | desc | Sort order (asc, desc) |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/payments/transactions?page=1&limit=100&status=succeeded&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "transactions": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "userId": "660e8400-e29b-41d4-a716-446655440001",
        "subscriptionId": "770e8400-e29b-41d4-a716-446655440002",
        "stripePaymentIntentId": "pi_1234567890",
        "stripeChargeId": "ch_1234567890",
        "amount": 29.99,
        "currency": "USD",
        "status": "succeeded",
        "paymentMethodType": "card",
        "paymentMethodLast4": "4242",
        "failureCode": null,
        "failureMessage": null,
        "receiptUrl": "https://stripe.com/receipts/...",
        "createdAt": "2025-01-15T10:30:00Z",
        "updatedAt": "2025-01-15T10:30:00Z",
        "metadata": {},
        "user": {
          "email": "user@example.com",
          "username": "johndoe"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 100,
      "totalCount": 342,
      "totalPages": 4,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "summary": {
      "totalRevenue": 10258.58,
      "successfulTransactions": 320,
      "failedTransactions": 22,
      "averageTransactionValue": 30.00
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid parameters
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `500 Internal Server Error`: Server error

---

### Get Transaction Details

Retrieve detailed information about a specific payment transaction.

**Endpoint:** `GET /api/admin/payments/transactions/:transactionId`

**Permissions Required:** `view_payments`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| transactionId | UUID | Transaction ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/payments/transactions/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "transaction": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "userId": "660e8400-e29b-41d4-a716-446655440001",
      "subscriptionId": "770e8400-e29b-41d4-a716-446655440002",
      "stripePaymentIntentId": "pi_1234567890",
      "stripeChargeId": "ch_1234567890",
      "amount": 29.99,
      "currency": "USD",
      "status": "succeeded",
      "paymentMethodType": "card",
      "paymentMethodLast4": "4242",
      "failureCode": null,
      "failureMessage": null,
      "receiptUrl": "https://stripe.com/receipts/...",
      "createdAt": "2025-01-15T10:30:00Z",
      "updatedAt": "2025-01-15T10:30:00Z",
      "metadata": {
        "subscription_tier": "premium",
        "billing_cycle": "monthly"
      }
    },
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "user@example.com",
      "username": "johndoe",
      "status": "active"
    },
    "paymentMethod": {
      "type": "card",
      "brand": "visa",
      "last4": "4242",
      "expMonth": 12,
      "expYear": 2025,
      "billingEmail": "user@example.com"
    },
    "refunds": [
      {
        "id": "880e8400-e29b-41d4-a716-446655440003",
        "amount": 10.00,
        "currency": "USD",
        "reason": "customer_request",
        "status": "succeeded",
        "createdAt": "2025-01-16T10:00:00Z",
        "adminUser": {
          "email": "admin@cloudtolocalllm.online",
          "role": "super_admin"
        }
      }
    ],
    "subscription": {
      "id": "770e8400-e29b-41d4-a716-446655440002",
      "tier": "premium",
      "status": "active",
      "currentPeriodEnd": "2025-02-15T10:30:00Z"
    },
    "refundSummary": {
      "totalRefunded": 10.00,
      "refundableAmount": 19.99,
      "netAmount": 19.99
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid transaction ID
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Transaction not found
- `500 Internal Server Error`: Server error

---

### Process Refund

Process a full or partial refund for a payment transaction.

**Endpoint:** `POST /api/admin/payments/refunds`

**Permissions Required:** `process_refunds`

**Request Body:**

```json
{
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 29.99,
  "reason": "customer_request",
  "reasonDetails": "Customer requested refund due to service issue"
}
```

**Body Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| transactionId | UUID | Yes | Transaction ID to refund |
| amount | number | Yes | Refund amount (must be ≤ refundable amount) |
| reason | string | Yes | Refund reason (customer_request, billing_error, service_issue, duplicate, fraudulent, other) |
| reasonDetails | string | No | Additional details about the refund |

**Valid Refund Reasons:**
- `customer_request` - Customer requested refund
- `billing_error` - Billing error or duplicate charge
- `service_issue` - Service quality or availability issue
- `duplicate` - Duplicate transaction
- `fraudulent` - Fraudulent transaction
- `other` - Other reason (requires reasonDetails)

**Example Request:**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/payments/refunds" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId": "550e8400-e29b-41d4-a716-446655440000",
    "amount": 29.99,
    "reason": "customer_request",
    "reasonDetails": "Customer requested refund due to service issue"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "message": "Refund processed successfully",
  "data": {
    "refund": {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "transactionId": "550e8400-e29b-41d4-a716-446655440000",
      "stripeRefundId": "re_1234567890",
      "amount": 29.99,
      "currency": "USD",
      "reason": "customer_request",
      "reasonDetails": "Customer requested refund due to service issue",
      "status": "succeeded",
      "adminUserId": "990e8400-e29b-41d4-a716-446655440004",
      "createdAt": "2025-01-20T15:00:00Z"
    },
    "transaction": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "refunded",
      "originalAmount": 29.99,
      "refundedAmount": 29.99,
      "netAmount": 0.00
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid request (missing fields, invalid amount, exceeds refundable amount)
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Transaction not found
- `500 Internal Server Error`: Server error or Stripe API error

---

### Get User Payment Methods

Retrieve payment methods associated with a user account.

**Endpoint:** `GET /api/admin/payments/methods/:userId`

**Permissions Required:** `view_payments`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| userId | UUID | User ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/payments/methods/660e8400-e29b-41d4-a716-446655440001" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "paymentMethods": [
      {
        "id": "aa0e8400-e29b-41d4-a716-446655440005",
        "stripePaymentMethodId": "pm_1234567890",
        "type": "card",
        "cardBrand": "visa",
        "cardLast4": "4242",
        "cardExpMonth": 12,
        "cardExpYear": 2025,
        "billingEmail": "u***@example.com",
        "isDefault": true,
        "status": "active",
        "createdAt": "2025-01-15T10:30:00Z",
        "usage": {
          "transactionCount": 5,
          "totalSpent": 149.95,
          "lastUsed": "2025-01-20T10:00:00Z"
        }
      }
    ],
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "user@example.com",
      "status": "active"
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Security Notes:**
- Billing email is masked (only first character and domain shown)
- Only last 4 digits of card number are shown
- No CVV or full card numbers are ever stored or returned
- PCI DSS compliant data handling

**Error Responses:**

- `400 Bad Request`: Invalid user ID
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error



## Dashboard Metrics Endpoint

### Get Dashboard Metrics

Retrieve key metrics and statistics for the Admin Center dashboard.

**Endpoint:** `GET /api/admin/dashboard/metrics`

**Permissions Required:** Admin authentication (any role)

**Query Parameters:** None

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/dashboard/metrics" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "users": {
      "total": 15420,
      "active": 12350,
      "activePercentage": 80.09,
      "newThisMonth": 450,
      "suspended": 120,
      "deleted": 50
    },
    "subscriptions": {
      "byTier": {
        "free": {
          "count": 10000,
          "percentage": 64.85
        },
        "premium": {
          "count": 4500,
          "percentage": 29.18
        },
        "enterprise": {
          "count": 920,
          "percentage": 5.97
        }
      },
      "total": 15420,
      "active": 5420,
      "canceled": 200,
      "pastDue": 50
    },
    "revenue": {
      "monthlyRecurringRevenue": 185000.00,
      "totalThisMonth": 195420.50,
      "previousMonth": 178350.25,
      "growthPercentage": 9.57,
      "currency": "USD"
    },
    "recentTransactions": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "userId": "660e8400-e29b-41d4-a716-446655440001",
        "amount": 29.99,
        "currency": "USD",
        "status": "succeeded",
        "paymentMethodType": "card",
        "paymentMethodLast4": "4242",
        "createdAt": "2025-01-20T14:55:00Z",
        "user": {
          "email": "user@example.com",
          "username": "johndoe"
        }
      }
    ],
    "systemHealth": {
      "apiResponseTime": 125,
      "errorRate": 0.5,
      "activeConnections": 1250,
      "databaseConnections": 45
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Metrics Explanation:**

- **users.total**: Total registered users
- **users.active**: Users with activity in last 30 days
- **users.newThisMonth**: New registrations in current month
- **subscriptions.byTier**: Distribution of users by subscription tier
- **revenue.monthlyRecurringRevenue**: MRR from active subscriptions
- **revenue.totalThisMonth**: Total revenue in current month
- **revenue.growthPercentage**: Month-over-month growth rate
- **recentTransactions**: Last 10 payment transactions
- **systemHealth**: Real-time system performance metrics

**Error Responses:**

- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Admin access required
- `500 Internal Server Error`: Server error

---

## Audit Log Endpoints

### List Audit Logs

Retrieve a paginated list of admin audit logs with filtering.

**Endpoint:** `GET /api/admin/audit/logs`

**Permissions Required:** `view_audit_logs`

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number (min: 1) |
| limit | integer | 50 | Items per page (min: 1, max: 200) |
| startDate | string | - | Filter by date (ISO 8601 format) |
| endDate | string | - | Filter by date (ISO 8601 format) |
| adminUserId | UUID | - | Filter by admin user ID |
| action | string | - | Filter by action type |
| resourceType | string | - | Filter by resource type (user, subscription, transaction, admin) |
| affectedUserId | UUID | - | Filter by affected user ID |
| sortBy | string | created_at | Sort field (created_at) |
| sortOrder | string | desc | Sort order (asc, desc) |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?page=1&limit=50&action=user_suspended&startDate=2025-01-01" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "adminUserId": "660e8400-e29b-41d4-a716-446655440001",
        "adminRole": "super_admin",
        "action": "user_suspended",
        "resourceType": "user",
        "resourceId": "770e8400-e29b-41d4-a716-446655440002",
        "affectedUserId": "770e8400-e29b-41d4-a716-446655440002",
        "details": {
          "reason": "Terms of service violation",
          "previousStatus": "active",
          "newStatus": "suspended"
        },
        "ipAddress": "192.168.1.100",
        "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)...",
        "createdAt": "2025-01-20T14:30:00Z",
        "adminUser": {
          "email": "admin@cloudtolocalllm.online",
          "username": "admin"
        },
        "affectedUser": {
          "email": "user@example.com",
          "username": "johndoe"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalCount": 1250,
      "totalPages": 25,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "filters": {
      "startDate": "2025-01-01T00:00:00.000Z",
      "endDate": null,
      "adminUserId": null,
      "action": "user_suspended",
      "resourceType": null,
      "affectedUserId": null
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Common Action Types:**
- `user_created` - New user registered
- `user_updated` - User profile updated
- `user_suspended` - User account suspended
- `user_reactivated` - User account reactivated
- `user_deleted` - User account deleted
- `subscription_created` - Subscription created
- `subscription_upgraded` - Subscription tier upgraded
- `subscription_downgraded` - Subscription tier downgraded
- `subscription_canceled` - Subscription canceled
- `payment_processed` - Payment processed
- `refund_processed` - Refund issued
- `admin_role_granted` - Admin role assigned
- `admin_role_revoked` - Admin role removed
- `configuration_changed` - System configuration modified

**Error Responses:**

- `400 Bad Request`: Invalid parameters
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `500 Internal Server Error`: Server error

---

### Get Audit Log Details

Retrieve detailed information about a specific audit log entry.

**Endpoint:** `GET /api/admin/audit/logs/:logId`

**Permissions Required:** `view_audit_logs`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| logId | UUID | Audit log ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "adminUserId": "660e8400-e29b-41d4-a716-446655440001",
    "adminRole": "super_admin",
    "action": "user_suspended",
    "resourceType": "user",
    "resourceId": "770e8400-e29b-41d4-a716-446655440002",
    "affectedUserId": "770e8400-e29b-41d4-a716-446655440002",
    "details": {
      "reason": "Terms of service violation",
      "previousStatus": "active",
      "newStatus": "suspended",
      "suspensionDuration": null,
      "notificationSent": true
    },
    "ipAddress": "192.168.1.100",
    "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "createdAt": "2025-01-20T14:30:00Z",
    "adminUser": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "admin@cloudtolocalllm.online",
      "username": "admin",
      "role": "super_admin"
    },
    "affectedUser": {
      "id": "770e8400-e29b-41d4-a716-446655440002",
      "email": "user@example.com",
      "username": "johndoe",
      "status": "suspended"
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid log ID
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Audit log not found
- `500 Internal Server Error`: Server error

---

### Export Audit Logs

Export audit logs to CSV format for compliance and reporting.

**Endpoint:** `GET /api/admin/audit/export`

**Permissions Required:** `export_audit_logs`

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| startDate | string | Yes | Start date (ISO 8601 format) |
| endDate | string | Yes | End date (ISO 8601 format) |
| adminUserId | UUID | No | Filter by admin user ID |
| action | string | No | Filter by action type |
| resourceType | string | No | Filter by resource type |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/export?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>" \
  --output audit_logs_2025-01.csv
```

**Response:**

- **Content-Type:** `text/csv`
- **Content-Disposition:** `attachment; filename="audit_logs_YYYY-MM-DD_to_YYYY-MM-DD.csv"`

**CSV Format:**

```csv
ID,Admin User ID,Admin Email,Admin Role,Action,Resource Type,Resource ID,Affected User ID,Affected User Email,Details,IP Address,User Agent,Created At
550e8400-e29b-41d4-a716-446655440000,660e8400-e29b-41d4-a716-446655440001,admin@cloudtolocalllm.online,super_admin,user_suspended,user,770e8400-e29b-41d4-a716-446655440002,770e8400-e29b-41d4-a716-446655440002,user@example.com,"{""reason"":""Terms of service violation""}",192.168.1.100,"Mozilla/5.0...",2025-01-20T14:30:00Z
```

**Error Responses:**

- `400 Bad Request`: Missing or invalid parameters
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `500 Internal Server Error`: Server error

---

## Admin Management Endpoints

### List Administrators

Retrieve a list of all administrators with their roles and activity.

**Endpoint:** `GET /api/admin/admins`

**Permissions Required:** Super Admin only

**Query Parameters:** None

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/admins" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "admins": [
      {
        "userId": "550e8400-e29b-41d4-a716-446655440000",
        "email": "admin@cloudtolocalllm.online",
        "username": "admin",
        "roles": [
          {
            "id": "660e8400-e29b-41d4-a716-446655440001",
            "role": "super_admin",
            "grantedBy": null,
            "grantedAt": "2025-01-01T00:00:00Z",
            "isActive": true
          }
        ],
        "activitySummary": {
          "totalActions": 1250,
          "lastAction": "2025-01-20T14:30:00Z",
          "lastActionType": "user_suspended"
        },
        "createdAt": "2025-01-01T00:00:00Z"
      },
      {
        "userId": "770e8400-e29b-41d4-a716-446655440002",
        "email": "support@cloudtolocalllm.online",
        "username": "support",
        "roles": [
          {
            "id": "880e8400-e29b-41d4-a716-446655440003",
            "role": "support_admin",
            "grantedBy": "550e8400-e29b-41d4-a716-446655440000",
            "grantedAt": "2025-01-15T10:00:00Z",
            "isActive": true
          }
        ],
        "activitySummary": {
          "totalActions": 450,
          "lastAction": "2025-01-20T12:00:00Z",
          "lastActionType": "user_reactivated"
        },
        "createdAt": "2025-01-10T00:00:00Z"
      }
    ],
    "summary": {
      "totalAdmins": 5,
      "superAdmins": 1,
      "supportAdmins": 2,
      "financeAdmins": 2
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Super Admin access required
- `500 Internal Server Error`: Server error

---

### Assign Admin Role

Assign an admin role to a user.

**Endpoint:** `POST /api/admin/admins`

**Permissions Required:** Super Admin only

**Request Body:**

```json
{
  "email": "newadmin@cloudtolocalllm.online",
  "role": "support_admin"
}
```

**Body Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| email | string | Yes | User email address |
| role | string | Yes | Admin role (support_admin, finance_admin) |

**Valid Roles:**
- `support_admin` - Support Admin role
- `finance_admin` - Finance Admin role

**Note:** Super Admin role can only be assigned manually in the database for security reasons.

**Example Request:**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/admins" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newadmin@cloudtolocalllm.online",
    "role": "support_admin"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "message": "Admin role assigned successfully",
  "data": {
    "userId": "990e8400-e29b-41d4-a716-446655440004",
    "email": "newadmin@cloudtolocalllm.online",
    "role": "support_admin",
    "grantedBy": "550e8400-e29b-41d4-a716-446655440000",
    "grantedAt": "2025-01-20T15:00:00Z"
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid email or role, user not found, or user already has role
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Super Admin access required
- `500 Internal Server Error`: Server error

---

### Revoke Admin Role

Revoke an admin role from a user.

**Endpoint:** `DELETE /api/admin/admins/:userId/roles/:role`

**Permissions Required:** Super Admin only

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| userId | UUID | User ID |
| role | string | Admin role to revoke (super_admin, support_admin, finance_admin) |

**Example Request:**

```bash
curl -X DELETE "https://api.cloudtolocalllm.online/api/admin/admins/990e8400-e29b-41d4-a716-446655440004/roles/support_admin" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "message": "Admin role revoked successfully",
  "data": {
    "userId": "990e8400-e29b-41d4-a716-446655440004",
    "email": "newadmin@cloudtolocalllm.online",
    "role": "support_admin",
    "revokedBy": "550e8400-e29b-41d4-a716-446655440000",
    "revokedAt": "2025-01-20T15:00:00Z"
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid user ID or role, user doesn't have role
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Super Admin access required, cannot revoke own Super Admin role
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error

