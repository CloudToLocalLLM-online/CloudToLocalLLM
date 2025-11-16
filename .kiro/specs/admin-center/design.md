# Admin Center Design Document

## Overview

The Admin Center is a secure web-based administrative interface for CloudToLocalLLM that enables authorized administrators to manage users, process payments, monitor system health, and perform administrative operations. The system will be built as a Flutter web application that integrates with the existing PostgreSQL database, Auth0 authentication, and payment gateway services (Stripe/PayPal).

The Admin Center will be accessible only to authorized administrators (initially cmaltais@cloudtolocalllm.online) through a button in the settings pane that opens the admin interface in a new browser tab. The interface will inherit the authentication session from the main application, eliminating the need for separate login.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Main Application                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Settings Pane (Authenticated User)           │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  Admin Center Button (if admin user)           │  │   │
│  │  │  - Visible only for cmaltais@cloudtolocalllm   │  │   │
│  │  │  - Opens new tab with admin interface          │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Opens new tab with session
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Admin Center (New Tab)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Admin Dashboard (Flutter Web App)            │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  - User Management                             │  │   │
│  │  │  - Payment Gateway Integration                 │  │   │
│  │  │  - Subscription Management                     │  │   │
│  │  │  - Transaction Management                      │  │   │
│  │  │  - Refund Processing                           │  │   │
│  │  │  - Financial Reporting                         │  │   │
│  │  │  - Audit Logging                               │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ API Calls
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Backend Services                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Admin API Service (Node.js/Express)          │   │
│  │  - Admin authentication middleware                   │   │
│  │  - User management endpoints                         │   │
│  │  - Payment gateway integration                       │   │
│  │  - Subscription management                           │   │
│  │  - Transaction queries                               │   │
│  │  - Refund processing                                 │   │
│  │  - Audit logging                                     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Database Queries
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                       │
│  - users                                                     │
│  - user_sessions                                             │
│  - subscriptions (new)                                       │
│  - payment_transactions (new)                                │
│  - payment_methods (new)                                     │
│  - refunds (new)                                             │
│  - admin_audit_logs (new)                                    │
│  - audit_logs (existing)                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Payment Processing
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Payment Gateway (Stripe/PayPal)           │
│  - Payment processing                                        │
│  - Subscription billing                                      │
│  - Refund processing                                         │
│  - Webhook notifications                                     │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Frontend (Admin Center UI):**
- Flutter Web (existing framework)
- Provider for state management
- go_router for navigation
- Material Design components
- dio for HTTP requests

**Backend (Admin API):**
- Node.js with Express.js (existing API backend)
- PostgreSQL for data persistence
- Stripe SDK for payment processing
- JWT for authentication
- Winston for logging

**Database:**
- PostgreSQL (existing instance)
- New tables for subscriptions, payments, refunds
- Existing tables: users, user_sessions, audit_logs

**Payment Gateway:**
- Stripe (primary) - for credit card processing
- PayPal (optional) - for PayPal payments



## Components and Interfaces

### Frontend Components

#### 1. Admin Access Component (Settings Pane Integration)

**Location:** `lib/screens/unified_settings_screen.dart` (modification)

**Purpose:** Add admin button to settings pane for authorized users

**Implementation:**
```dart
// In UnifiedSettingsScreen widget
Widget _buildAdminAccessButton() {
  final authService = context.watch<AuthService>();
  final userEmail = authService.currentUser?.email;
  
  // Only show for authorized admin users
  if (userEmail != 'cmaltais@cloudtolocalllm.online') {
    return const SizedBox.shrink();
  }
  
  return ListTile(
    leading: const Icon(Icons.admin_panel_settings),
    title: const Text('Admin Center'),
    subtitle: const Text('Manage users and payments'),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => _openAdminCenter(),
  );
}

void _openAdminCenter() {
  // Open admin center in new tab with session token
  final adminUrl = '/admin-center';
  html.window.open(adminUrl, '_blank');
}
```

#### 2. Admin Center Main Screen

**Location:** `lib/screens/admin/admin_center_screen.dart` (new)

**Purpose:** Main admin dashboard with navigation

**Structure:**
- Sidebar navigation (Dashboard, Users, Payments, Subscriptions, Reports, Audit Logs)
- Main content area with tab-based views
- Header with admin user info and logout
- Real-time metrics and notifications

**Key Features:**
- Responsive layout (desktop-optimized)
- Role-based access control
- Real-time data updates
- Search and filtering capabilities

#### 3. User Management Component

**Location:** `lib/screens/admin/user_management_screen.dart` (new)

**Purpose:** Manage registered users

**Features:**
- User search and filtering
- User profile viewing
- Subscription tier management
- Account suspension/reactivation
- User activity timeline
- Session management

**UI Elements:**
- Search bar with filters (tier, status, date range)
- Paginated user table
- User detail modal/drawer
- Action buttons (edit, suspend, view sessions)

#### 4. Payment Gateway Integration Component

**Location:** `lib/services/payment_gateway_service.dart` (new)

**Purpose:** Interface with Stripe/PayPal APIs

**Methods:**
```dart
class PaymentGatewayService extends ChangeNotifier {
  final AuthService _authService;
  final Dio _dio;
  
  // Payment processing
  Future<PaymentResult> processPayment({
    required String userId,
    required double amount,
    required String currency,
    required String paymentMethodId,
  });
  
  // Subscription management
  Future<Subscription> createSubscription({
    required String userId,
    required String priceId,
    required String paymentMethodId,
  });
  
  Future<void> cancelSubscription(String subscriptionId);
  Future<void> updateSubscription(String subscriptionId, String newPriceId);
  
  // Refund processing
  Future<Refund> processRefund({
    required String transactionId,
    required double amount,
    required String reason,
  });
  
  // Transaction queries
  Future<List<Transaction>> getTransactions({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  });
}
```

#### 5. Subscription Management Component

**Location:** `lib/screens/admin/subscription_management_screen.dart` (new)

**Purpose:** Manage user subscriptions

**Features:**
- View all subscriptions
- Upgrade/downgrade subscriptions
- Cancel subscriptions
- View subscription history
- Upcoming renewals
- Proration calculations

#### 6. Transaction Management Component

**Location:** `lib/screens/admin/transaction_management_screen.dart` (new)

**Purpose:** View and manage payment transactions

**Features:**
- Transaction search and filtering
- Transaction details view
- Export to CSV
- Refund initiation
- Transaction status tracking

#### 7. Financial Reporting Component

**Location:** `lib/screens/admin/financial_reports_screen.dart` (new)

**Purpose:** Generate financial reports

**Features:**
- Revenue reports (daily, monthly, yearly)
- Subscription metrics (MRR, churn rate)
- Payment method breakdown
- Refund statistics
- Export to PDF/CSV
- Visual charts and graphs

#### 8. Audit Log Viewer Component

**Location:** `lib/screens/admin/audit_log_viewer_screen.dart` (new)

**Purpose:** View administrative action logs

**Features:**
- Log search and filtering
- Log detail view
- Export logs
- Real-time log streaming
- Severity filtering

#### 9. Email Provider Configuration Component (Self-Hosted Only)

**Location:** `lib/screens/admin/email_provider_config_screen.dart` (new)

**Purpose:** Configure email provider for self-hosted instances

**Features:**
- SMTP server configuration form
- Email service provider selection (SendGrid, Mailgun, AWS SES)
- Test email functionality
- Email provider status monitoring
- Only visible in self-hosted deployments

**Visibility Logic:**
```dart
bool get isEmailConfigAvailable {
  // Check if instance is self-hosted
  // This will be determined by environment variable or deployment config
  return !kIsWeb || _isSelfHostedInstance();
}

bool _isSelfHostedInstance() {
  // Check deployment type from environment
  const deploymentType = String.fromEnvironment('DEPLOYMENT_TYPE', defaultValue: 'cloud');
  return deploymentType == 'self-hosted';
}
```

**Note:** Detailed implementation will be covered in a separate email provider configuration spec.

#### 10. Admin Management Component (Super Admin Only)

**Location:** `lib/screens/admin/admin_management_screen.dart` (new)

**Purpose:** Manage administrator accounts and roles

**Features:**
- List all administrators with their roles
- Add new administrators
- Assign/revoke admin roles
- View admin activity history
- Only accessible to Super Admin role

**UI Elements:**
- Admin list table with role badges
- Add admin button
- Role assignment dropdown
- Revoke role button
- Admin activity timeline

**Role Assignment Flow:**
1. Super Admin searches for user by email
2. Select user from search results
3. Choose role (Support Admin or Finance Admin)
4. Confirm role assignment
5. User receives email notification (if email configured)
6. Action logged in audit log

### Backend API Endpoints

#### Admin Authentication Middleware

**Location:** `services/api-backend/src/middleware/admin-auth.js` (new)

**Purpose:** Verify admin privileges and roles

```javascript
const adminAuth = (requiredPermissions = []) => {
  return async (req, res, next) => {
    try {
      // Verify JWT token
      const token = req.headers.authorization?.split(' ')[1];
      if (!token) {
        return res.status(401).json({ error: 'No token provided' });
      }
      
      // Decode and verify token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      // Get user and their admin roles
      const userResult = await db.query(
        `SELECT u.id, u.email, u.auth0_id,
                array_agg(ar.role) as roles
         FROM users u
         LEFT JOIN admin_roles ar ON u.id = ar.user_id AND ar.is_active = true
         WHERE u.auth0_id = $1
         GROUP BY u.id, u.email, u.auth0_id`,
        [decoded.sub]
      );
      
      if (!userResult.rows[0]) {
        return res.status(403).json({ error: 'User not found' });
      }
      
      const user = userResult.rows[0];
      
      // Check if user has any admin role
      if (!user.roles || user.roles.length === 0 || user.roles[0] === null) {
        return res.status(403).json({ error: 'Admin access required' });
      }
      
      // Check if user has required permissions
      if (requiredPermissions.length > 0) {
        const hasPermission = checkPermissions(user.roles, requiredPermissions);
        if (!hasPermission) {
          return res.status(403).json({ 
            error: 'Insufficient permissions',
            required: requiredPermissions
          });
        }
      }
      
      req.adminUser = user;
      req.adminRoles = user.roles;
      next();
    } catch (error) {
      return res.status(401).json({ error: 'Invalid token' });
    }
  };
};

// Permission checking helper
const checkPermissions = (userRoles, requiredPermissions) => {
  const rolePermissions = {
    super_admin: ['*'], // All permissions
    support_admin: [
      'view_users', 'edit_users', 'suspend_users',
      'view_sessions', 'terminate_sessions',
      'view_payments', 'view_audit_logs'
    ],
    finance_admin: [
      'view_users', 'view_payments', 'process_refunds',
      'view_subscriptions', 'edit_subscriptions',
      'view_reports', 'export_reports', 'view_audit_logs'
    ]
  };
  
  // Super admin has all permissions
  if (userRoles.includes('super_admin')) {
    return true;
  }
  
  // Check if user has any role with required permissions
  const userPermissions = userRoles.flatMap(role => rolePermissions[role] || []);
  return requiredPermissions.every(perm => userPermissions.includes(perm));
};

// Usage examples:
// router.get('/users', adminAuth(), async (req, res) => { ... });
// router.delete('/users/:id', adminAuth(['delete_users']), async (req, res) => { ... });
// router.post('/refunds', adminAuth(['process_refunds']), async (req, res) => { ... });
```

#### User Management Endpoints

**Location:** `services/api-backend/src/routes/admin/users.js` (new)

```javascript
// GET /api/admin/users - List all users with pagination
router.get('/users', adminAuth, async (req, res) => {
  const { page = 1, limit = 50, search, tier, status } = req.query;
  // Implementation
});

// GET /api/admin/users/:userId - Get user details
router.get('/users/:userId', adminAuth, async (req, res) => {
  // Implementation
});

// PATCH /api/admin/users/:userId - Update user
router.patch('/users/:userId', adminAuth, async (req, res) => {
  // Implementation
});

// POST /api/admin/users/:userId/suspend - Suspend user
router.post('/users/:userId/suspend', adminAuth, async (req, res) => {
  // Implementation
});

// POST /api/admin/users/:userId/reactivate - Reactivate user
router.post('/users/:userId/reactivate', adminAuth, async (req, res) => {
  // Implementation
});
```

#### Payment Management Endpoints

**Location:** `services/api-backend/src/routes/admin/payments.js` (new)

```javascript
// GET /api/admin/payments/transactions - List transactions
router.get('/payments/transactions', adminAuth, async (req, res) => {
  // Implementation
});

// GET /api/admin/payments/transactions/:transactionId - Get transaction details
router.get('/payments/transactions/:transactionId', adminAuth, async (req, res) => {
  // Implementation
});

// POST /api/admin/payments/refunds - Process refund
router.post('/payments/refunds', adminAuth, async (req, res) => {
  // Implementation
});

// GET /api/admin/payments/methods/:userId - Get user payment methods
router.get('/payments/methods/:userId', adminAuth, async (req, res) => {
  // Implementation
});
```

#### Subscription Management Endpoints

**Location:** `services/api-backend/src/routes/admin/subscriptions.js` (new)

```javascript
// GET /api/admin/subscriptions - List all subscriptions
router.get('/subscriptions', adminAuth, async (req, res) => {
  // Implementation
});

// GET /api/admin/subscriptions/:subscriptionId - Get subscription details
router.get('/subscriptions/:subscriptionId', adminAuth, async (req, res) => {
  // Implementation
});

// PATCH /api/admin/subscriptions/:subscriptionId - Update subscription
router.patch('/subscriptions/:subscriptionId', adminAuth, async (req, res) => {
  // Implementation
});

// POST /api/admin/subscriptions/:subscriptionId/cancel - Cancel subscription
router.post('/subscriptions/:subscriptionId/cancel', adminAuth, async (req, res) => {
  // Implementation
});
```

#### Reporting Endpoints

**Location:** `services/api-backend/src/routes/admin/reports.js` (new)

```javascript
// GET /api/admin/reports/revenue - Revenue report
router.get('/reports/revenue', adminAuth, async (req, res) => {
  // Implementation
});

// GET /api/admin/reports/subscriptions - Subscription metrics
router.get('/reports/subscriptions', adminAuth, async (req, res) => {
  // Implementation
});

// GET /api/admin/reports/export - Export report
router.get('/reports/export', adminAuth, async (req, res) => {
  // Implementation
});
```

#### Audit Log Endpoints

**Location:** `services/api-backend/src/routes/admin/audit.js` (new)

```javascript
// GET /api/admin/audit/logs - List audit logs
router.get('/audit/logs', adminAuth, async (req, res) => {
  // Implementation
});

// GET /api/admin/audit/logs/:logId - Get log details
router.get('/audit/logs/:logId', adminAuth, async (req, res) => {
  // Implementation
});
```



## Data Models

### Database Schema Extensions

#### Subscriptions Table

```sql
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stripe_subscription_id TEXT UNIQUE,  -- Stripe subscription ID
  stripe_customer_id TEXT,  -- Stripe customer ID
  tier TEXT NOT NULL CHECK (tier IN ('free', 'premium', 'enterprise')),
  status TEXT NOT NULL CHECK (status IN ('active', 'canceled', 'past_due', 'trialing', 'incomplete')),
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT false,
  canceled_at TIMESTAMPTZ,
  trial_start TIMESTAMPTZ,
  trial_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_stripe_subscription_id ON subscriptions(stripe_subscription_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_tier ON subscriptions(tier);
```

#### Payment Transactions Table

```sql
CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  stripe_payment_intent_id TEXT UNIQUE,  -- Stripe PaymentIntent ID
  stripe_charge_id TEXT,  -- Stripe Charge ID
  amount DECIMAL(10, 2) NOT NULL,  -- Amount in dollars
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded', 'partially_refunded', 'disputed')),
  payment_method_type TEXT,  -- card, paypal, etc.
  payment_method_last4 TEXT,  -- Last 4 digits of card
  failure_code TEXT,
  failure_message TEXT,
  receipt_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_payment_transactions_user_id ON payment_transactions(user_id);
CREATE INDEX idx_payment_transactions_subscription_id ON payment_transactions(subscription_id);
CREATE INDEX idx_payment_transactions_stripe_payment_intent_id ON payment_transactions(stripe_payment_intent_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX idx_payment_transactions_created_at ON payment_transactions(created_at DESC);
```

#### Payment Methods Table

```sql
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stripe_payment_method_id TEXT UNIQUE NOT NULL,  -- Stripe PaymentMethod ID
  type TEXT NOT NULL,  -- card, paypal, etc.
  card_brand TEXT,  -- visa, mastercard, etc.
  card_last4 TEXT,
  card_exp_month INTEGER,
  card_exp_year INTEGER,
  billing_email TEXT,
  billing_name TEXT,
  billing_address JSONB,
  is_default BOOLEAN DEFAULT false,
  status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'failed_verification')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_stripe_payment_method_id ON payment_methods(stripe_payment_method_id);
CREATE INDEX idx_payment_methods_status ON payment_methods(status);
```

#### Refunds Table

```sql
CREATE TABLE IF NOT EXISTS refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE CASCADE,
  stripe_refund_id TEXT UNIQUE NOT NULL,  -- Stripe Refund ID
  amount DECIMAL(10, 2) NOT NULL,  -- Refund amount in dollars
  currency TEXT NOT NULL DEFAULT 'USD',
  reason TEXT NOT NULL CHECK (reason IN ('customer_request', 'billing_error', 'service_issue', 'duplicate', 'fraudulent', 'other')),
  reason_details TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'canceled')),
  failure_reason TEXT,
  admin_user_id UUID REFERENCES users(id),  -- Admin who processed refund
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_refunds_transaction_id ON refunds(transaction_id);
CREATE INDEX idx_refunds_stripe_refund_id ON refunds(stripe_refund_id);
CREATE INDEX idx_refunds_status ON refunds(status);
CREATE INDEX idx_refunds_created_at ON refunds(created_at DESC);
```

#### Admin Roles Table

```sql
CREATE TABLE IF NOT EXISTS admin_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('super_admin', 'support_admin', 'finance_admin')),
  granted_by UUID REFERENCES users(id) ON DELETE SET NULL,  -- Admin who granted the role
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)  -- User can have multiple roles but not duplicate roles
);

CREATE INDEX idx_admin_roles_user_id ON admin_roles(user_id);
CREATE INDEX idx_admin_roles_role ON admin_roles(role);
CREATE INDEX idx_admin_roles_is_active ON admin_roles(is_active) WHERE is_active = true;

-- Insert default Super Admin role for cmaltais@cloudtolocalllm.online
-- This will be executed during initial database setup
INSERT INTO admin_roles (user_id, role, is_active)
SELECT id, 'super_admin', true
FROM users
WHERE email = 'cmaltais@cloudtolocalllm.online'
ON CONFLICT (user_id, role) DO NOTHING;
```

#### Admin Audit Logs Table

```sql
CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  admin_role TEXT NOT NULL,  -- Role of admin at time of action
  action TEXT NOT NULL,  -- e.g., 'user_suspended', 'subscription_upgraded', 'refund_processed'
  resource_type TEXT NOT NULL,  -- e.g., 'user', 'subscription', 'transaction'
  resource_id TEXT NOT NULL,  -- ID of affected resource
  affected_user_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- User affected by action
  details JSONB DEFAULT '{}'::jsonb,  -- Additional action details
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_admin_audit_logs_admin_user_id ON admin_audit_logs(admin_user_id);
CREATE INDEX idx_admin_audit_logs_action ON admin_audit_logs(action);
CREATE INDEX idx_admin_audit_logs_resource_type ON admin_audit_logs(resource_type);
CREATE INDEX idx_admin_audit_logs_affected_user_id ON admin_audit_logs(affected_user_id);
CREATE INDEX idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);
```

### Dart Models

All Flutter models for the Admin Center are located in `lib/models/` and follow consistent patterns for JSON serialization, immutability, and value equality.

#### Subscription Model

**Location:** `lib/models/subscription_model.dart` ✅ **IMPLEMENTED**

**Purpose:** Represents user subscription information including tier, status, and billing periods.

**Key Features:**
- Subscription tier management (free, premium, enterprise)
- Status tracking (active, canceled, past_due, trialing, incomplete)
- Billing period information with start/end dates
- Trial period support
- Stripe integration (subscription ID, customer ID)
- Cancellation tracking (cancel at period end, canceled at timestamp)
- Helper methods: `isActive`, `isTrialing`, `isCanceled`, `isPastDue`, `daysRemaining`
- JSON serialization with both snake_case and camelCase support
- Immutable design with `copyWith()` method
- Value equality implementation

**Enums:**
- `SubscriptionTier`: free, premium, enterprise (with display names)
- `SubscriptionStatus`: active, canceled, past_due, trialing, incomplete (with display names and issue detection)

**Example Usage:**
```dart
// Parse from API response
final subscription = SubscriptionModel.fromJson(jsonData);

// Check subscription status
if (subscription.isActive) {
  print('Days remaining: ${subscription.daysRemaining}');
}

// Update subscription
final updated = subscription.copyWith(
  tier: SubscriptionTier.premium,
  status: SubscriptionStatus.active,
);
```

#### Payment Transaction Model

**Location:** `lib/models/payment_transaction_model.dart` (new)

```dart
class PaymentTransactionModel {
  final String id;
  final String userId;
  final String? subscriptionId;
  final String? stripePaymentIntentId;
  final String? stripeChargeId;
  final double amount;
  final String currency;
  final TransactionStatus status;
  final String? paymentMethodType;
  final String? paymentMethodLast4;
  final String? failureCode;
  final String? failureMessage;
  final String? receiptUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;
  
  PaymentTransactionModel({
    required this.id,
    required this.userId,
    this.subscriptionId,
    this.stripePaymentIntentId,
    this.stripeChargeId,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentMethodType,
    this.paymentMethodLast4,
    this.failureCode,
    this.failureMessage,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });
  
  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    // Implementation
  }
  
  Map<String, dynamic> toJson() {
    // Implementation
  }
}

enum TransactionStatus {
  pending,
  succeeded,
  failed,
  refunded,
  partiallyRefunded,
  disputed
}
```

#### Refund Model

**Location:** `lib/models/refund_model.dart` (new)

```dart
class RefundModel {
  final String id;
  final String transactionId;
  final String stripeRefundId;
  final double amount;
  final String currency;
  final RefundReason reason;
  final String? reasonDetails;
  final RefundStatus status;
  final String? failureReason;
  final String? adminUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;
  
  RefundModel({
    required this.id,
    required this.transactionId,
    required this.stripeRefundId,
    required this.amount,
    required this.currency,
    required this.reason,
    this.reasonDetails,
    required this.status,
    this.failureReason,
    this.adminUserId,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });
  
  factory RefundModel.fromJson(Map<String, dynamic> json) {
    // Implementation
  }
  
  Map<String, dynamic> toJson() {
    // Implementation
  }
}

enum RefundReason {
  customerRequest,
  billingError,
  serviceIssue,
  duplicate,
  fraudulent,
  other
}

enum RefundStatus { pending, succeeded, failed, canceled }
```

#### Admin Role Model

**Location:** `lib/models/admin_role_model.dart` (new)

```dart
class AdminRoleModel {
  final String id;
  final String userId;
  final AdminRole role;
  final String? grantedBy;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  AdminRoleModel({
    required this.id,
    required this.userId,
    required this.role,
    this.grantedBy,
    required this.grantedAt,
    this.revokedAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory AdminRoleModel.fromJson(Map<String, dynamic> json) {
    // Implementation
  }
  
  Map<String, dynamic> toJson() {
    // Implementation
  }
  
  bool hasPermission(AdminPermission permission) {
    return role.permissions.contains(permission);
  }
}

enum AdminRole {
  superAdmin,
  supportAdmin,
  financeAdmin;
  
  List<AdminPermission> get permissions {
    switch (this) {
      case AdminRole.superAdmin:
        return AdminPermission.values; // All permissions
      case AdminRole.supportAdmin:
        return [
          AdminPermission.viewUsers,
          AdminPermission.editUsers,
          AdminPermission.suspendUsers,
          AdminPermission.viewSessions,
          AdminPermission.terminateSessions,
          AdminPermission.viewPayments,
          AdminPermission.viewAuditLogs,
        ];
      case AdminRole.financeAdmin:
        return [
          AdminPermission.viewUsers,
          AdminPermission.viewPayments,
          AdminPermission.processRefunds,
          AdminPermission.viewSubscriptions,
          AdminPermission.editSubscriptions,
          AdminPermission.viewReports,
          AdminPermission.exportReports,
          AdminPermission.viewAuditLogs,
        ];
    }
  }
}

enum AdminPermission {
  // User management
  viewUsers,
  editUsers,
  suspendUsers,
  deleteUsers,
  viewSessions,
  terminateSessions,
  
  // Payment management
  viewPayments,
  processRefunds,
  viewPaymentMethods,
  deletePaymentMethods,
  
  // Subscription management
  viewSubscriptions,
  editSubscriptions,
  cancelSubscriptions,
  
  // Reporting
  viewReports,
  exportReports,
  
  // Admin management
  viewAdmins,
  createAdmins,
  editAdmins,
  deleteAdmins,
  
  // Configuration
  viewConfiguration,
  editConfiguration,
  
  // Audit logs
  viewAuditLogs,
  exportAuditLogs,
}
```

#### Admin Audit Log Model

**Location:** `lib/models/admin_audit_log_model.dart` (new)

```dart
class AdminAuditLogModel {
  final String id;
  final String adminUserId;
  final String adminRole;
  final String action;
  final String resourceType;
  final String resourceId;
  final String? affectedUserId;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;
  
  AdminAuditLogModel({
    required this.id,
    required this.adminUserId,
    required this.adminRole,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    this.affectedUserId,
    this.details,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });
  
  factory AdminAuditLogModel.fromJson(Map<String, dynamic> json) {
    // Implementation
  }
  
  Map<String, dynamic> toJson() {
    // Implementation
  }
}
```



## Error Handling

### Frontend Error Handling

#### Error Types

1. **Authentication Errors**
   - Unauthorized access (403)
   - Session expired (401)
   - Invalid admin privileges

2. **API Errors**
   - Network failures
   - Server errors (500)
   - Validation errors (400)
   - Not found errors (404)

3. **Payment Gateway Errors**
   - Payment processing failures
   - Refund failures
   - Subscription update failures
   - Invalid payment method

4. **Data Validation Errors**
   - Invalid input data
   - Missing required fields
   - Format errors

#### Error Handling Strategy

```dart
class AdminErrorHandler {
  static void handleError(BuildContext context, dynamic error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          _handleUnauthorized(context);
          break;
        case 403:
          _handleForbidden(context);
          break;
        case 404:
          _handleNotFound(context);
          break;
        case 500:
          _handleServerError(context);
          break;
        default:
          _handleGenericError(context, error);
      }
    } else if (error is PaymentGatewayException) {
      _handlePaymentError(context, error);
    } else {
      _handleGenericError(context, error);
    }
  }
  
  static void _handleUnauthorized(BuildContext context) {
    // Show session expired dialog
    // Redirect to login
  }
  
  static void _handleForbidden(BuildContext context) {
    // Show access denied message
    // Redirect to main app
  }
  
  static void _handlePaymentError(BuildContext context, PaymentGatewayException error) {
    // Show payment-specific error message
    // Provide retry option
  }
}
```

### Backend Error Handling

#### Error Response Format

```javascript
{
  "error": {
    "code": "PAYMENT_FAILED",
    "message": "Payment processing failed",
    "details": {
      "reason": "insufficient_funds",
      "payment_intent_id": "pi_xxx"
    },
    "timestamp": "2025-11-15T10:30:00Z"
  }
}
```

#### Error Logging

```javascript
const logError = (error, context) => {
  logger.error({
    message: error.message,
    stack: error.stack,
    context: {
      adminUserId: context.adminUser?.id,
      action: context.action,
      resourceId: context.resourceId,
      timestamp: new Date().toISOString()
    }
  });
};
```

### Payment Gateway Error Handling

#### Stripe Error Handling

```javascript
const handleStripeError = (error) => {
  switch (error.type) {
    case 'StripeCardError':
      // Card was declined
      return {
        code: 'CARD_DECLINED',
        message: error.message,
        details: { decline_code: error.decline_code }
      };
    case 'StripeInvalidRequestError':
      // Invalid parameters
      return {
        code: 'INVALID_REQUEST',
        message: 'Invalid payment request',
        details: { param: error.param }
      };
    case 'StripeAPIError':
      // Stripe API error
      return {
        code: 'PAYMENT_GATEWAY_ERROR',
        message: 'Payment gateway error',
        details: { type: error.type }
      };
    default:
      return {
        code: 'UNKNOWN_ERROR',
        message: 'An unknown error occurred',
        details: {}
      };
  }
};
```

## Testing Strategy

### Unit Tests

#### Frontend Unit Tests

**Location:** `test/services/payment_gateway_service_test.dart`

```dart
void main() {
  group('PaymentGatewayService', () {
    late PaymentGatewayService service;
    late MockAuthService mockAuthService;
    late MockDio mockDio;
    
    setUp(() {
      mockAuthService = MockAuthService();
      mockDio = MockDio();
      service = PaymentGatewayService(mockAuthService, mockDio);
    });
    
    test('processPayment returns success on valid payment', () async {
      // Test implementation
    });
    
    test('processPayment throws exception on payment failure', () async {
      // Test implementation
    });
    
    test('processRefund creates refund successfully', () async {
      // Test implementation
    });
  });
}
```

#### Backend Unit Tests

**Location:** `services/api-backend/src/routes/admin/__tests__/users.test.js`

```javascript
describe('Admin User Management API', () => {
  describe('GET /api/admin/users', () => {
    it('should return paginated users for admin', async () => {
      // Test implementation
    });
    
    it('should return 403 for non-admin users', async () => {
      // Test implementation
    });
    
    it('should filter users by subscription tier', async () => {
      // Test implementation
    });
  });
  
  describe('PATCH /api/admin/users/:userId', () => {
    it('should update user subscription tier', async () => {
      // Test implementation
    });
    
    it('should log admin action in audit log', async () => {
      // Test implementation
    });
  });
});
```

### Integration Tests

#### Payment Gateway Integration Tests

**Location:** `services/api-backend/src/__tests__/integration/payment-gateway.test.js`

```javascript
describe('Payment Gateway Integration', () => {
  it('should process payment through Stripe', async () => {
    // Test with Stripe test mode
  });
  
  it('should create subscription and charge customer', async () => {
    // Test subscription creation
  });
  
  it('should process refund successfully', async () => {
    // Test refund processing
  });
  
  it('should handle webhook notifications', async () => {
    // Test webhook handling
  });
});
```

### End-to-End Tests

#### Admin Center E2E Tests

**Location:** `test/e2e/admin_center_test.dart`

```dart
void main() {
  group('Admin Center E2E Tests', () {
    testWidgets('Admin can access admin center from settings', (tester) async {
      // Test admin button visibility and navigation
    });
    
    testWidgets('Admin can view and search users', (tester) async {
      // Test user management functionality
    });
    
    testWidgets('Admin can process refund', (tester) async {
      // Test refund processing workflow
    });
    
    testWidgets('Non-admin cannot access admin center', (tester) async {
      // Test access control
    });
  });
}
```

### Test Data

#### Test Users

```javascript
const testUsers = {
  admin: {
    email: 'admin@test.com',
    auth0_id: 'auth0|test_admin',
    role: 'admin'
  },
  regularUser: {
    email: 'user@test.com',
    auth0_id: 'auth0|test_user',
    role: 'user'
  }
};
```

#### Test Payment Data

```javascript
const testPaymentData = {
  validCard: {
    number: '4242424242424242',  // Stripe test card
    exp_month: 12,
    exp_year: 2025,
    cvc: '123'
  },
  declinedCard: {
    number: '4000000000000002',  // Stripe test declined card
    exp_month: 12,
    exp_year: 2025,
    cvc: '123'
  }
};
```

### Testing Best Practices

1. **Use Test Mode for Payment Gateway**
   - Always use Stripe test mode API keys
   - Never use production credentials in tests

2. **Mock External Services**
   - Mock Auth0 authentication in unit tests
   - Mock payment gateway responses
   - Use test database for integration tests

3. **Test Error Scenarios**
   - Test payment failures
   - Test network errors
   - Test invalid input data
   - Test unauthorized access

4. **Test Audit Logging**
   - Verify all admin actions are logged
   - Test log retrieval and filtering
   - Verify log immutability

5. **Test Data Isolation**
   - Use separate test database
   - Clean up test data after each test
   - Use transactions for rollback



## Security Considerations

### Authentication and Authorization

#### Admin Access Control

1. **Role-Based Access Control (RBAC)**
   - Three admin roles: Super Admin, Support Admin, Finance Admin
   - Default Super Admin: `cmaltais@cloudtolocalllm.online`
   - Role stored in database (admin_roles table)
   - Verified against Auth0 user profile

2. **Admin Roles and Permissions**
   - **Super Admin**: Full access to all features (user management, payments, configuration, admin management)
   - **Support Admin**: User management, account suspension, view-only access to payments
   - **Finance Admin**: Payment management, refunds, financial reports, no user deletion

3. **Session Inheritance**
   - Admin Center inherits session from main app
   - No separate login required
   - Session token passed via secure cookie or localStorage
   - Session validation on every API request
   - Role checked on every privileged operation

4. **JWT Token Validation**
   - Verify JWT signature
   - Check token expiration
   - Validate admin role from database
   - Refresh token if needed

#### API Security

1. **Admin Middleware**
   - Verify JWT token on every request
   - Check admin email against whitelist
   - Log all admin API access
   - Rate limiting for admin endpoints

2. **CORS Configuration**
   - Restrict CORS to app domain
   - No wildcard origins
   - Credentials required for admin endpoints

3. **Input Validation**
   - Validate all input parameters
   - Sanitize user input
   - Prevent SQL injection
   - Prevent XSS attacks

### Data Protection

#### Sensitive Data Handling

1. **Payment Information**
   - Never store full credit card numbers
   - Store only last 4 digits
   - Use Stripe tokenization
   - PCI DSS compliance

2. **User Data**
   - Encrypt sensitive user data at rest
   - Use HTTPS for all communications
   - Mask email addresses in logs
   - Implement data retention policies

3. **Audit Logs**
   - Immutable audit logs
   - Cryptographic signatures
   - Tamper detection
   - Long-term retention (7 years)

#### Database Security

1. **Connection Security**
   - Use SSL/TLS for database connections
   - Rotate database credentials regularly
   - Use connection pooling
   - Limit database user privileges

2. **Query Security**
   - Use parameterized queries
   - Prevent SQL injection
   - Limit query result sizes
   - Implement query timeouts

### Payment Gateway Security

#### Stripe Integration Security

1. **API Key Management**
   - Use environment variables for API keys
   - Separate test and production keys
   - Rotate keys periodically
   - Never commit keys to version control

2. **Webhook Security**
   - Verify webhook signatures
   - Use HTTPS for webhook endpoints
   - Implement idempotency
   - Log all webhook events

3. **Payment Processing**
   - Use Stripe Elements for card input
   - Implement 3D Secure (SCA)
   - Handle payment failures gracefully
   - Implement retry logic

### Audit and Compliance

#### Audit Logging

1. **Log All Admin Actions**
   - User management actions
   - Payment operations
   - Subscription changes
   - Refund processing
   - Data access

2. **Log Format**
   ```json
   {
     "id": "uuid",
     "admin_user_id": "uuid",
     "action": "user_suspended",
     "resource_type": "user",
     "resource_id": "user_uuid",
     "affected_user_id": "user_uuid",
     "details": {
       "reason": "Terms of service violation",
       "previous_status": "active",
       "new_status": "suspended"
     },
     "ip_address": "192.168.1.1",
     "user_agent": "Mozilla/5.0...",
     "timestamp": "2025-11-15T10:30:00Z"
   }
   ```

3. **Log Retention**
   - Minimum 7 years for compliance
   - Automated archival
   - Secure backup storage
   - Tamper-proof storage

#### Compliance Requirements

1. **PCI DSS Compliance**
   - Never store full card numbers
   - Use Stripe for card processing
   - Implement access controls
   - Regular security audits

2. **GDPR Compliance**
   - User data export capability
   - Right to be forgotten
   - Data processing agreements
   - Privacy policy updates

3. **SOC 2 Compliance** (Future)
   - Security controls
   - Availability monitoring
   - Processing integrity
   - Confidentiality measures

## Performance Optimization

### Frontend Performance

#### Lazy Loading

1. **Route-Based Code Splitting**
   - Load admin screens on demand
   - Reduce initial bundle size
   - Faster initial load time

2. **Data Pagination**
   - Paginate user lists (50 per page)
   - Paginate transaction lists (100 per page)
   - Virtual scrolling for large lists

3. **Caching Strategy**
   - Cache user data locally
   - Cache transaction data
   - Invalidate cache on updates
   - Use service worker for offline support

#### UI Optimization

1. **Debouncing and Throttling**
   - Debounce search inputs (300ms)
   - Throttle scroll events
   - Throttle window resize events

2. **Optimistic Updates**
   - Update UI immediately
   - Revert on error
   - Show loading indicators

### Backend Performance

#### Database Optimization

1. **Indexing Strategy**
   - Index frequently queried columns
   - Composite indexes for complex queries
   - Partial indexes for filtered queries
   - Regular index maintenance

2. **Query Optimization**
   - Use EXPLAIN ANALYZE for slow queries
   - Optimize JOIN operations
   - Limit result sets
   - Use database views for complex queries

3. **Connection Pooling**
   - Maximum 50 connections
   - Connection timeout: 30 seconds
   - Idle connection timeout: 10 minutes
   - Connection reuse

#### API Performance

1. **Response Caching**
   - Cache frequently accessed data
   - Use Redis for caching
   - Cache invalidation strategy
   - ETags for conditional requests

2. **Rate Limiting**
   - 100 requests per minute per admin
   - Burst allowance: 20 requests
   - Rate limit headers in response
   - 429 status code on limit exceeded

3. **Async Processing**
   - Queue long-running operations
   - Background job processing
   - Webhook processing
   - Report generation

### Payment Gateway Performance

#### Stripe API Optimization

1. **Request Batching**
   - Batch multiple operations
   - Reduce API calls
   - Use Stripe's batch endpoints

2. **Webhook Processing**
   - Async webhook handling
   - Queue webhook events
   - Retry failed webhooks
   - Idempotency keys

3. **Caching**
   - Cache customer data
   - Cache subscription data
   - Cache payment methods
   - Invalidate on updates

## Deployment Strategy

### Development Environment

1. **Local Development**
   - Use Stripe test mode
   - Local PostgreSQL database
   - Mock payment gateway responses
   - Hot reload for Flutter web

2. **Development Database**
   - Separate dev database
   - Test data seeding
   - Database migrations
   - Backup and restore

### Staging Environment

1. **Staging Setup**
   - Staging database (PostgreSQL)
   - Stripe test mode
   - Staging domain: `admin-staging.cloudtolocalllm.online`
   - SSL certificate

2. **Testing**
   - Integration testing
   - E2E testing
   - Performance testing
   - Security testing

### Production Environment

1. **Production Setup**
   - Production database (PostgreSQL on AKS)
   - Stripe production mode
   - Production domain: `admin.cloudtolocalllm.online`
   - SSL certificate (Let's Encrypt)

2. **Deployment Process**
   - Build Flutter web app
   - Deploy to Kubernetes
   - Database migrations
   - Health checks
   - Rollback plan

3. **Monitoring**
   - Grafana dashboards
   - Prometheus metrics
   - Error tracking (Sentry)
   - Performance monitoring

### CI/CD Pipeline

1. **Build Pipeline**
   - Run tests
   - Build Flutter web app
   - Build Docker image
   - Push to Docker Hub

2. **Deployment Pipeline**
   - Deploy to staging
   - Run smoke tests
   - Deploy to production
   - Verify deployment

3. **Rollback Strategy**
   - Keep previous 3 versions
   - Automated rollback on failure
   - Database migration rollback
   - Manual rollback option

## Monitoring and Observability

### Application Monitoring

1. **Metrics Collection**
   - Request count and latency
   - Error rates
   - Payment success/failure rates
   - Refund processing times
   - User management operations

2. **Grafana Dashboards**
   - Admin Center overview
   - Payment gateway metrics
   - User management metrics
   - System health
   - Error tracking

3. **Alerts**
   - High error rate (>5%)
   - Payment failures (>10%)
   - Slow API responses (>2s)
   - Database connection issues
   - Stripe API errors

### Logging

1. **Application Logs**
   - Structured JSON logs
   - Log levels (debug, info, warn, error)
   - Request/response logging
   - Error stack traces

2. **Audit Logs**
   - All admin actions
   - Payment operations
   - User management
   - Data access
   - Configuration changes

3. **Log Aggregation**
   - Centralized logging (Loki)
   - Log retention (90 days)
   - Log search and filtering
   - Log export

### Performance Monitoring

1. **Frontend Performance**
   - Page load times
   - Time to interactive
   - First contentful paint
   - Largest contentful paint

2. **Backend Performance**
   - API response times
   - Database query times
   - Payment gateway latency
   - Cache hit rates

3. **Database Performance**
   - Query execution times
   - Connection pool usage
   - Index usage
   - Table sizes

## Future Enhancements

### Email Provider Configuration (Self-Hosted Only)

**Note:** Email provider configuration will be detailed in a separate spec. This section provides a high-level overview of the feature.

1. **Email Provider Settings**
   - SMTP server configuration
   - Email service provider integration (SendGrid, Mailgun, AWS SES)
   - Email templates management
   - Email sending and receiving configuration

2. **Availability**
   - Only available in self-hosted instances
   - Hidden in cloud-hosted instances
   - Requires admin privileges to configure

3. **UI Location**
   - Admin Center > Configuration > Email Provider
   - Settings form for SMTP/provider credentials
   - Test email functionality
   - Email logs and monitoring

4. **Future Spec**
   - Detailed email provider configuration spec will be created separately
   - Will include email template management
   - Email queue and retry logic
   - Email analytics and tracking

### Phase 2 Features (from Roadmap)

1. **Analytics Dashboard**
   - User engagement metrics
   - Conversion analytics
   - Revenue trends
   - Geographic distribution

2. **Support Integration**
   - In-app messaging
   - Ticket management
   - Broadcast announcements

3. **Advanced Reporting**
   - Custom report builder
   - Scheduled reports
   - Export to multiple formats

### Scalability Considerations

1. **Horizontal Scaling**
   - Multiple admin API instances
   - Load balancing
   - Session sharing (Redis)
   - Database read replicas

2. **Caching Layer**
   - Redis for caching
   - Cache warming
   - Cache invalidation
   - Distributed caching

3. **Database Sharding** (Future)
   - Shard by user ID
   - Shard by date
   - Cross-shard queries
   - Shard rebalancing

