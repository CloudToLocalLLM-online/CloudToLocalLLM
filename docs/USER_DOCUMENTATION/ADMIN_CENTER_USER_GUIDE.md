# Admin Center User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Dashboard Overview](#dashboard-overview)
4. [User Management](#user-management)
5. [Payment Management](#payment-management)
6. [Subscription Management](#subscription-management)
7. [Financial Reports](#financial-reports)
8. [Audit Log Viewer](#audit-log-viewer)
9. [Admin Management](#admin-management)
10. [Email Configuration](#email-configuration)
11. [DNS Configuration](#dns-configuration)
12. [Role-Based Permissions](#role-based-permissions)
13. [Troubleshooting](#troubleshooting)

---

## Introduction

The Admin Center is a secure web-based administrative interface for CloudToLocalLLM that enables authorized administrators to manage users, process payments, monitor system health, and perform administrative operations.

### Who Can Access the Admin Center?

Access to the Admin Center is restricted to users with administrator privileges. There are three administrator roles:

- **Super Admin**: Full access to all features including admin management
- **Support Admin**: Access to user management and account operations
- **Finance Admin**: Access to payment, subscription, and financial reporting features

### Key Features

- **User Management**: Search, view, and manage user accounts
- **Payment Processing**: View transactions, process refunds, manage payment methods
- **Subscription Management**: Upgrade, downgrade, and cancel user subscriptions
- **Financial Reporting**: Generate revenue reports and subscription metrics
- **Audit Logging**: Track all administrative actions for compliance
- **Admin Management**: Assign and revoke administrator roles (Super Admin only)
- **Email Configuration**: Configure email providers for self-hosted instances
- **DNS Configuration**: Manage DNS records for email authentication

---

## Getting Started

### Accessing the Admin Center

1. **Log in to CloudToLocalLLM** with your administrator account
2. **Navigate to Settings** by clicking the settings icon in the main application
3. **Locate the Admin Center button** in the settings pane (only visible to administrators)
4. **Click "Admin Center"** to open the administrative interface in a new browser tab

> **Note**: The Admin Center button is only visible if your account has administrator privileges. If you don't see this button, contact your Super Admin to request access.

### Admin Center Interface

The Admin Center interface consists of:

- **Sidebar Navigation**: Access different sections (Dashboard, Users, Payments, etc.)
- **Header Bar**: Displays current section title and refresh button
- **Main Content Area**: Shows the selected section's content
- **Exit Button**: Returns to the main application

### Navigation

Use the sidebar to navigate between different sections:

- **Dashboard**: Overview metrics and system health
- **Users**: User account management
- **Payments**: Transaction and refund management
- **Subscriptions**: Subscription tier management
- **Reports**: Financial reports and analytics
- **Audit Logs**: Administrative action history
- **Admins**: Administrator role management (Super Admin only)
- **Email Config**: Email provider settings (self-hosted only)
- **Email Metrics**: Email delivery statistics (self-hosted only)
- **DNS Config**: DNS record management (self-hosted only)

> **Note**: Navigation items are filtered based on your role. You will only see sections you have permission to access.

---

## Dashboard Overview

The Dashboard provides a quick overview of key metrics and system health.

### Key Metrics Cards

The dashboard displays four primary metrics:

1. **Total Users**: Total number of registered users
2. **Active Users**: Users who logged in within the last 30 days
3. **Monthly Recurring Revenue (MRR)**: Total recurring revenue from active subscriptions
4. **Current Month Revenue**: Total revenue generated in the current month

### Subscription Distribution

A visual chart shows the distribution of users across subscription tiers:

- **Free Tier**: Number and percentage of free users
- **Premium Tier**: Number and percentage of premium subscribers
- **Enterprise Tier**: Number and percentage of enterprise subscribers

The chart also displays the conversion rate (percentage of users with paid subscriptions).

### Recent Transactions

The dashboard shows the 10 most recent payment transactions with:

- Transaction ID
- User email
- Amount
- Status (Succeeded, Failed, Refunded, etc.)
- Timestamp

### Auto-Refresh

The dashboard automatically refreshes every 60 seconds to display the latest data. You can also manually refresh by clicking the refresh button in the header.

**Last Updated**: The dashboard displays when the data was last refreshed.

---

## User Management

The User Management section allows you to search, view, and manage user accounts.

### Searching for Users

1. **Navigate to the Users section** from the sidebar
2. **Use the search bar** to search by:
   - Email address
   - Username
   - User ID
3. **Apply filters** to narrow results:
   - **Subscription Tier**: Free, Premium, Enterprise
   - **Account Status**: Active, Suspended, Deleted
   - **Date Range**: Registration date range
4. **Click Search** to display results

### Viewing User Details

1. **Click on a user** in the search results table
2. **View comprehensive user information**:
   - Profile details (email, username, registration date)
   - Current subscription tier and status
   - Payment history with all transactions
   - Active sessions and login history
   - Administrative action timeline

### Updating Subscription Tiers

**Required Permission**: `edit_users`

1. **Open the user detail view**
2. **Click "Change Subscription"** button
3. **Select the new tier** (Free, Premium, or Enterprise)
4. **Review prorated charges** (if upgrading mid-cycle)
5. **Confirm the change**
6. **Verify the update** in the user's profile

> **Note**: Subscription changes are logged in the audit log and the user receives an email notification (if email is configured).

### Suspending User Accounts

**Required Permission**: `suspend_users`

1. **Open the user detail view**
2. **Click "Suspend Account"** button
3. **Select a reason** for suspension:
   - Terms of Service violation
   - Payment issues
   - Security concerns
   - Other (provide details)
4. **Enter additional details** (required)
5. **Confirm suspension**

**What happens when an account is suspended:**
- User cannot log in to the application
- All active sessions are terminated
- Subscriptions are paused (no billing)
- User receives suspension notification email

### Reactivating User Accounts

**Required Permission**: `suspend_users`

1. **Open the suspended user's detail view**
2. **Click "Reactivate Account"** button
3. **Confirm reactivation**
4. **User can log in again** and subscriptions resume

---


## Payment Management

The Payment Management section allows you to view transactions, process refunds, and manage payment methods.

### Viewing Payment Transactions

1. **Navigate to the Payments section** from the sidebar
2. **View the paginated transaction table** with:
   - Transaction ID
   - User email
   - Amount and currency
   - Payment method (last 4 digits)
   - Status
   - Timestamp
3. **Use pagination controls** to navigate through pages (100 transactions per page)

### Filtering Transactions

Apply filters to find specific transactions:

- **Date Range**: Select start and end dates
- **Status**: Pending, Succeeded, Failed, Refunded, Partially Refunded, Disputed
- **User**: Filter by user email or ID
- **Amount Range**: Minimum and maximum amounts
- **Sort By**: Date, Amount, or Status

### Viewing Transaction Details

1. **Click on a transaction** in the table
2. **View comprehensive transaction information**:
   - Transaction ID and Stripe Payment Intent ID
   - User information (email, username, account status)
   - Amount, currency, and payment method details
   - Transaction status and timestamp
   - Refund information (if applicable)
   - Subscription information (if related to a subscription)
   - Metadata and gateway response

### Processing Refunds

**Required Permission**: `process_refunds`

#### Full Refund

1. **Open the transaction detail view**
2. **Click "Process Refund"** button
3. **Select "Full Refund"**
4. **Choose a reason**:
   - Customer Request
   - Billing Error
   - Service Issue
   - Duplicate Charge
   - Fraudulent Transaction
   - Other
5. **Enter reason details** (optional but recommended)
6. **Confirm the refund**
7. **Wait for processing** (typically 5-10 seconds)
8. **Verify success** - transaction status updates to "Refunded"

#### Partial Refund

1. **Open the transaction detail view**
2. **Click "Process Refund"** button
3. **Select "Partial Refund"**
4. **Enter the refund amount** (must be less than the remaining refundable amount)
5. **Choose a reason** and enter details
6. **Confirm the refund**
7. **Verify success** - transaction status updates to "Partially Refunded"

> **Important**: Refunds are processed through Stripe and typically take 5-10 business days to appear in the customer's account. All refund actions are logged in the audit log.

### Viewing Payment Methods

**Required Permission**: `view_payments`

1. **Navigate to a user's detail view**
2. **Click "Payment Methods"** tab
3. **View all payment methods** associated with the user:
   - Payment method type (card, PayPal, etc.)
   - Card brand (Visa, Mastercard, etc.)
   - Last 4 digits (for security)
   - Expiration date
   - Billing email (masked)
   - Status (Active, Expired, Failed Verification)
   - Usage statistics (transaction count, total spent, last used)

> **Security Note**: Full card numbers and CVV codes are never displayed or stored. Only the last 4 digits are shown for identification purposes, in compliance with PCI DSS requirements.

---

## Subscription Management

The Subscription Management section allows you to view and manage user subscriptions.

### Viewing Subscriptions

1. **Navigate to the Subscriptions section** from the sidebar
2. **View the paginated subscription table** with:
   - User email
   - Subscription tier (Free, Premium, Enterprise)
   - Status (Active, Canceled, Past Due, Trialing)
   - Current period start and end dates
   - Next billing date
   - Monthly recurring revenue (MRR)
3. **Use pagination controls** to navigate through pages

### Filtering Subscriptions

Apply filters to find specific subscriptions:

- **Tier**: Free, Premium, Enterprise
- **Status**: Active, Canceled, Past Due, Trialing, Incomplete
- **User**: Filter by user email or ID
- **Upcoming Renewals**: Show subscriptions renewing within a specific timeframe

### Viewing Subscription Details

1. **Click on a subscription** in the table
2. **View comprehensive subscription information**:
   - User information
   - Subscription tier and status
   - Billing cycle information (start, end, next billing)
   - Payment history for this subscription
   - Stripe subscription ID and customer ID
   - Trial information (if applicable)
   - Cancellation information (if applicable)

### Upgrading Subscriptions

**Required Permission**: `edit_subscriptions`

1. **Open the subscription detail view**
2. **Click "Upgrade Subscription"** button
3. **Select the new tier** (must be higher than current tier)
4. **Review prorated charges**:
   - Remaining value of current subscription
   - Cost of new subscription
   - Prorated amount to charge
5. **Confirm the upgrade**
6. **Verify success** - subscription tier updates immediately

**What happens during an upgrade:**
- User is charged the prorated amount immediately
- New tier features are available immediately
- Next billing date remains the same
- Billing amount increases for future cycles

### Downgrading Subscriptions

**Required Permission**: `edit_subscriptions`

1. **Open the subscription detail view**
2. **Click "Downgrade Subscription"** button
3. **Select the new tier** (must be lower than current tier)
4. **Choose when to apply**:
   - **Immediate**: Downgrade takes effect immediately with prorated credit
   - **End of Period**: Downgrade takes effect at the end of the current billing cycle
5. **Review prorated credit** (if immediate)
6. **Confirm the downgrade**

**What happens during a downgrade:**
- **Immediate**: User receives prorated credit, new tier features apply immediately
- **End of Period**: User keeps current tier until billing cycle ends, then downgrades

### Canceling Subscriptions

**Required Permission**: `edit_subscriptions`

1. **Open the subscription detail view**
2. **Click "Cancel Subscription"** button
3. **Choose cancellation type**:
   - **Immediate**: Cancel immediately and stop billing
   - **End of Period**: Cancel at the end of the current billing cycle
4. **Confirm cancellation**

**What happens when a subscription is canceled:**
- **Immediate**: Access to paid features is revoked immediately, no refund issued
- **End of Period**: User keeps access until billing cycle ends, then reverts to Free tier
- Future billing is stopped
- User receives cancellation confirmation email

> **Note**: All subscription changes are logged in the audit log and trigger email notifications to the user.

---

## Financial Reports

The Financial Reports section allows you to generate and export financial reports.

### Report Types

Three types of reports are available:

1. **Revenue Report**: Total revenue, transaction count, average transaction value
2. **Subscription Metrics**: MRR trends, churn rate, retention metrics
3. **Transaction Report**: Detailed transaction list with filters

### Generating a Revenue Report

**Required Permission**: `view_reports`

1. **Navigate to the Reports section** from the sidebar
2. **Select "Revenue Report"** from the report type dropdown
3. **Choose a date range**:
   - Last 7 days
   - Last 30 days
   - Last 90 days
   - This month
   - Last month
   - Custom range
4. **Click "Generate Report"**
5. **View the report** with:
   - Total revenue for the period
   - Total transaction count
   - Average transaction value
   - Revenue breakdown by subscription tier (Free, Premium, Enterprise)
   - Visual charts showing revenue trends

### Generating a Subscription Metrics Report

**Required Permission**: `view_reports`

1. **Navigate to the Reports section**
2. **Select "Subscription Metrics"** from the report type dropdown
3. **Choose a date range**
4. **Click "Generate Report"**
5. **View the report** with:
   - Monthly Recurring Revenue (MRR) trends
   - Churn rate (percentage of canceled subscriptions)
   - Retention metrics (active subscriptions over time)
   - New subscriptions vs cancellations
   - Subscription tier distribution
   - Visual charts showing trends

### Exporting Reports

**Required Permission**: `export_reports`

1. **Generate a report** (as described above)
2. **Click "Export to CSV"** button
3. **Wait for file generation** (typically 1-5 seconds)
4. **Download the CSV file** automatically

**CSV Format:**
- Revenue Report: Date, Revenue, Transaction Count, Average Value, Tier Breakdown
- Subscription Metrics: Date, MRR, Active Subscriptions, New Subscriptions, Cancellations, Churn Rate
- Transaction Report: Transaction ID, User Email, Amount, Currency, Status, Payment Method, Timestamp

> **Note**: Report exports are logged in the audit log for compliance purposes.

---

## Audit Log Viewer

The Audit Log Viewer allows you to track all administrative actions for compliance and security.

### Viewing Audit Logs

**Required Permission**: `view_audit_logs`

1. **Navigate to the Audit Logs section** from the sidebar
2. **View the paginated audit log table** with:
   - Timestamp
   - Admin user (who performed the action)
   - Admin role (at the time of action)
   - Action type (e.g., "user_suspended", "refund_processed")
   - Resource type (e.g., "user", "transaction")
   - Affected user (if applicable)
   - IP address
3. **Use pagination controls** to navigate through pages

### Filtering Audit Logs

Apply filters to find specific log entries:

- **Date Range**: Select start and end dates
- **Admin User**: Filter by administrator email
- **Action Type**: Filter by specific actions (suspend, refund, subscription change, etc.)
- **Affected User**: Filter by the user who was affected by the action
- **Resource Type**: Filter by resource (user, transaction, subscription, etc.)

### Viewing Log Details

1. **Click on a log entry** in the table
2. **View comprehensive log information**:
   - Full timestamp with timezone
   - Admin user information (email, role)
   - Action type and description
   - Resource type and ID
   - Affected user information (if applicable)
   - Action details (JSON formatted)
   - IP address and user agent
   - Request metadata

### Exporting Audit Logs

**Required Permission**: `export_audit_logs`

1. **Apply filters** to select the logs you want to export
2. **Click "Export to CSV"** button
3. **Wait for file generation**
4. **Download the CSV file** automatically

**CSV Format:**
- Timestamp, Admin Email, Admin Role, Action Type, Resource Type, Resource ID, Affected User Email, IP Address, Details

> **Important**: Audit logs are immutable and cannot be deleted or modified. They are retained for a minimum of 7 years for compliance purposes.

---


## Admin Management

The Admin Management section allows Super Admins to assign and revoke administrator roles.

> **Note**: This section is only accessible to users with the Super Admin role.

### Viewing Administrators

**Required Permission**: Super Admin role

1. **Navigate to the Admins section** from the sidebar
2. **View the list of all administrators** with:
   - User email
   - Assigned roles (Super Admin, Support Admin, Finance Admin)
   - Role assignment date
   - Granted by (which Super Admin assigned the role)
   - Status (Active, Revoked)
3. **View admin activity summary** for each administrator

### Administrator Roles

Three administrator roles are available:

#### Super Admin
- **Full access** to all Admin Center features
- Can assign and revoke administrator roles
- Can manage other administrators
- Can access all sections and perform all actions
- Default role for the initial administrator (cmaltais@cloudtolocalllm.online)

#### Support Admin
- **User management**: View, edit, suspend, and reactivate user accounts
- **Session management**: View and terminate user sessions
- **Payment viewing**: View payment transactions (read-only)
- **Audit log viewing**: View audit logs (read-only)
- **Cannot**: Process refunds, manage subscriptions, delete users, manage admins

#### Finance Admin
- **User viewing**: View user accounts (read-only)
- **Payment management**: View transactions, process refunds
- **Subscription management**: View, upgrade, downgrade, and cancel subscriptions
- **Financial reports**: Generate and export revenue and subscription reports
- **Audit log viewing**: View audit logs (read-only)
- **Cannot**: Suspend users, delete users, manage admins

### Assigning Admin Roles

**Required Permission**: Super Admin role

1. **Click "Add Admin"** button
2. **Search for a user** by email address
3. **Select the user** from search results
4. **Choose a role**:
   - Support Admin
   - Finance Admin
   - Super Admin (use with caution)
5. **Review the permissions** that will be granted
6. **Confirm role assignment**
7. **User receives email notification** (if email is configured)

**What happens when a role is assigned:**
- User gains access to the Admin Center
- Admin Center button appears in their settings pane
- User can access sections based on their role permissions
- Action is logged in the audit log

> **Best Practice**: Assign the minimum role necessary for the user's responsibilities. Use Support Admin for customer service staff and Finance Admin for accounting staff.

### Revoking Admin Roles

**Required Permission**: Super Admin role

1. **Locate the administrator** in the admin list
2. **Click "Revoke Role"** button next to their role
3. **Confirm revocation**
4. **User loses admin access** immediately

**What happens when a role is revoked:**
- User can no longer access the Admin Center
- Admin Center button is hidden from their settings pane
- All active admin sessions are terminated
- Action is logged in the audit log
- User receives email notification (if email is configured)

> **Note**: You cannot revoke your own Super Admin role. Another Super Admin must revoke it.

### Viewing Admin Activity

1. **Click on an administrator** in the admin list
2. **View their activity timeline** with:
   - All actions performed
   - Timestamps
   - Affected users or resources
   - Action outcomes (success/failure)
3. **Filter activity** by date range or action type

---

## Email Configuration

The Email Configuration section allows administrators to configure email providers for sending transactional emails.

> **Note**: This section is only visible in self-hosted deployments. Cloud-hosted instances use pre-configured email services.

### Supported Email Providers

- **Google Workspace**: Gmail API with OAuth 2.0 authentication
- **SMTP Relay**: Generic SMTP server (SendGrid, Mailgun, AWS SES, etc.)

### Configuring Google Workspace

**Required Permission**: Super Admin role

1. **Navigate to the Email Config section** from the sidebar
2. **Click "Connect Google Workspace"** button
3. **Authenticate with Google**:
   - You will be redirected to Google OAuth consent screen
   - Sign in with your Google Workspace admin account
   - Grant permissions for sending emails
4. **Return to Admin Center** after authentication
5. **Verify connection status** - should show "Connected"
6. **View quota usage**:
   - Daily sending limit
   - Current usage
   - Remaining quota

### Configuring SMTP Relay

**Required Permission**: Super Admin role

1. **Navigate to the Email Config section**
2. **Select "SMTP Relay"** as the provider
3. **Enter SMTP settings**:
   - **Host**: SMTP server hostname (e.g., smtp.sendgrid.net)
   - **Port**: SMTP port (typically 587 for TLS, 465 for SSL)
   - **Username**: SMTP authentication username
   - **Password**: SMTP authentication password
   - **Encryption**: TLS, SSL, or None
   - **From Email**: Email address to send from
   - **From Name**: Display name for sent emails
4. **Click "Save Configuration"**
5. **Credentials are encrypted** before storage

### Testing Email Configuration

1. **After configuring an email provider**
2. **Click "Send Test Email"** button
3. **Enter recipient email** (defaults to your admin email)
4. **Click "Send"**
5. **Wait for delivery** (typically 5-10 seconds)
6. **View delivery status**:
   - **Success**: Email sent successfully
   - **Failure**: Error message with details

> **Troubleshooting**: If the test email fails, check your SMTP credentials, firewall settings, and ensure the SMTP server allows connections from your server's IP address.

### Email Templates

The system uses pre-configured email templates for:

- **Password Reset**: Sent when users request password resets
- **Account Verification**: Sent when new users register
- **Admin Notifications**: Sent for critical system events
- **Subscription Alerts**: Sent for subscription changes
- **Payment Confirmations**: Sent after successful payments

### Email Metrics

**Navigate to the Email Metrics section** to view:

- **Sent Count**: Total emails sent
- **Failed Count**: Total emails that failed to send
- **Bounced Count**: Total emails that bounced
- **Delivery Time**: Average time to deliver emails
- **Recent Emails**: List of recently sent emails with status

---

## DNS Configuration

The DNS Configuration section allows administrators to manage DNS records for email authentication.

> **Note**: This section is only visible in self-hosted deployments. Cloud-hosted instances use pre-configured DNS settings.

### Why DNS Configuration is Important

Proper DNS configuration is essential for:

- **Email Deliverability**: Ensures emails don't end up in spam folders
- **Email Authentication**: Proves emails are legitimately from your domain
- **Security**: Prevents email spoofing and phishing attacks

### Required DNS Records

For proper email authentication, you need:

1. **MX Records**: Mail exchange records for receiving emails
2. **SPF Record**: Sender Policy Framework for sender verification
3. **DKIM Record**: DomainKeys Identified Mail for message authentication
4. **DMARC Record**: Domain-based Message Authentication for policy enforcement

### Connecting DNS Provider

**Required Permission**: Super Admin role

1. **Navigate to the DNS Config section** from the sidebar
2. **Select your DNS provider**:
   - Cloudflare (recommended)
   - Azure DNS
   - AWS Route 53
   - Other (manual configuration)
3. **Enter API credentials**:
   - **Cloudflare**: API Token with DNS edit permissions
   - **Azure DNS**: Service Principal credentials
   - **AWS Route 53**: Access Key ID and Secret Access Key
4. **Click "Connect"**
5. **Verify connection** - should show "Connected"

### Getting Google Workspace DNS Records

If using Google Workspace for email:

1. **Ensure Google Workspace is connected** in Email Config
2. **Click "Get Google Workspace Records"** button
3. **DNS record fields are auto-populated** with recommended values
4. **Review the records** before creating them

### Creating DNS Records

**Required Permission**: Super Admin role

#### One-Click Setup (Recommended)

1. **After getting Google Workspace records**
2. **Click "One-Click Setup"** button
3. **All required DNS records are created automatically** via DNS provider API
4. **Wait for creation** (typically 5-10 seconds)
5. **Verify success** - records appear in the DNS records table

#### Manual Setup

1. **Click "Add DNS Record"** button
2. **Select record type**: MX, SPF, DKIM, DMARC, or CNAME
3. **Enter record details**:
   - **Name**: Record name (e.g., @ for root domain, _dmarc for DMARC)
   - **Value**: Record value (e.g., v=spf1 include:_spf.google.com ~all)
   - **TTL**: Time to live in seconds (default: 3600)
   - **Priority**: For MX records only (default: 10)
4. **Click "Create Record"**
5. **Record is created** via DNS provider API

### Validating DNS Records

1. **After creating DNS records**
2. **Click "Validate DNS Records"** button
3. **System performs DNS lookups** to verify records
4. **View validation status** for each record:
   - **Valid**: Record is correctly configured and propagated
   - **Invalid**: Record has incorrect value or format
   - **Pending**: Record is not yet propagated (wait 5-60 minutes)
5. **View validation timestamp** for each record

### DNS Propagation

After creating or updating DNS records:

- **Propagation time**: Typically 5-60 minutes, can take up to 48 hours
- **Check propagation status**: Use the "Validate DNS Records" button
- **Estimated time**: Displayed in the DNS Config section

### Deleting DNS Records

**Required Permission**: Super Admin role

1. **Locate the record** in the DNS records table
2. **Click "Delete"** button
3. **Confirm deletion**
4. **Record is removed** via DNS provider API

> **Warning**: Deleting DNS records can break email functionality. Only delete records if you're certain they're no longer needed.

---

## Role-Based Permissions

The Admin Center uses role-based access control to restrict features based on administrator roles.

### Permission Matrix

| Feature | Super Admin | Support Admin | Finance Admin |
|---------|-------------|---------------|---------------|
| **Dashboard** | ✅ | ✅ | ✅ |
| **View Users** | ✅ | ✅ | ✅ (read-only) |
| **Edit Users** | ✅ | ✅ | ❌ |
| **Suspend Users** | ✅ | ✅ | ❌ |
| **Delete Users** | ✅ | ❌ | ❌ |
| **View Payments** | ✅ | ✅ (read-only) | ✅ |
| **Process Refunds** | ✅ | ❌ | ✅ |
| **View Subscriptions** | ✅ | ✅ (read-only) | ✅ |
| **Edit Subscriptions** | ✅ | ❌ | ✅ |
| **View Reports** | ✅ | ❌ | ✅ |
| **Export Reports** | ✅ | ❌ | ✅ |
| **View Audit Logs** | ✅ | ✅ | ✅ |
| **Export Audit Logs** | ✅ | ❌ | ✅ |
| **Manage Admins** | ✅ | ❌ | ❌ |
| **Email Config** | ✅ | ❌ | ❌ |
| **DNS Config** | ✅ | ❌ | ❌ |

### Permission Descriptions

#### User Management Permissions

- **view_users**: View user accounts and profiles
- **edit_users**: Modify user profiles and subscription tiers
- **suspend_users**: Suspend and reactivate user accounts
- **delete_users**: Permanently delete user accounts (use with extreme caution)

#### Payment Permissions

- **view_payments**: View payment transactions and payment methods
- **process_refunds**: Process full and partial refunds

#### Subscription Permissions

- **view_subscriptions**: View user subscriptions
- **edit_subscriptions**: Upgrade, downgrade, and cancel subscriptions

#### Reporting Permissions

- **view_reports**: Generate financial reports
- **export_reports**: Export reports to CSV format

#### Audit Log Permissions

- **view_audit_logs**: View audit log entries
- **export_audit_logs**: Export audit logs to CSV format

#### Admin Management Permissions

- **manage_admins**: Assign and revoke administrator roles (Super Admin only)

### Checking Your Permissions

1. **Navigate to any section** in the Admin Center
2. **Sections you don't have access to** are hidden from the sidebar
3. **If you try to access a restricted feature**, you'll see an error message: "Insufficient permissions"
4. **Contact your Super Admin** to request additional permissions if needed

---

