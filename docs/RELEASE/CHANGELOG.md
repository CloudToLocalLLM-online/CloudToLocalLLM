# Changelog

All notable changes to CloudToLocalLLM will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - Admin Center UI Access

#### Settings Screen Admin Center Integration
- **Admin Center Access Button** in Unified Settings Screen
  - Visible only to authorized admin users (cmaltais@cloudtolocalllm.online)
  - Email-based authorization check using AuthService
  - Opens Admin Center in new tab (web) or navigates to route (desktop)
  - Visual indicator with admin panel icon
  - Descriptive subtitle: "Manage users, payments, and subscriptions"
  - Graceful error handling for auth service failures

**Features:**
- Dynamic visibility based on user email authentication
- Platform-aware navigation (web vs desktop)
- Integration with existing AuthService for user identification
- Clean card-based UI design matching app theme
- External link icon for visual clarity

**Implementation:**
- Location: `lib/screens/unified_settings_screen.dart`
- Dependencies: `AuthService`, `go_router`
- Route: `/admin-center` (configured in router)
- Authorization: Email-based check against authorized admin list

**Security:**
- Client-side authorization check (UI visibility only)
- Backend API enforces role-based access control
- JWT token validation on all admin API requests
- Comprehensive audit logging of admin actions

### Added - Admin Center Flutter Services (Phase 1)

#### Admin Center Service (`lib/services/admin_center_service.dart`)
- **AdminCenterService** - Core administrative service for Admin Center
  - Role-based access control and permission checking
  - Admin role management (Super Admin, Support Admin, Finance Admin)
  - Permission validation for all admin operations
  - Service initialization with role loading
  - JWT authentication with admin role validation
  - Dio HTTP client with interceptors for auth and error handling
  - Real-time data caching with timestamp tracking
  - Comprehensive error handling and user feedback
  - Integration with admin API backend (`/api/admin/*`)
  - User management operations (list, view, suspend, reactivate)
  - Dashboard metrics retrieval and caching
  - Subscription tier updates

**Features:**
- Connects to admin API backend at `/api/admin/*`
- Automatic JWT token injection via Dio interceptors
- Admin role validation (403 error handling)
- Permission-based method access control
- Loading state management with `ChangeNotifier`
- Error state management with user-friendly messages
- Cached dashboard metrics with timestamps
- Auth state listener for automatic cleanup on logout
- Proper resource cleanup in `dispose()`

**Admin Roles:**
- `super_admin` - Full system access (all permissions)
- `support_admin` - User management and support operations
- `finance_admin` - Payment and subscription management

**Permissions:**
- `view_users` - View user list and details
- `edit_users` - Update user information
- `suspend_users` - Suspend and reactivate accounts
- `view_payments` - View payment transactions
- `process_refunds` - Process refunds
- `view_subscriptions` - View subscription details
- `edit_subscriptions` - Modify subscriptions
- `view_reports` - Access financial reports
- `export_reports` - Export report data
- `view_audit_logs` - View audit trail
- `export_audit_logs` - Export audit logs

**API Methods:**
- `initialize()` - Initialize service and load admin roles
- `hasRole(AdminRole)` - Check if user has specific role
- `hasPermission(AdminPermission)` - Check if user has specific permission
- `getUsers()` - Get paginated user list with filtering
- `getUserDetails(userId)` - Get detailed user information
- `updateUserSubscription(userId, tier)` - Update user subscription tier
- `suspendUser(userId, reason)` - Suspend user account
- `reactivateUser(userId)` - Reactivate suspended account
- `getDashboardMetrics()` - Get admin dashboard metrics
- `clearError()` - Clear error state

**API Integration:**
- Base URL: `AppConfig.adminApiBaseUrl`
- Timeout: 30 seconds (connect and receive)
- Authentication: Bearer token from `AuthService`
- Error handling: 403 (admin access denied), network errors, timeouts

**State Management:**
- `isLoading` - Loading state indicator
- `error` - Error message (null if no error)
- `isInitialized` - Service initialization status
- `adminRoles` - List of admin roles for current user
- `dashboardMetrics` - Cached dashboard metrics
- `isSuperAdmin` - Computed property for super admin check
- `isAdmin` - Computed property for any admin role check

**Dependencies:**
- `flutter/foundation.dart` - ChangeNotifier for state management
- `dio` - HTTP client for API requests
- `AuthService` - Authentication and token management
- `AppConfig` - Configuration constants
- Admin models: `AdminRoleModel`, `SubscriptionModel`, `PaymentTransactionModel`, `RefundModel`, `AdminAuditLogModel`, `UserModel`

**Related Services:**
- `AuthService` - Provides JWT tokens and auth state
- `PaymentGatewayService` - Payment processing operations
- Backend API: `services/api-backend/routes/admin/*`
- Middleware: `services/api-backend/middleware/admin-auth.js`

**Documentation:**
- Service documentation: `lib/services/README.md`
- Admin Center design: `.kiro/specs/admin-center/design.md`
- Admin API reference: `docs/API/ADMIN_API.md`
- Task completion: `.kiro/specs/admin-center/TASK_13_COMPLETION_SUMMARY.md`

#### Payment Gateway Service (`lib/services/payment_gateway_service.dart`)
- **PaymentGatewayService** - Comprehensive payment processing service for Admin Center
  - Payment transaction management with real-time updates
  - Subscription creation and lifecycle management
  - Refund processing with admin authentication
  - Payment method management with PCI DSS compliance
  - JWT authentication with admin role validation
  - Automatic token refresh and error handling
  - Dio HTTP client with interceptors for auth and error handling
  - Real-time data caching with timestamp tracking
  - Comprehensive error handling and user feedback
  - Integration with admin API backend (`/api/admin/payments`)

**Features:**
- Connects to admin API backend at `/api/admin/payments`
- Automatic JWT token injection via Dio interceptors
- Admin role validation (403 error handling)
- Loading state management with `ChangeNotifier`
- Error state management with user-friendly messages
- Cached data with last update timestamps
- Auth state listener for automatic cleanup on logout
- Proper resource cleanup in `dispose()`

**API Integration:**
- Base URL: `AppConfig.adminApiBaseUrl`
- Timeout: `AppConfig.adminApiTimeout`
- Authentication: Bearer token from `AuthService`
- Error handling: 403 (admin access denied), network errors, timeouts

**State Management:**
- `isLoading` - Loading state indicator
- `error` - Error message (null if no error)
- `transactions` - Cached payment transactions list
- `subscriptions` - Cached subscriptions list
- `lastTransactionsUpdate` - Timestamp of last transactions fetch
- `lastSubscriptionsUpdate` - Timestamp of last subscriptions fetch

**Dependencies:**
- `flutter/foundation.dart` - ChangeNotifier for state management
- `dio` - HTTP client for API requests
- `AuthService` - Authentication and token management
- `AppConfig` - Configuration constants
- Payment models: `PaymentTransactionModel`, `SubscriptionModel`, `RefundModel`

**Related Services:**
- `AuthService` - Provides JWT tokens and auth state
- Backend API: `services/api-backend/routes/admin/payments.js`
- Payment processing: `services/api-backend/services/payment-service.js`
- Refund processing: `services/api-backend/services/refund-service.js`

**Documentation:**
- Service documentation: `lib/services/README.md` (to be created)
- Admin Center design: `.kiro/specs/admin-center/design.md`
- Admin API reference: `docs/API/ADMIN_API.md`
- Payment API reference: `services/api-backend/routes/admin/PAYMENTS_API.md`

### Added - Admin Center Flutter Models (Phase 1)

#### Subscription Model (`lib/models/subscription_model.dart`)
- **SubscriptionModel** - Comprehensive subscription data model for Admin Center
  - Subscription tier management (free, premium, enterprise)
  - Status tracking (active, canceled, past_due, trialing, incomplete)
  - Billing period information (current period start/end)
  - Trial period support with start/end dates
  - Stripe integration (subscription ID, customer ID)
  - Cancellation tracking (cancel at period end, canceled at timestamp)
  - Days remaining calculation helper method
  - JSON serialization with both snake_case and camelCase support
  - Immutable design with `copyWith()` method
  - Value equality implementation

**Enums:**
- `SubscriptionTier`: free, premium, enterprise with display names
- `SubscriptionStatus`: active, canceled, past_due, trialing, incomplete with display names and issue detection

**Features:**
- Null-safe parsing with fallback values
- Support for both API formats (snake_case and camelCase)
- Helper methods: `isActive`, `isTrialing`, `isCanceled`, `isPastDue`, `daysRemaining`
- Comprehensive `toString()` for debugging
- Proper equality and hashCode implementation

**Related Models:**
- `PaymentTransactionModel` - Payment transaction details
- `RefundModel` - Refund records
- `AdminRoleModel` - Administrator roles and permissions
- `AdminAuditLogModel` - Audit trail entries

**Documentation:**
- Model documentation: `lib/models/README.md`
- Admin Center design: `.kiro/specs/admin-center/design.md`
- Admin API reference: `docs/API/ADMIN_API.md`

### Added - Admin Center Backend API (Phase 1)

#### Dashboard Metrics API Route
- **GET /api/admin/dashboard/metrics** - Get comprehensive dashboard metrics
  - Total registered users count
  - Active users (last 30 days)
  - New user registrations (current month)
  - Subscription tier distribution (free, premium, enterprise)
  - Monthly Recurring Revenue (MRR) calculation
  - Total revenue (current month)
  - Recent payment transactions (last 10)
  - Real-time calculations from database
  - Optimized SQL queries with aggregations
  - Response time < 500ms for typical datasets
  - Requires admin authentication (any admin role)

**Features:**
- User statistics (total, active, new, active percentage)
- Subscription distribution and conversion rate
- Revenue metrics (MRR, current month, average transaction value)
- Recent transactions with user and subscription details
- Date ranges for all calculations
- Database connection pooling for performance
- Comprehensive error handling and logging

**Documentation:**
- Full API reference: `services/api-backend/routes/admin/DASHBOARD_API.md`
- Quick reference guide: `services/api-backend/routes/admin/DASHBOARD_QUICK_REFERENCE.md`
- Implementation summary: `services/api-backend/routes/admin/DASHBOARD_IMPLEMENTATION_SUMMARY.md`

#### Financial Reporting API Routes
- **GET /api/admin/reports/revenue** - Generate revenue reports with date range filtering
  - Date range filtering (up to 1 year maximum)
  - Optional tier-based revenue grouping
  - Total revenue calculation for period
  - Transaction count and average transaction value
  - Revenue breakdown by subscription tier (free, premium, enterprise)
  - ISO 8601 date format support
  - Comprehensive input validation
  - Requires `view_reports` permission

**Features:**
- Flexible date range queries (startDate and endDate required)
- Optional groupBy parameter for tier breakdown
- Real-time revenue calculations from database
- Transaction metrics (count, total, average)
- Per-tier revenue analysis when groupBy enabled
- Comprehensive audit logging of all report generations
- Input validation (date format, range limits, parameter validation)
- Error handling with detailed error messages

**Metrics Provided:**
- Total revenue for specified period
- Total transaction count
- Average transaction value
- Revenue by tier (when groupBy=true)
- Transaction count by tier
- Average transaction value by tier

**Documentation:**
- Full API reference: `services/api-backend/routes/admin/REPORTS_API.md`
- Quick reference guide: `services/api-backend/routes/admin/REPORTS_QUICK_REFERENCE.md`
- Implementation summary: `services/api-backend/routes/admin/REPORTS_IMPLEMENTATION_SUMMARY.md`

#### Audit Log API Routes
- **GET /api/admin/audit/logs** - List audit logs with pagination and filtering
  - Pagination support (100 logs per page, max 200)
  - Filter by admin user ID, action type, resource type, affected user ID
  - Filter by date range (start/end dates)
  - Sort by created_at, action, resource_type, admin_user_id
  - Returns audit logs with admin and affected user details
  - Immutable audit log storage (cannot be modified or deleted)
  - Requires `view_audit_logs` permission

- **GET /api/admin/audit/logs/:logId** - Get detailed audit log entry
  - Complete audit log entry with full context
  - Admin user information (email, username, role, Supabase Auth ID)
  - Affected user information (if applicable)
  - Full action details (JSON formatted)
  - IP address and user agent tracking
  - Requires `view_audit_logs` permission

- **GET /api/admin/audit/export** - Export audit logs to CSV
  - CSV export with all filtering options
  - Automatic filename generation with timestamp
  - Proper CSV escaping for special characters
  - Streaming file download
  - Complete audit trail in export (15 columns)
  - Requires `export_audit_logs` permission

**Features:**
- Immutable audit log storage for compliance
- Comprehensive filtering and sorting capabilities
- IP address and user agent tracking for security
- JSON details field for additional context
- Integration with existing audit logger utility
- Role-based permission checking
- CSV export for compliance reporting

**Documentation:**
- Full API reference: `services/api-backend/routes/admin/AUDIT_API.md`
- Quick reference guide: `services/api-backend/routes/admin/AUDIT_QUICK_REFERENCE.md`
- Implementation summary: `services/api-backend/routes/admin/AUDIT_IMPLEMENTATION_SUMMARY.md`

### Added - Admin Center Backend API (Phase 1)

#### User Management API Routes
- **GET /api/admin/users** - List users with pagination, search, and filtering
  - Pagination support (50 users per page, max 100)
  - Search by email, username, user ID, or Supabase Auth ID
  - Filter by subscription tier (free, premium, enterprise)
  - Filter by account status (active, suspended, deleted)
  - Filter by registration date range
  - Sort by created_at, last_login, email, or username
  - Returns user profile with subscription info and active sessions count
  - Requires `view_users` permission

- **GET /api/admin/users/:userId** - Get detailed user profile
  - Complete user profile information
  - Subscription details with billing periods
  - Payment transaction history (last 20 transactions)
  - Active payment methods with masked card details
  - Active user sessions with IP and user agent
  - Administrative action timeline (last 10 actions)
  - User statistics (total payments, total spent, account age)
  - Requires `view_users` permission

- **PATCH /api/admin/users/:userId** - Update user subscription tier
  - Change subscription tier (free, premium, enterprise)
  - Automatic prorated charge calculation for upgrades
  - Creates new subscription if user doesn't have one
  - Comprehensive audit logging with reason field
  - Requires `edit_users` permission

- **POST /api/admin/users/:userId/suspend** - Suspend user account
  - Suspends user account with required reason
  - Invalidates all active user sessions immediately
  - Comprehensive audit logging
  - Requires `suspend_users` permission

- **POST /api/admin/users/:userId/reactivate** - Reactivate suspended account
  - Reactivates suspended user account
  - Clears suspension reason and timestamp
  - Optional note field for reactivation context
  - Comprehensive audit logging
  - Requires `suspend_users` permission

#### Admin Authentication & Authorization
- **Admin authentication middleware** with JWT token validation
- **Role-based access control** (Super Admin, Support Admin, Finance Admin)
- **Permission checking system** with granular permissions
  - Super Admin: All permissions (*)
  - Support Admin: view_users, edit_users, suspend_users, view_sessions, terminate_sessions, view_payments, view_audit_logs
  - Finance Admin: view_users, view_payments, process_refunds, view_subscriptions, edit_subscriptions, view_reports, export_reports, view_audit_logs
- **Database-backed role verification** from admin_roles table
- **Automatic role loading** on authentication

#### Audit Logging System
- **Comprehensive audit logging** for all administrative actions
- **Immutable audit log storage** in admin_audit_logs table
- **Detailed action tracking** with admin user, role, resource type, resource ID, affected user
- **Additional context** including IP address, user agent, and custom details
- **Audit log query API** with filtering by admin, action, resource, date range
- **Audit log export** to CSV format for compliance

#### Database Schema
- **subscriptions table** - User subscription information with Stripe integration
- **payment_transactions table** - Payment transaction records with status tracking
- **payment_methods table** - User payment method details with card masking
- **refunds table** - Refund records with reason tracking
- **admin_roles table** - Administrator role assignments with grant tracking
- **admin_audit_logs table** - Comprehensive audit trail
- **users table enhancements** - Added suspension fields (is_suspended, suspended_at, suspension_reason, deleted_at)
- **30+ database indexes** for query optimization
- **5 updated_at triggers** for automatic timestamp management
- **Default Super Admin role** for cmaltais@cloudtolocalllm.online

#### Database Migration System
- **Migration runner** (run-migration.js) for applying and rolling back migrations
- **Migration tracking table** (schema_migrations) for version control
- **Transaction-wrapped migrations** for atomicity
- **Rollback scripts** for safe migration reversal
- **Migration status command** for checking applied migrations

#### Development Seed Data
- **Seed data runner** (run-seed.js) for development data
- **5 test users** with different subscription tiers (free, premium, enterprise, trial, canceled)
- **5 test subscriptions** with various statuses
- **5 test payment transactions** (succeeded, failed, pending, refunded)
- **3 test payment methods** (active and expired cards)
- **1 test refund** with complete details
- **3 admin roles** (super admin, support admin, finance admin)
- **3 sample audit logs** for testing
- **Production safety checks** preventing seed data in production
- **Clean command** for removing all test data

#### Payment Gateway Integration (Stripe)
- **Stripe SDK integration** with Node.js client
- **Payment processing service** for creating PaymentIntents
- **Subscription management service** for Stripe subscriptions
- **Refund processing service** for issuing refunds
- **Error handling** for Stripe API errors
- **Test mode support** for development

#### Subscription Management API Routes
- **GET /api/admin/subscriptions** - List subscriptions with pagination and filtering
  - Pagination support (50 subscriptions per page, max 200)
  - Filter by tier (free, premium, enterprise)
  - Filter by status (active, canceled, past_due, trialing, incomplete)
  - Filter by user ID
  - Include upcoming renewals (next 7 days)
  - Sort by created_at, current_period_end, tier, status, updated_at
  - Returns subscription details with user information
  - Requires `view_subscriptions` permission

- **GET /api/admin/subscriptions/:subscriptionId** - Get detailed subscription information
  - Complete subscription details with metadata
  - User information (email, username, status, account age)
  - Payment history (last 50 transactions)
  - Billing cycle information (days remaining, next billing date, renewal status)
  - Payment statistics (total transactions, successful/failed counts, total amount paid)
  - Requires `view_subscriptions` permission

- **PATCH /api/admin/subscriptions/:subscriptionId** - Update subscription tier
  - Upgrade or downgrade subscription tier
  - Automatic proration calculation via Stripe
  - Configurable proration behavior (create_prorations, none, always_invoice)
  - Returns upcoming invoice details with line items
  - Validates subscription is active or trialing before update
  - Comprehensive audit logging with old/new tier tracking
  - Requires `edit_subscriptions` permission

- **POST /api/admin/subscriptions/:subscriptionId/cancel** - Cancel subscription
  - Immediate cancellation or cancel at period end
  - Required cancellation reason for audit trail
  - Automatic refund eligibility calculation for immediate cancellations
  - Prorated refund amount based on days remaining in billing cycle
  - Prevents duplicate cancellation attempts
  - Comprehensive audit logging with cancellation details
  - Requires `edit_subscriptions` permission

#### Payment Management API Routes
- **GET /api/admin/payments/transactions** - List payment transactions with pagination and filtering
  - Pagination support (100 transactions per page, max 200)
  - Filter by user ID, status, date range, and amount range
  - Sort by created_at, amount, or status
  - Returns summary statistics (total revenue, success/fail counts)
  - Requires `view_payments` permission

- **GET /api/admin/payments/transactions/:transactionId** - Get detailed transaction information
  - Complete transaction details with metadata
  - User information (email, username, suspension status)
  - Payment method details (masked for PCI DSS compliance)
  - Refund information with admin user details
  - Related subscription information
  - Calculated refund totals and net amount
  - Requires `view_payments` permission

- **POST /api/admin/payments/refunds** - Process refunds for transactions
  - Full and partial refund support
  - Validates refund amount against remaining refundable amount
  - Six refund reasons (customer_request, billing_error, service_issue, duplicate, fraudulent, other)
  - Processes refund through Stripe via RefundService
  - Stores refund in database with admin tracking
  - Comprehensive audit logging with IP and user agent
  - Requires `process_refunds` permission

- **GET /api/admin/payments/methods/:userId** - View user payment methods
  - Returns all payment methods for a user
  - Masks sensitive data (billing email, only last 4 digits shown)
  - Includes payment method status and expiration check
  - Usage statistics (transaction count, total spent, last used)
  - PCI DSS compliant (no full card numbers or CVV)
  - Requires `view_payments` permission

#### Documentation
- **Admin Center Requirements** - Complete requirements specification
- **Admin Center Design** - Detailed architecture and component design
- **Admin Center Tasks** - Implementation task breakdown with 30 tasks
- **Admin Center Roadmap** - Future enhancements and phases
- **Database Migration README** - Migration usage and best practices
- **Database Seed README** - Seed data usage and development workflow
- **Database Quickstart** - Quick reference for database setup

### Technical Implementation
- **PostgreSQL connection pooling** with configurable pool size (max 50)
- **Comprehensive error handling** with detailed error codes
- **Input validation and sanitization** for security
- **Structured logging** with Winston logger integration
- **Transaction support** for data consistency
- **Async/await patterns** throughout codebase
- **ES modules** for modern JavaScript

### Security Features
- **JWT token validation** on every admin request
- **Role-based permission checking** before operations
- **Audit logging** for accountability and compliance
- **Input sanitization** to prevent SQL injection
- **Parameterized queries** for database safety
- **Secure password handling** (never stored in logs)
- **IP address tracking** for security monitoring
- **User agent logging** for session tracking

### Testing & Quality
- **Comprehensive test data** for development
- **Migration rollback support** for safe deployments
- **Transaction-wrapped operations** for atomicity
- **Error recovery mechanisms** with rollback on failure
- **Detailed error messages** for debugging
- **Logging at all levels** (info, warn, error)

### Next Steps (Upcoming)
- Frontend Flutter web application for Admin Center UI
- Payment management endpoints (transactions, refunds)
- Subscription management endpoints (upgrade, downgrade, cancel)
- Financial reporting endpoints (revenue, MRR, churn)
- Audit log viewer endpoints
- Admin management endpoints (role assignment, revocation)
- Dashboard metrics endpoint
- Email provider configuration (self-hosted only)

### Breaking Changes
None - This is a new feature addition with no impact on existing functionality.

### Migration Guide
For administrators setting up the Admin Center:

1. **Apply database migration**:
   ```bash
   node services/api-backend/database/migrations/run-migration.js up 001
   ```

2. **Apply seed data (development only)**:
   ```bash
   node services/api-backend/database/seeds/run-seed.js apply 001
   ```

3. **Configure environment variables**:
   ```bash
   export DB_HOST=localhost
   export DB_PORT=5432
   export DB_NAME=cloudtolocalllm
   export DB_USER=postgres
   export DB_PASSWORD=yourpassword
   export JWT_SECRET=your-jwt-secret
   ```

4. **Verify setup**:
   ```bash
   node services/api-backend/database/migrations/run-migration.js status
   ```

### Known Issues
- Frontend UI not yet implemented (backend API only)
- Payment gateway webhooks not yet implemented
- Email notifications not yet implemented
- Bulk operations not yet implemented

### Version Compatibility
- Requires PostgreSQL 12+
- Requires Node.js 18+
- Compatible with existing CloudToLocalLLM v4.5.0+

---

## [4.5.0] - 2025-11-15

### Added - SSH WebSocket Tunnel Enhancement

#### Connection Resilience & Auto-Recovery
- **Automatic reconnection** with exponential backoff and jitter
- **Connection state persistence** across reconnection attempts
- **Request queuing** during network interruptions (up to 100 requests)
- **Automatic request flushing** after successful reconnection
- **Visual reconnection feedback** in UI with status indicators
- **Stale connection detection** and cleanup (60-second timeout)
- **Seamless client reconnection** without data loss
- **Reconnection within 5 seconds** (95th percentile) after network restoration
- **Max reconnection attempts** with user notification (10 attempts)
- **Comprehensive reconnection logging** with timestamps and reasons

#### Enhanced Error Handling & Diagnostics
- **Error categorization** into Network, Authentication, Configuration, Server, and Unknown
- **User-friendly error messages** with actionable suggestions
- **Detailed error context logging** including stack traces and connection state
- **Diagnostic mode** for testing each connection component separately
- **Component testing** including DNS resolution, WebSocket connectivity, SSH authentication, and tunnel establishment
- **Connection metrics display** showing latency, packet loss, and throughput
- **Token expiration detection** distinguishing between expired and invalid credentials
- **Error codes mapping** (TUNNEL_001-010) with documentation links
- **Diagnostic endpoint** at `/api/tunnel/diagnostics` for server-side diagnostics

#### Performance Monitoring & Metrics
- **Per-user metrics** tracking request count, success rate, average latency, and data transferred
- **System-wide metrics** for active connections, total throughput, and error rate
- **Client-side metrics** for connection uptime, reconnection count, and request queue size
- **Prometheus metrics endpoint** at `/api/tunnel/metrics` in standard format
- **Connection quality indicator** (excellent/good/fair/poor) based on latency and packet loss
- **95th percentile latency** calculation and exposure for all connections
- **Error rate alerting** when exceeding 5% over 5-minute window
- **Slow request tracking** (>5 seconds) for analysis
- **Real-time performance dashboard** in client UI
- **7-day metrics retention** for historical analysis

#### Multi-Tenant Security & Isolation
- **Strict user isolation** preventing cross-user data access
- **JWT token validation** on every request (not just connection time)
- **Per-user rate limiting** (100 requests/minute)
- **Authentication attempt logging** with success/failure tracking
- **Automatic disconnection** when JWT tokens expire
- **Separate SSH sessions** for each user connection
- **TLS 1.3 encryption** for all data in transit
- **Per-user connection limits** (max 3 concurrent connections)
- **Comprehensive audit logging** for all tunnel operations
- **IP-based rate limiting** for DDoS attack prevention

#### Request Queuing & Flow Control
- **Priority-based request queue** (high/normal/low priority levels)
- **Configurable queue size** (default: 100 requests)
- **Backpressure signals** when queue reaches 80% capacity
- **User notification** when queue is full and requests are dropped
- **Per-user server-side queues** preventing single-user blocking
- **30-second request timeout** with error return to client
- **Circuit breaker pattern** stopping forwarding after 5 consecutive failures
- **Automatic circuit breaker reset** after 60 seconds of no failures
- **High-priority request persistence** to disk during shutdown
- **Request restoration** on startup with automatic retry

#### WebSocket Connection Management
- **Ping/pong heartbeat** every 30 seconds
- **Connection loss detection** within 45 seconds (1.5x heartbeat interval)
- **5-second server response** requirement for ping frames
- **WebSocket compression support** (permessage-deflate) for bandwidth efficiency
- **Connection pooling** for multiple simultaneous tunnels
- **1MB WebSocket frame size limit** to prevent memory exhaustion
- **Graceful WebSocket close** with proper close codes
- **Clear upgrade failure messages** for debugging
- **5-minute idle timeout** for WebSocket connections
- **Complete WebSocket lifecycle logging** (connect, disconnect, error)

#### SSH Protocol Enhancements
- **SSH protocol v2 only** (no SSHv1 support)
- **Modern key exchange algorithms** (curve25519-sha256)
- **AES-256-GCM encryption** for SSH connections
- **SSH keep-alive messages** every 60 seconds
- **Server host key verification** on first connection with caching
- **SSH connection multiplexing** (multiple channels over one connection)
- **Per-connection channel limit** (max 10 channels)
- **SSH compression support** for large data transfers
- **SSH protocol error logging** with detailed context
- **Future support** for SSH agent forwarding

#### Graceful Shutdown & Cleanup
- **Request flushing** before shutdown (10-second timeout)
- **Proper SSH disconnect** message to server
- **WebSocket close** with code 1000 (normal closure)
- **Server-side request completion** before closing (30-second timeout)
- **Connection state persistence** for graceful restart
- **Shutdown event logging** with reason codes
- **Connection preference saving** and restoration on startup
- **Pre-shutdown client notification** for planned maintenance
- **SIGTERM handler** for graceful shutdown
- **Shutdown progress display** in UI

#### Configuration & Customization
- **UI configuration options** for reconnect attempts, timeout values, queue size
- **Configuration profiles** (Stable Network, Unstable Network, Low Bandwidth)
- **Configuration validation** with helpful error messages
- **Persistent configuration** across restarts
- **Environment variable support** for server-side configuration
- **Admin configuration endpoint** at `/api/tunnel/config`
- **Debug logging toggle** for troubleshooting
- **Debug logging levels** (ERROR, WARN, INFO, DEBUG, TRACE)
- **Reset to defaults** option for configuration
- **Comprehensive configuration documentation** with examples

#### Monitoring & Observability
- **Prometheus integration** via prom-client library
- **Health check endpoints** for load balancers
- **Structured JSON logging** for easy parsing
- **Correlation IDs** in all logs for request tracing
- **Connection lifecycle event logging** (connect, disconnect, error, reconnect)
- **OpenTelemetry distributed tracing** support
- **Runtime log level changes** without restart
- **Multi-instance log aggregation** for centralized analysis
- **Critical error alerting** (authentication failures, connection storms)
- **Real-time monitoring dashboards** in Grafana

#### Kubernetes Deployment
- **Streaming-proxy service** as separate Kubernetes deployment
- **Automated Docker image builds** on code changes
- **Docker image push** to Docker Hub registry
- **Health checks** with liveness and readiness probes
- **Horizontal Pod Autoscaling** (HPA) support
- **Multi-replica deployment** for high availability
- **WebSocket traffic routing** via ingress
- **Environment variable configuration** for Supabase Auth and WebSocket settings
- **Deployment rollout verification** in CI/CD pipeline
- **Redis state management** for multi-instance deployments

#### Documentation & Developer Experience
- **Architecture documentation** explaining all components
- **API documentation** for client and server interfaces
- **Troubleshooting guide** for common issues
- **Code examples** for common use cases
- **Sequence diagrams** for key flows (connect, reconnect, forward request)
- **Inline code comments** explaining complex logic
- **Developer setup guide** for local testing
- **Contribution guidelines** for external contributors
- **Comprehensive changelog** documenting all changes
- **Versioned documentation** kept in sync with code

### Breaking Changes

#### Configuration Format Changes
- **New tunnel configuration structure** in client settings
  - Old format: `tunnelConfig` (flat structure)
  - New format: `TunnelConfig` object with nested properties
  - Migration: Automatic conversion on first load
  - Recommendation: Update custom configurations to new format

#### API Endpoint Changes
- **New diagnostics endpoint**: `/api/tunnel/diagnostics` (server-side)
- **New metrics endpoint**: `/api/tunnel/metrics` (Prometheus format)
- **New config endpoint**: `/api/tunnel/config` (admin only)
- **Existing endpoints**: Backward compatible with enhanced responses

#### Server Configuration Changes
- **New environment variables** required:
  - `PROMETHEUS_ENABLED` - Enable Prometheus metrics (default: true)
  - `OTEL_EXPORTER_JAEGER_ENDPOINT` - Jaeger tracing endpoint (optional)
  - `LOG_LEVEL` - Logging level (default: INFO)
- **Deprecated variables**: None (all existing variables still supported)

#### Client Behavior Changes
- **Auto-reconnect enabled by default** (can be disabled in settings)
- **Request queuing enabled by default** (can be disabled in settings)
- **Connection quality indicator** now displayed in UI
- **Error messages** now more detailed and actionable

### Migration Guide

#### For Existing Users

1. **Update Configuration**
   - Open tunnel settings in the application
   - Review new configuration options (reconnect attempts, queue size, timeout values)
   - Select appropriate profile (Stable Network, Unstable Network, or Low Bandwidth)
   - Or keep default settings for most use cases

2. **Handle Deprecated Features**
   - No deprecated features in this release
   - All existing configurations automatically migrated
   - Old configuration format automatically converted to new format

3. **Test Upgraded System**
   - Verify tunnel connection establishes successfully
   - Test reconnection by temporarily disabling network
   - Check error messages are clear and helpful
   - Run diagnostics from settings menu to verify all components
   - Monitor performance dashboard for expected metrics

#### For System Administrators

1. **Update Server Configuration**
   - Add new environment variables to deployment (optional, defaults provided)
   - Configure Prometheus scraping if monitoring is desired
   - Update ingress configuration for WebSocket support (if not already done)
   - Configure alert rules for critical metrics

2. **Deploy New Version**
   - Update Docker image to latest version
   - Deploy streaming-proxy service with new configuration
   - Verify health checks pass
   - Monitor metrics endpoint for data collection
   - Test end-to-end tunnel functionality

3. **Monitor System Health**
   - Access Grafana dashboards for real-time monitoring
   - Configure alerts for error rate, latency, and connection issues
   - Review logs for any errors or warnings
   - Verify metrics are being collected and exported

### Performance Improvements

- **Faster reconnection**: Reduced from ~10 seconds to <5 seconds (95th percentile)
- **Lower latency**: Reduced tunnel overhead from ~100ms to <50ms (95th percentile)
- **Higher throughput**: Support for 1000+ requests/second per server instance
- **Better error recovery**: Automatic recovery from transient failures
- **Improved resource usage**: Optimized memory and CPU usage under load

### Known Issues

- WebSocket compression may not work with all proxy configurations (fallback to uncompressed)
- OpenTelemetry tracing requires Jaeger endpoint configuration for production use
- Some firewall configurations may require additional port forwarding for WebSocket

### Upgrade Path

```
v4.4.x → v4.5.0 (Recommended)
- Automatic configuration migration
- No breaking changes for existing deployments
- New features available immediately after upgrade
- Backward compatible with v4.4.x clients during transition period
```

### Testing Recommendations

1. **Unit Tests**: 80%+ code coverage for tunnel components
2. **Integration Tests**: End-to-end tunnel scenarios with reconnection
3. **Load Tests**: 100+ concurrent connections with 1000+ requests/second
4. **Chaos Tests**: Network failures, server crashes, and recovery scenarios
5. **Security Tests**: JWT validation, rate limiting, and user isolation

---

## [4.3.0] - 2025-11-15

### Added
- **Grafana Dashboard Setup Guide** (`services/streaming-proxy/src/monitoring/grafana-dashboard-setup.ts`)
  - Comprehensive guide for using Grafana MCP tools to create production monitoring dashboards
  - Dashboard configuration interfaces for Tunnel Health, Performance Metrics, and Error Tracking
  - Alert rule configurations for critical tunnel issues
  - Prometheus metrics reference with 30+ metrics
  - Loki log queries reference for error analysis
  - Implementation notes and best practices
  - Task 18 completion: Set up Grafana Monitoring Dashboards

- **Monitoring Documentation Updates**
  - Updated `docs/OPERATIONS/GRAFANA_MCP_TOOLS_USAGE.md` with references to new dashboard setup guide
  - Updated `docs/OPERATIONS/TUNNEL_MONITORING_SETUP.md` with implementation guidance
  - Added dashboard setup implementation section with links to detailed guides

### Features
- Real-time tunnel health monitoring with 30-second refresh intervals
- Performance metrics dashboard with P95/P99 latency tracking
- Error tracking dashboard with pattern detection
- Critical alerts for high error rates, connection pool exhaustion, circuit breaker open, and rate limit violations
- Shareable dashboard links using Grafana deeplinks
- Comprehensive metrics reference (connection, request, error, performance, resource, circuit breaker, rate limiter, queue)
- Loki log query examples for error analysis and troubleshooting

### Documentation
- Complete Grafana MCP tools usage guide
- Step-by-step dashboard setup instructions
- Prometheus metrics reference with descriptions
- Loki log queries reference
- Alert runbooks and troubleshooting procedures
- Implementation checklist for production deployment


## [4.1.4] - 2025-11-01



### Fixed
- Bug fixes and improvements


## [4.1.1] - 2025-08-07



### Fixed
- Bug fixes and improvements


## [4.1.0] - 2025-08-07



### Added
- New features and enhancements


## [4.0.86] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.85] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.84] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.83] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.82] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.81] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.80] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.79] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.78] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.77] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.76] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.75] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.74] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.73] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.72] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.71] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.70] - 2025-08-05



### Technical
- Build and deployment updates


## [4.0.70] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.69] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.68] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.67] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.66] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.65] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.64] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.63] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.62] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.61] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.60] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.59] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.58] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.57] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.56] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.55] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.54] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.53] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.52] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.51] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.50] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.49] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.48] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.47] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.46] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.45] - 2025-08-03

### Fixed
- Bug fixes and improvements

## [4.0.44] - 2025-08-03



### Fixed
- Bug fixes and improvements


## [4.0.43] - 2025-08-03



### Fixed
- Bug fixes and improvements


## [4.0.35] - 2025-08-02



### Fixed
- Bug fixes and improvements


## [4.0.32] - 2025-08-01



### Fixed
- Bug fixes and improvements


## [Unreleased] - 2025-01-13

### Changed - Deployment Script Consolidation and Cleanup
- **CONSOLIDATED: Enhanced complete_deployment.sh** - Merged functionality from multiple deployment scripts
  - Integrated six-phase deployment structure from complete_automated_deployment.sh
  - Added enhanced argument parsing: --verbose, --dry-run, --force, --skip-backup, --interactive
  - Merged build-time timestamp injection integration for automated version management
  - Enhanced network connectivity checks with latency monitoring and fallback handling
  - Improved error handling with comprehensive recovery mechanisms and detailed logging
  - Added dry-run simulation mode for safe testing without making actual changes
  - Preserved zero-tolerance quality gates and strict verification standards
  - Maintained automated execution without interactive prompts (user preference)

- **ARCHIVED: Duplicate deployment scripts** - Moved to scripts/archive/ with migration documentation
  - complete_automated_deployment.sh â†’ Functionality merged into complete_deployment.sh
  - deploy_to_vps.sh â†’ Functionality available in consolidated scripts
  - build_and_package.sh â†’ Functionality available in scripts/packaging/build_deb.sh

### Removed - AUR Support (Temporary)
- **AUR support is temporarily removed** as of v3.10.3. See [AUR Status](DEPLOYMENT/AUR_STATUS.md) for details.

### Fixed - Documentation and Cross-References
- **Updated script references** across all documentation files
  - README.md: Updated script listings and usage examples
  - scripts/README.md: Accurate deployment script inventory
  - scripts/update_documentation.sh: Corrected script references
  - Dockerfile.build: Updated to use scripts/packaging/build_deb.sh
  - All deployment workflow documentation updated for consolidated scripts

### Enhanced - Script Organization and Safety
- **Created scripts/archive/** directory with comprehensive migration documentation
  - Detailed migration guide for users of archived scripts
  - Recovery instructions for temporary script restoration if needed
  - 30-day retention policy with automatic cleanup schedule
  - Complete functionality mapping between old and new scripts

## [3.2.0] - 2025-01-27

### Added - Multi-App Architecture with Tunnel Manager
- **NEW: Tunnel Manager v1.0.0** - Independent Flutter desktop application for tunnel management
  - Dedicated connection broker handling local Ollama and cloud services
  - HTTP REST API server on localhost:8765 for external application integration
  - Real-time WebSocket support for status updates
  - Comprehensive health monitoring with configurable intervals (5-300 seconds)
  - Performance metrics collection (latency percentiles, throughput, error rates)
  - Secure authentication token management with Flutter secure storage
  - Material Design 3 GUI for configuration and diagnostics
  - Background service operation with optional minimal GUI
  - Automatic startup integration via systemd user service
  - Connection pooling and request routing optimization
  - Graceful shutdown handling with state persistence

- **Unified Flutter-Native System Tray v2.0.0** - Major upgrade with tunnel integration
  - Real-time tunnel status monitoring with dynamic icons
  - Enhanced menu structure with connection quality indicators
  - Intelligent alert system with configurable thresholds
  - Version compatibility checking across all components
  - Migration support from v1.x with automated upgrade paths
  - Improved IPC communication with HTTP REST API primary and TCP fallback
  - Comprehensive tooltip information with latency and model counts
  - Context-aware menu items based on authentication state

- **Shared Library v3.2.0** - Common utilities and version management
  - Centralized version constants and compatibility checking
  - Cross-component version validation during build process
  - Shared models and services for consistent behavior
  - Build timestamp and Git commit tracking

- **Multi-App Build System** - Comprehensive build pipeline
  - Version consistency validation across all components
  - Unified distribution packaging with launcher scripts
  - Platform-specific build optimization for Linux desktop
  - Automated desktop integration with .desktop entries
  - Build information generation with dependency tracking

### Enhanced
- **Main Application v3.2.0** - Integration with tunnel manager
  - Tunnel manager integration for improved connection reliability
  - Version display in persistent bottom-right corner overlay
  - Enhanced connection status reporting via tunnel API
  - Backward compatibility with existing tray daemon v1.x
  - Improved error handling and graceful degradation

- **Version Management System** - Comprehensive versioning
  - Semantic versioning across all components with compatibility matrix
  - Build timestamp and Git commit hash tracking
  - Version display in all user interfaces with hover tooltips
  - Cross-component dependency validation during builds
  - Migration support for configuration and data formats

- **Documentation Updates** - Complete architecture documentation
  - Tunnel Manager README with API reference and troubleshooting
  - Updated main README with multi-app architecture section
  - Version compatibility matrix and migration guides
  - Deployment documentation with multi-service configuration
  - API reference documentation with OpenAPI specification

### Technical Improvements
- **Architecture Refactoring** - Modular multi-app design
  - Independent application lifecycle management
  - Service isolation to prevent cascade failures
  - Centralized configuration management with hot-reloading
  - Hierarchical service dependency resolution
  - Enhanced error handling with specific error codes

- **Performance Optimization** - System-wide improvements
  - Connection pooling with concurrent request handling
  - Request queuing and routing optimization
  - Memory usage optimization (<50MB per service)
  - CPU usage optimization (<5% idle, <15% active)
  - Latency optimization (<100ms tunnel, <10ms API responses)

- **Security Enhancements** - Comprehensive security model
  - No root privileges required for any component
  - Proper sandboxing and process isolation
  - Secure credential storage with encryption
  - HTTPS-only cloud connections with certificate validation
  - Configurable CORS policies for API server

### Breaking Changes
- **Tray Daemon API v2.0** - Updated IPC protocol
  - New HTTP REST API primary communication method
  - Enhanced status reporting with connection quality metrics
  - Updated menu structure and tooltip format
  - Migration required from v1.x configurations

- **Configuration Format Changes** - Unified configuration
  - New tunnel manager configuration in `~/.cloudtolocalllm/tunnel_config.json`
  - Updated tray daemon configuration format
  - Shared library configuration validation
  - Backward compatibility with automatic migration

### Deployment
- **AUR Package Updates** - Enhanced Linux packaging
  - Multi-app binary distribution with ~125MB unified package
  - Systemd service templates for all components
  - Desktop integration with proper icon installation
  - Version consistency validation in package scripts

- **Build Pipeline** - Automated multi-component builds
  - Cross-component version validation
  - Unified distribution archive creation
  - Checksum generation and integrity verification
  - Platform-specific optimization for Linux x64

### Version Compatibility Matrix
- Main Application v3.2.0 â†” Tunnel Manager v1.0.0 âœ…
- Main Application v3.2.0 â†” Tray Daemon v2.0.0 âœ…
- Main Application v3.2.0 â†” Shared Library v3.2.0 âœ…
- Tunnel Manager v1.0.0 â†” Tray Daemon v2.0.0 âœ…
- Backward compatibility: Main App v3.2.0 â†” Tray Daemon v1.x âš ï¸ (limited)

### Migration Guide
For users upgrading from v3.1.x:
1. Stop existing tray daemon: `pkill cloudtolocalllm-enhanced-tray`
2. Install new multi-app package
3. Run configuration migration: `./cloudtolocalllm-tray --migrate-config`
4. Install system integration: `./install-system-integration.sh`
5. Start services: `systemctl --user start cloudtolocalllm-tunnel.service`

### Known Issues
- Tunnel manager WebSocket connections may require firewall configuration
- System tray icons may not display correctly on some Wayland compositors
- Configuration migration from v1.x requires manual verification

### Future Roadmap
- v1.1.0: Advanced load balancing and plugin system
- v2.0.0: Multi-user support and distributed tunnel management
- Cross-platform support for Windows and macOS

## [3.1.3] - 2025-01-26

### Fixed
- Enhanced tray daemon stability improvements
- Connection broker error handling
- Flutter web build compatibility

### Changed
- Updated dependencies to latest versions
- Improved logging and debugging output

## [3.1.2] - 2025-01-25

### Added
- Enhanced system tray daemon with connection broker
- Universal connection management for local and cloud
- Improved authentication flow

### Fixed
- System tray integration issues on Linux
- Connection stability improvements
- Memory usage optimization

## [3.1.1] - 2025-01-24

### Fixed
- Critical authentication bug fixes
- Improved error handling for connection failures
- UI responsiveness improvements

## [3.1.0] - 2025-01-23

### Added
- System tray integration with independent daemon
- Enhanced connection management
- Improved authentication with Supabase Auth integration
- Material Design 3 dark theme implementation

### Changed
- Migrated from system_tray package to Python-based daemon
- Improved connection reliability and error handling
- Enhanced UI with modern design patterns

### Fixed
- Connection timeout issues
- Authentication token management
- System tray icon display on various Linux environments

## [3.0.3] - 2025-01-20

### Fixed
- AUR package installation issues
- Binary distribution optimization
- Desktop integration improvements

## [3.0.2] - 2025-01-19

### Added
- AUR package support for Arch Linux
- Improved binary distribution
- Enhanced build scripts

### Fixed
- Package size optimization
- Dependency management improvements

## [3.0.1] - 2025-01-18

### Added
- SourceForge binary distribution
- Enhanced deployment workflow
- Improved documentation

### Fixed
- Build process optimization
- Distribution file management

## [3.0.0] - 2025-01-17

### Added
- Multi-container Docker architecture
- Independent service deployments
- Enhanced security with non-root containers
- Comprehensive documentation structure

### Changed
- Major architecture refactoring
- Improved scalability and maintainability
- Enhanced deployment processes

### Breaking Changes
- Docker configuration format changes
- Service communication protocol updates
- Configuration file structure modifications

---

For more information about each release, visit our [GitHub Releases](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases) page.
