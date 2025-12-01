# Admin Center API Documentation

## Overview

The Admin Center API provides secure administrative endpoints for managing CloudToLocalLLM users, subscriptions, payments, and system operations. All endpoints require admin authentication with role-based permissions.

## Base URL

```
Production: https://api.cloudtolocalllm.online/api/admin
Development: http://localhost:3001/api/admin
```

## Authentication

All admin endpoints require a valid JWT token with admin privileges.

### Headers

```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

### Admin Roles

- **Super Admin**: Full access to all admin operations
- **Support Admin**: User management, sessions, view payments and audit logs
- **Finance Admin**: Payments, refunds, subscriptions, reports, view users and audit logs

## User Management Endpoints

### List Users

Retrieve a paginated list of users with search and filtering capabilities.

**Endpoint:** `GET /api/admin/users`

**Permissions Required:** `view_users`

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number (min: 1) |
| limit | integer | 50 | Items per page (min: 1, max: 100) |
| search | string | - | Search by email, username, user ID, or Supabase Auth ID |
| tier | string | - | Filter by subscription tier (free, premium, enterprise) |
| status | string | - | Filter by account status (active, suspended, deleted) |
| startDate | string | - | Filter by registration date (ISO 8601 format) |
| endDate | string | - | Filter by registration date (ISO 8601 format) |
| sortBy | string | created_at | Sort field (created_at, last_login, email, username) |
| sortOrder | string | desc | Sort order (asc, desc) |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/users?page=1&limit=50&tier=premium&status=active" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "email": "user@example.com",
        "username": "johndoe",
        "supabase-auth_id": "supabase-auth|123456789",
        "created_at": "2025-01-15T10:30:00Z",
        "last_login": "2025-01-20T14:22:00Z",
        "is_suspended": false,
        "suspended_at": null,
        "suspension_reason": null,
        "deleted_at": null,
        "subscription_tier": "premium",
        "subscription_status": "active",
        "subscription_end_date": "2025-02-15T10:30:00Z",
        "active_sessions": 2
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalUsers": 150,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "filters": {
      "search": "",
      "tier": "premium",
      "status": "active",
      "startDate": null,
      "endDate": null,
      "sortBy": "created_at",
      "sortOrder": "DESC"
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `500 Internal Server Error`: Server error

---

### Get User Details

Retrieve detailed information about a specific user.

**Endpoint:** `GET /api/admin/users/:userId`

**Permissions Required:** `view_users`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| userId | UUID | User ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "user@example.com",
      "username": "johndoe",
      "supabase-auth_id": "supabase-auth|123456789",
      "created_at": "2025-01-15T10:30:00Z",
      "last_login": "2025-01-20T14:22:00Z",
      "is_suspended": false,
      "suspended_at": null,
      "suspension_reason": null,
      "deleted_at": null,
      "metadata": {}
    },
    "subscription": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "stripe_subscription_id": "sub_1234567890",
      "stripe_customer_id": "cus_1234567890",
      "tier": "premium",
      "status": "active",
      "current_period_start": "2025-01-15T10:30:00Z",
      "current_period_end": "2025-02-15T10:30:00Z",
      "cancel_at_period_end": false,
      "canceled_at": null,
      "trial_start": null,
      "trial_end": null,
      "created_at": "2025-01-15T10:30:00Z",
      "updated_at": "2025-01-15T10:30:00Z",
      "metadata": {}
    },
    "paymentHistory": [
      {
        "id": "770e8400-e29b-41d4-a716-446655440002",
        "subscription_id": "660e8400-e29b-41d4-a716-446655440001",
        "stripe_payment_intent_id": "pi_1234567890",
        "stripe_charge_id": "ch_1234567890",
        "amount": 29.99,
        "currency": "USD",
        "status": "succeeded",
        "payment_method_type": "card",
        "payment_method_last4": "4242",
        "failure_code": null,
        "failure_message": null,
        "receipt_url": "https://stripe.com/receipts/...",
        "created_at": "2025-01-15T10:30:00Z",
        "metadata": {}
      }
    ],
    "paymentMethods": [
      {
        "id": "880e8400-e29b-41d4-a716-446655440003",
        "stripe_payment_method_id": "pm_1234567890",
        "type": "card",
        "card_brand": "visa",
        "card_last4": "4242",
        "card_exp_month": 12,
        "card_exp_year": 2025,
        "is_default": true,
        "status": "active",
        "created_at": "2025-01-15T10:30:00Z"
      }
    ],
    "activeSessions": [
      {
        "id": "990e8400-e29b-41d4-a716-446655440004",
        "session_token": "sess_...",
        "created_at": "2025-01-20T14:22:00Z",
        "expires_at": "2025-01-21T14:22:00Z",
        "last_activity": "2025-01-20T15:00:00Z",
        "ip_address": "192.168.1.100",
        "user_agent": "Mozilla/5.0..."
      }
    ],
    "activityTimeline": [
      {
        "id": "aa0e8400-e29b-41d4-a716-446655440005",
        "admin_user_id": "bb0e8400-e29b-41d4-a716-446655440006",
        "admin_role": "super_admin",
        "action": "subscription_upgraded",
        "resource_type": "subscription",
        "resource_id": "660e8400-e29b-41d4-a716-446655440001",
        "details": {
          "previous_tier": "free",
          "new_tier": "premium",
          "reason": "Customer request"
        },
        "ip_address": "192.168.1.200",
        "created_at": "2025-01-15T10:30:00Z"
      }
    ],
    "statistics": {
      "totalPayments": 5,
      "totalSpent": 149.95,
      "activeSessions": 2,
      "accountAge": 30
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid user ID format
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error

---

### Update User Subscription

Update a user's subscription tier with automatic prorated charge calculation.

**Endpoint:** `PATCH /api/admin/users/:userId`

**Permissions Required:** `edit_users`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| userId | UUID | User ID |

**Request Body:**

```json
{
  "subscriptionTier": "premium",
  "reason": "Customer support request"
}
```

**Body Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| subscriptionTier | string | Yes | New subscription tier (free, premium, enterprise) |
| reason | string | No | Reason for the change |

**Example Request:**

```bash
curl -X PATCH "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "subscriptionTier": "premium",
    "reason": "Customer support request"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "message": "User subscription tier updated successfully",
  "data": {
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "previousTier": "free",
    "newTier": "premium",
    "proratedCharge": "29.99",
    "subscriptionId": "660e8400-e29b-41d4-a716-446655440001"
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid user ID or subscription tier
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error

---

### Suspend User Account

Suspend a user account and invalidate all active sessions.

**Endpoint:** `POST /api/admin/users/:userId/suspend`

**Permissions Required:** `suspend_users`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| userId | UUID | User ID |

**Request Body:**

```json
{
  "reason": "Terms of service violation"
}
```

**Body Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| reason | string | Yes | Reason for suspension |

**Example Request:**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000/suspend" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Terms of service violation"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "message": "User account suspended successfully",
  "data": {
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "suspendedAt": "2025-01-20T15:00:00Z",
    "reason": "Terms of service violation",
    "invalidatedSessions": 2
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid user ID, missing reason, or user already suspended
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error

---

### Reactivate User Account

Reactivate a suspended user account.

**Endpoint:** `POST /api/admin/users/:userId/reactivate`

**Permissions Required:** `suspend_users`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| userId | UUID | User ID |

**Request Body:**

```json
{
  "note": "Issue resolved, account reactivated"
}
```

**Body Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| note | string | No | Optional note about reactivation |

**Example Request:**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000/reactivate" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "note": "Issue resolved, account reactivated"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "message": "User account reactivated successfully",
  "data": {
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "reactivatedAt": "2025-01-20T15:00:00Z",
    "previousSuspensionReason": "Terms of service violation"
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid user ID or user not suspended
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error

---

## Subscription Management Endpoints

### List Subscriptions

Retrieve a paginated list of subscriptions with filtering capabilities.

**Endpoint:** `GET /api/admin/subscriptions`

**Permissions Required:** `view_subscriptions`

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number (min: 1) |
| limit | integer | 50 | Items per page (min: 1, max: 200) |
| tier | string | - | Filter by tier (free, premium, enterprise) |
| status | string | - | Filter by status (active, canceled, past_due, trialing, incomplete) |
| userId | UUID | - | Filter by user ID |
| includeUpcoming | boolean | false | Include upcoming renewals (next 7 days) |
| sortBy | string | created_at | Sort field (created_at, current_period_end, tier, status, updated_at) |
| sortOrder | string | desc | Sort order (asc, desc) |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions?page=1&limit=50&tier=premium&includeUpcoming=true" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "subscriptions": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "userId": "660e8400-e29b-41d4-a716-446655440001",
        "stripeSubscriptionId": "sub_1234567890",
        "stripeCustomerId": "cus_1234567890",
        "tier": "premium",
        "status": "active",
        "currentPeriodStart": "2025-01-15T10:30:00Z",
        "currentPeriodEnd": "2025-02-15T10:30:00Z",
        "cancelAtPeriodEnd": false,
        "canceledAt": null,
        "trialStart": null,
        "trialEnd": null,
        "createdAt": "2025-01-15T10:30:00Z",
        "updatedAt": "2025-01-15T10:30:00Z",
        "metadata": {},
        "user": {
          "email": "user@example.com",
          "username": "johndoe",
          "status": "active"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalCount": 150,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "upcomingRenewals": [
      {
        "id": "770e8400-e29b-41d4-a716-446655440002",
        "userId": "880e8400-e29b-41d4-a716-446655440003",
        "tier": "enterprise",
        "currentPeriodEnd": "2025-01-22T10:30:00Z",
        "userEmail": "enterprise@example.com"
      }
    ]
  }
}
```

**Error Responses:**

- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `500 Internal Server Error`: Server error

---

### Get Subscription Details

Retrieve detailed information about a specific subscription.

**Endpoint:** `GET /api/admin/subscriptions/:subscriptionId`

**Permissions Required:** `view_subscriptions`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| subscriptionId | UUID | Subscription ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "660e8400-e29b-41d4-a716-446655440001",
    "stripeSubscriptionId": "sub_1234567890",
    "stripeCustomerId": "cus_1234567890",
    "tier": "premium",
    "status": "active",
    "currentPeriodStart": "2025-01-15T10:30:00Z",
    "currentPeriodEnd": "2025-02-15T10:30:00Z",
    "cancelAtPeriodEnd": false,
    "canceledAt": null,
    "trialStart": null,
    "trialEnd": null,
    "createdAt": "2025-01-15T10:30:00Z",
    "updatedAt": "2025-01-15T10:30:00Z",
    "metadata": {},
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "user@example.com",
      "username": "johndoe",
      "status": "active",
      "createdAt": "2025-01-01T00:00:00Z",
      "lastLogin": "2025-01-20T14:22:00Z"
    },
    "billingCycle": {
      "currentPeriodStart": "2025-01-15T10:30:00Z",
      "currentPeriodEnd": "2025-02-15T10:30:00Z",
      "daysRemaining": 25,
      "daysInCycle": 31,
      "nextBillingDate": "2025-02-15T10:30:00Z",
      "willRenew": true
    },
    "paymentHistory": [
      {
        "id": "990e8400-e29b-41d4-a716-446655440004",
        "amount": 29.99,
        "currency": "USD",
        "status": "succeeded",
        "paymentMethodType": "card",
        "paymentMethodLast4": "4242",
        "receiptUrl": "https://stripe.com/receipts/...",
        "createdAt": "2025-01-15T10:30:00Z",
        "metadata": {}
      }
    ],
    "paymentStats": {
      "totalTransactions": 5,
      "successfulTransactions": 5,
      "failedTransactions": 0,
      "totalAmountPaid": 149.95,
      "currency": "USD"
    }
  }
}
```

**Error Responses:**

- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Subscription not found
- `500 Internal Server Error`: Server error

---

### Update Subscription

Update a subscription tier (upgrade or downgrade).

**Endpoint:** `PATCH /api/admin/subscriptions/:subscriptionId`

**Permissions Required:** `edit_subscriptions`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| subscriptionId | UUID | Subscription ID |

**Request Body:**

```json
{
  "tier": "enterprise",
  "priceId": "price_1234567890",
  "prorationBehavior": "create_prorations"
}
```

**Body Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| tier | string | Yes | New subscription tier (free, premium, enterprise) |
| priceId | string | Yes | Stripe price ID for the new tier |
| prorationBehavior | string | No | Proration behavior (create_prorations, none, always_invoice) (default: create_prorations) |

**Example Request:**

```bash
curl -X PATCH "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "tier": "enterprise",
    "priceId": "price_1234567890",
    "prorationBehavior": "create_prorations"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "tier": "enterprise",
      "status": "active",
      "currentPeriodStart": "2025-01-15T10:30:00Z",
      "currentPeriodEnd": "2025-02-15T10:30:00Z",
      "updatedAt": "2025-01-20T15:00:00Z"
    },
    "prorationDetails": {
      "proratedAmount": 70.00,
      "currency": "usd",
      "nextInvoiceDate": "2025-02-15T10:30:00Z",
      "lineItems": [
        {
          "description": "Remaining time on Premium after 15 Jan 2025",
          "amount": -10.00,
          "period": {
            "start": "2025-01-20T15:00:00Z",
            "end": "2025-02-15T10:30:00Z"
          }
        },
        {
          "description": "Remaining time on Enterprise after 20 Jan 2025",
          "amount": 80.00,
          "period": {
            "start": "2025-01-20T15:00:00Z",
            "end": "2025-02-15T10:30:00Z"
          }
        }
      ]
    },
    "message": "Subscription upgraded from premium to enterprise"
  }
}
```

**Error Responses:**

- `400 Bad Request`: Invalid request (missing fields, invalid tier, subscription not active)
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Subscription not found
- `500 Internal Server Error`: Server error

---

### Cancel Subscription

Cancel a subscription immediately or at the end of the billing period.

**Endpoint:** `POST /api/admin/subscriptions/:subscriptionId/cancel`

**Permissions Required:** `edit_subscriptions`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| subscriptionId | UUID | Subscription ID |

**Request Body:**

```json
{
  "immediate": false,
  "reason": "Customer requested cancellation"
}
```

**Body Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| immediate | boolean | No | Cancel immediately (true) or at period end (false) (default: false) |
| reason | string | Yes | Reason for cancellation |

**Example Request:**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000/cancel" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "immediate": false,
    "reason": "Customer requested cancellation"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "active",
      "cancelAtPeriodEnd": true,
      "canceledAt": "2025-01-20T15:00:00Z",
      "currentPeriodEnd": "2025-02-15T10:30:00Z"
    },
    "cancellationType": "end_of_period",
    "effectiveDate": "2025-02-15T10:30:00Z",
    "refundInfo": null,
    "message": "Subscription will be canceled at the end of the current billing period (2025-02-15). User will retain access until then."
  }
}
```

**Example Response (Immediate Cancellation):**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "canceled",
      "cancelAtPeriodEnd": false,
      "canceledAt": "2025-01-20T15:00:00Z"
    },
    "cancellationType": "immediate",
    "effectiveDate": "2025-01-20T15:00:00Z",
    "refundInfo": {
      "eligibleForRefund": true,
      "proratedAmount": 19.35,
      "currency": "USD",
      "daysRemaining": 25,
      "totalDays": 31,
      "note": "Refund must be processed separately through the refunds endpoint"
    },
    "message": "Subscription canceled immediately. User access has been revoked."
  }
}
```

**Error Responses:**

- `400 Bad Request`: Invalid request (missing reason, subscription already canceled, etc.)
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Subscription not found
- `500 Internal Server Error`: Server error

---

## Error Handling

All endpoints follow a consistent error response format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional error details"
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| NO_TOKEN | 401 | No JWT token provided |
| INVALID_TOKEN | 401 | Invalid or expired JWT token |
| USER_NOT_FOUND | 403 | User not found in database |
| ADMIN_ACCESS_REQUIRED | 403 | User does not have admin role |
| INSUFFICIENT_PERMISSIONS | 403 | User lacks required permissions |
| INVALID_USER_ID | 400 | Invalid user ID format |
| INVALID_TIER | 400 | Invalid subscription tier |
| TIER_UNCHANGED | 400 | User already has this tier |
| REASON_REQUIRED | 400 | Suspension reason is required |
| ALREADY_SUSPENDED | 400 | User is already suspended |
| NOT_SUSPENDED | 400 | User is not suspended |
| USERS_LIST_FAILED | 500 | Failed to retrieve users list |
| USER_DETAILS_FAILED | 500 | Failed to retrieve user details |
| USER_UPDATE_FAILED | 500 | Failed to update user |
| USER_SUSPEND_FAILED | 500 | Failed to suspend user |
| USER_REACTIVATE_FAILED | 500 | Failed to reactivate user |
| SUBSCRIPTION_LIST_FAILED | 500 | Failed to retrieve subscriptions list |
| SUBSCRIPTION_NOT_FOUND | 404 | Subscription not found |
| SUBSCRIPTION_DETAILS_FAILED | 500 | Failed to retrieve subscription details |
| INVALID_TIER | 400 | Invalid subscription tier |
| SUBSCRIPTION_NOT_ACTIVE | 400 | Subscription is not active or trialing |
| SUBSCRIPTION_UPDATE_FAILED | 500 | Failed to update subscription |
| SUBSCRIPTION_ALREADY_CANCELED | 400 | Subscription is already canceled |
| SUBSCRIPTION_ALREADY_CANCELING | 400 | Subscription is already set to cancel at period end |
| SUBSCRIPTION_CANCEL_FAILED | 500 | Failed to cancel subscription |

---

## Rate Limiting

Admin API endpoints are rate-limited to prevent abuse:

- **100 requests per minute** per admin user
- **Burst allowance**: 20 requests
- **Response headers** include rate limit information

---

## Audit Logging

All administrative actions are automatically logged to the `admin_audit_logs` table with:

- Admin user ID and role
- Action type and resource details
- Affected user ID
- IP address and user agent
- Timestamp and additional context

---

## Best Practices

1. **Always include reason fields** when suspending users or changing subscriptions
2. **Check user status** before performing operations
3. **Handle errors gracefully** with proper error messages
4. **Log all administrative actions** for compliance
5. **Use pagination** for large result sets
6. **Validate input** before making API calls
7. **Store JWT tokens securely** and refresh before expiration

---

---

## Financial Reporting Endpoints

### Generate Revenue Report

Generate revenue report for a specified date range with optional tier breakdown.

**Endpoint:** `GET /api/admin/reports/revenue`

**Permissions Required:** `view_reports`

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| startDate | string | Yes | Start date in ISO 8601 format (YYYY-MM-DD) |
| endDate | string | Yes | End date in ISO 8601 format (YYYY-MM-DD) |
| groupBy | boolean | No | Group results by subscription tier (default: false) |

**Constraints:**
- Date range cannot exceed 1 year
- startDate must be before or equal to endDate
- Dates must be in ISO 8601 format

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/reports/revenue?startDate=2025-01-01&endDate=2025-01-31&groupBy=true" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "period": {
    "startDate": "2025-01-01T00:00:00.000Z",
    "endDate": "2025-01-31T23:59:59.999Z"
  },
  "totalRevenue": 15420.50,
  "transactionCount": 342,
  "averageTransactionValue": 45.09,
  "revenueByTier": [
    {
      "tier": "premium",
      "transactionCount": 200,
      "totalRevenue": 10000.00,
      "averageTransactionValue": 50.00
    },
    {
      "tier": "enterprise",
      "transactionCount": 100,
      "totalRevenue": 5000.00,
      "averageTransactionValue": 50.00
    }
  ]
}
```

**Error Responses:**

- `400 Bad Request`: Missing or invalid parameters
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Insufficient permissions
- `500 Internal Server Error`: Server error

---

## Support

For API support or questions:
- Documentation: `/docs/API/`
- Issues: GitHub Issues
- Email: support@cloudtolocalllm.online


---

## Webhook Endpoints

### Stripe Webhook Handler

Process Stripe webhook events for payment and subscription updates.

**Endpoint:** `POST /api/webhooks/stripe`

**Authentication:** Webhook signature verification (no JWT required)

**Headers:**
- `stripe-signature` (required) - Stripe webhook signature
- `Content-Type: application/json`

**Supported Events:**
- `payment_intent.succeeded` - Payment completed successfully
- `payment_intent.failed` - Payment failed
- `customer.subscription.created` - New subscription created
- `customer.subscription.updated` - Subscription modified
- `customer.subscription.deleted` - Subscription canceled

**Request Body:**
Raw JSON webhook event from Stripe

**Success Response (200 OK):**
```json
{
  "received": true,
  "status": "processed"
}
```

**Idempotent Response (200 OK):**
```json
{
  "received": true,
  "status": "already_processed"
}
```

**Error Responses:**

**400 Bad Request** - Invalid signature
```json
{
  "error": "Webhook signature verification failed"
}
```

**500 Internal Server Error** - Processing error
```json
{
  "error": "Error processing webhook"
}
```

**Features:**
- Automatic signature verification
- Idempotency to prevent duplicate processing
- Database synchronization for payments and subscriptions
- Comprehensive logging and error handling

**Configuration:**
- Webhook secret: `STRIPE_WEBHOOK_SECRET` environment variable
- Configure in Stripe Dashboard: Developers > Webhooks

**Documentation:**
- [Webhook API Documentation](../../services/api-backend/routes/WEBHOOK_API.md)
- [Webhook Implementation Summary](../../services/api-backend/routes/WEBHOOK_IMPLEMENTATION_SUMMARY.md)
- [Webhook Quick Reference](../../services/api-backend/routes/WEBHOOK_QUICK_REFERENCE.md)

---
