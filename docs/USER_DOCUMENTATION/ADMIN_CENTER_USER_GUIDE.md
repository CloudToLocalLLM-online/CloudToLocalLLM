# Admin Center User Guide

## Table of Contents

1. [Getting Started](#getting-started)
2. [Accessing Admin Center](#accessing-admin-center)
3. [Dashboard Overview](#dashboard-overview)
4. [User Management](#user-management)
5. [Payment Management](#payment-management)
6. [Subscription Management](#subscription-management)
7. [Financial Reports](#financial-reports)
8. [Audit Logs](#audit-logs)
9. [Admin Management](#admin-management)
10. [Troubleshooting](#troubleshooting)

## Getting Started

### What is Admin Center?

Admin Center is a comprehensive management interface for CloudToLocalLLM administrators. It provides tools to manage users, process payments, handle refunds, manage subscriptions, generate financial reports, and monitor all administrative activities.

### Admin Roles and Permissions

There are three admin roles with different permission levels:

**Super Admin**
- Full access to all features
- Can manage other administrators
- Can view and modify all user data
- Can process payments and refunds
- Can access all reports and audit logs
- Default Super Admin: cmaltais@cloudtolocalllm.online

**Support Admin**
- User management (view, edit, suspend, reactivate)
- View-only access to payments
- View audit logs
- Cannot process refunds or manage subscriptions
- Cannot manage other administrators

**Finance Admin**
- Payment management (view transactions, process refunds)
- Subscription management (view, update, cancel)
- Financial reports and export
- View audit logs
- Cannot manage users or other administrators

### System Requirements

- Modern web browser (Chrome, Firefox, Safari, Edge)
- Active admin account with assigned role
- Stable internet connection
- JavaScript enabled



## Accessing Admin Center

### Step 1: Log In to CloudToLocalLLM

1. Open CloudToLocalLLM application
2. Log in with your admin account credentials
3. You must have an admin role assigned to access Admin Center

### Step 2: Navigate to Settings

1. Click the **Settings** icon in the main application
2. Look for the **Admin Center** button in the settings panel
3. If you don't see the Admin Center button, you don't have admin privileges

### Step 3: Open Admin Center

1. Click the **Admin Center** button
2. Admin Center will open in a new tab or window
3. You'll see the Admin Center dashboard with navigation sidebar

### Access Control

- Only users with assigned admin roles can access Admin Center
- Your role determines which features you can access
- If you try to access a feature you don't have permission for, you'll see an access denied message
- All access attempts are logged in the audit log

### Session Management

- Your Admin Center session inherits from your main CloudToLocalLLM session
- If you log out of the main app, your Admin Center session will also end
- Sessions expire after 24 hours of inactivity
- You'll be prompted to log in again if your session expires



## Dashboard Overview

### Dashboard Layout

The Dashboard is your main view when you open Admin Center. It displays key metrics and quick access to all features.

### Key Metrics

**Total Users**
- Shows the total number of registered users
- Updated in real-time
- Click to view detailed user list

**Active Subscriptions**
- Shows the number of active paid subscriptions
- Includes all subscription tiers (Free, Pro, Enterprise)
- Click to view subscription details

**Monthly Revenue**
- Shows total revenue for the current month
- Includes all successful payments
- Excludes refunded amounts

**Recent Transactions**
- Shows the 10 most recent payment transactions
- Displays transaction date, amount, user, and status
- Click on a transaction to view details

### Navigation Sidebar

The left sidebar provides quick access to all Admin Center features:

- **Dashboard** - Main overview and metrics
- **User Management** - Manage user accounts and subscriptions
- **Payment Management** - View transactions and process refunds
- **Subscription Management** - Manage user subscriptions
- **Financial Reports** - Generate and export financial reports
- **Audit Logs** - View all administrative activities
- **Admin Management** - Manage other administrators (Super Admin only)

### Refreshing Data

- Dashboard data refreshes automatically every 30 seconds
- Click the **Refresh** button to manually update data
- Some operations (like processing refunds) will automatically refresh relevant sections



## User Management

### Accessing User Management

1. Click **User Management** in the sidebar
2. You'll see a list of all registered users with their details

### User List View

The user list displays:
- **Email** - User's email address
- **Subscription Tier** - Current subscription level (Free, Pro, Enterprise)
- **Status** - Active or Suspended
- **Created Date** - When the account was created
- **Last Active** - Last login date and time

### Searching for Users

1. Use the **Search** box at the top of the user list
2. Type the user's email address or name
3. Results update as you type
4. Click on a user to view detailed information

### Filtering Users

Use the filter options to narrow down the user list:

- **Subscription Tier** - Filter by Free, Pro, or Enterprise
- **Status** - Filter by Active or Suspended users
- **Date Range** - Filter by account creation date

### Viewing User Details

1. Click on a user in the list
2. A detail panel opens showing:
   - Email address
   - Full name
   - Subscription tier and renewal date
   - Account creation date
   - Last login date
   - Account status
   - Payment methods on file

### Updating User Information

1. Open user details
2. Click the **Edit** button
3. Modify the user's information:
   - Subscription tier
   - Account status
4. Click **Save** to apply changes
5. The action is logged in the audit log

### Suspending a User Account

1. Open user details
2. Click the **Suspend Account** button
3. Confirm the suspension
4. The user will no longer be able to log in
5. All active sessions will be terminated

### Reactivating a Suspended Account

1. Open user details for a suspended user
2. Click the **Reactivate Account** button
3. Confirm the reactivation
4. The user can log in again immediately

### Viewing User Sessions

1. Open user details
2. Scroll to the **Active Sessions** section
3. View all active sessions for this user
4. Click **Terminate Session** to log out a specific session



## Payment Management

### Accessing Payment Management

1. Click **Payment Management** in the sidebar
2. You'll see a list of all payment transactions

### Payment Transactions

The transaction list displays:
- **Date** - Transaction date and time
- **User** - Customer email address
- **Amount** - Transaction amount
- **Status** - Succeeded, Failed, or Pending
- **Type** - One-time payment or subscription charge
- **Payment Method** - Card ending in (last 4 digits)

### Searching Transactions

1. Use the **Search** box to find transactions
2. Search by:
   - User email address
   - Transaction ID
   - Amount
3. Results update as you type

### Filtering Transactions

Use the filter options to narrow down transactions:

- **Status** - Succeeded, Failed, or Pending
- **Type** - One-time or Subscription
- **Date Range** - Filter by transaction date
- **Amount Range** - Filter by transaction amount

### Viewing Transaction Details

1. Click on a transaction in the list
2. A detail panel shows:
   - Transaction ID
   - User information
   - Amount and currency
   - Payment method details
   - Transaction status
   - Timestamp
   - Stripe transaction ID (for reference)

### Processing Refunds

**Important:** Only Finance Admins and Super Admins can process refunds.

#### Full Refund

1. Open a successful transaction
2. Click the **Refund** button
3. Select **Full Refund**
4. Enter a reason for the refund (required)
5. Click **Confirm Refund**
6. The refund will be processed immediately
7. The user's account will be credited

#### Partial Refund

1. Open a successful transaction
2. Click the **Refund** button
3. Select **Partial Refund**
4. Enter the refund amount (must be less than transaction amount)
5. Enter a reason for the refund
6. Click **Confirm Refund**
7. The partial refund will be processed
8. The user's account will be credited with the refund amount

### Refund Status

After processing a refund:
- **Pending** - Refund is being processed (usually 1-2 minutes)
- **Completed** - Refund has been successfully processed
- **Failed** - Refund failed (check error message for details)

### Viewing Refund History

1. Click on a transaction that has been refunded
2. Scroll to the **Refund History** section
3. View all refunds for this transaction
4. See refund amount, date, and status

### Payment Methods

1. Click the **Payment Methods** tab
2. View all payment methods on file for users
3. See card details (last 4 digits, expiration date)
4. View associated user account



## Subscription Management

### Accessing Subscription Management

1. Click **Subscription Management** in the sidebar
2. You'll see a list of all active subscriptions

### Subscription List View

The subscription list displays:
- **User** - Customer email address
- **Tier** - Subscription tier (Free, Pro, Enterprise)
- **Status** - Active, Cancelled, or Expired
- **Start Date** - When the subscription began
- **Renewal Date** - Next billing date
- **Amount** - Monthly subscription cost

### Searching Subscriptions

1. Use the **Search** box to find subscriptions
2. Search by:
   - User email address
   - Subscription ID
3. Results update as you type

### Filtering Subscriptions

Use the filter options to narrow down subscriptions:

- **Tier** - Filter by Free, Pro, or Enterprise
- **Status** - Filter by Active, Cancelled, or Expired
- **Date Range** - Filter by start date or renewal date

### Viewing Subscription Details

1. Click on a subscription in the list
2. A detail panel shows:
   - Subscription ID
   - User information
   - Current tier and price
   - Start date and renewal date
   - Billing cycle (monthly/annual)
   - Payment method
   - Subscription status
   - Billing history

### Changing Subscription Tier

**Important:** Only Finance Admins and Super Admins can change subscriptions.

1. Open a subscription
2. Click the **Change Tier** button
3. Select the new tier:
   - Free
   - Pro
   - Enterprise
4. Review the price change
5. Click **Confirm Change**
6. The subscription will be updated immediately
7. Billing will be adjusted for the new tier

### Cancelling a Subscription

1. Open a subscription
2. Click the **Cancel Subscription** button
3. Select the cancellation reason (optional)
4. Confirm the cancellation
5. The subscription will be cancelled immediately
6. The user will no longer be charged
7. Access to paid features will be revoked

### Reactivating a Cancelled Subscription

1. Open a cancelled subscription
2. Click the **Reactivate** button
3. Select the tier to reactivate
4. Confirm reactivation
5. The subscription will be active again
6. Billing will resume

### Viewing Billing History

1. Open a subscription
2. Scroll to the **Billing History** section
3. View all charges for this subscription
4. See charge date, amount, and status
5. Click on a charge to view transaction details

### Subscription Renewal

- Subscriptions automatically renew on the renewal date
- Users are charged the subscription amount
- If payment fails, the user is notified
- After 3 failed payment attempts, the subscription is cancelled



## Financial Reports

### Accessing Financial Reports

1. Click **Financial Reports** in the sidebar
2. You'll see report generation options

### Revenue Report

The Revenue Report shows financial performance over a selected time period.

#### Generating a Revenue Report

1. Click the **Revenue Report** tab
2. Select the date range:
   - Last 7 days
   - Last 30 days
   - Last 90 days
   - Custom date range
3. Click **Generate Report**
4. The report displays:
   - Total revenue for the period
   - Revenue by subscription tier (Free, Pro, Enterprise)
   - Daily revenue breakdown
   - Revenue trends chart
   - Average transaction value
   - Number of transactions

#### Revenue Report Metrics

- **Total Revenue** - Sum of all successful payments
- **Revenue by Tier** - Breakdown of revenue from each subscription tier
- **Daily Revenue** - Revenue for each day in the period
- **Average Transaction Value** - Mean transaction amount
- **Transaction Count** - Total number of transactions

### Subscription Metrics Report

The Subscription Metrics Report shows subscription performance and health.

#### Generating a Subscription Metrics Report

1. Click the **Subscription Metrics** tab
2. Select the date range
3. Click **Generate Report**
4. The report displays:
   - Monthly Recurring Revenue (MRR)
   - Churn rate (percentage of cancelled subscriptions)
   - Retention rate (percentage of retained subscriptions)
   - New subscriptions
   - Cancelled subscriptions
   - Subscription trends chart

#### Subscription Metrics Explained

- **MRR** - Expected monthly revenue from active subscriptions
- **Churn Rate** - Percentage of subscriptions cancelled in the period
- **Retention Rate** - Percentage of subscriptions that remained active
- **New Subscriptions** - Number of new subscriptions created
- **Cancelled Subscriptions** - Number of subscriptions cancelled

### Exporting Reports

#### Export to CSV

1. Generate a report
2. Click the **Export to CSV** button
3. The report will download as a CSV file
4. Open in Excel or Google Sheets for further analysis

#### Export to PDF

1. Generate a report
2. Click the **Export to PDF** button
3. The report will download as a PDF file
4. Print or share with stakeholders

### Report Scheduling

Reports can be scheduled to generate automatically:

1. Click **Schedule Report**
2. Select report type (Revenue or Subscription Metrics)
3. Select frequency (Daily, Weekly, Monthly)
4. Select recipients (email addresses)
5. Click **Save Schedule**
6. Reports will be generated and emailed automatically



## Audit Logs

### Accessing Audit Logs

1. Click **Audit Logs** in the sidebar
2. You'll see a list of all administrative activities

### Audit Log List View

The audit log displays:
- **Date/Time** - When the action occurred
- **Admin** - Which admin performed the action
- **Action** - What action was performed
- **Resource** - What was affected (user, payment, subscription)
- **Status** - Success or failure
- **IP Address** - Where the action came from

### Searching Audit Logs

1. Use the **Search** box to find specific log entries
2. Search by:
   - Admin email address
   - User email address
   - Action type
   - Resource ID
3. Results update as you type

### Filtering Audit Logs

Use the filter options to narrow down audit logs:

- **Date Range** - Filter by date
- **Admin User** - Filter by which admin performed the action
- **Action Type** - Filter by action (user_suspended, refund_processed, etc.)
- **Affected User** - Filter by which user was affected
- **Severity** - Filter by critical, warning, or info

### Viewing Log Details

1. Click on a log entry
2. A detail panel shows:
   - Full timestamp
   - Admin user information
   - Action performed
   - Resource details
   - Affected user (if applicable)
   - Action details (JSON formatted)
   - IP address and user agent
   - Request ID for support reference

### Audit Log Actions

Common actions logged in the audit log:

**User Management**
- user_created
- user_updated
- user_suspended
- user_reactivated
- user_deleted

**Payment Management**
- payment_processed
- refund_processed
- payment_failed
- payment_method_added
- payment_method_deleted

**Subscription Management**
- subscription_created
- subscription_updated
- subscription_cancelled
- subscription_reactivated
- tier_changed

**Admin Management**
- admin_role_assigned
- admin_role_revoked
- admin_created
- admin_deleted

### Exporting Audit Logs

1. Apply filters to narrow down the logs you want to export
2. Click the **Export** button
3. Select export format:
   - CSV - For spreadsheet analysis
   - JSON - For system integration
4. The file will download
5. Use for compliance, auditing, or investigation

### Audit Log Retention

- Audit logs are retained for 7 years
- Logs are immutable (cannot be modified or deleted)
- Logs are cryptographically signed for tamper detection
- Regular backups are maintained

### Compliance and Investigation

Use audit logs for:
- Investigating suspicious activities
- Compliance audits
- Security investigations
- User support (tracking what happened to an account)
- Billing disputes



## Admin Management

**Note:** This section is only available to Super Admins.

### Accessing Admin Management

1. Click **Admin Management** in the sidebar
2. You'll see a list of all administrators

### Admin List View

The admin list displays:
- **Email** - Admin's email address
- **Role** - Admin role (Super Admin, Support Admin, Finance Admin)
- **Granted By** - Which admin assigned this role
- **Granted Date** - When the role was assigned
- **Status** - Active or Revoked

### Adding a New Administrator

1. Click the **Add Admin** button
2. A dialog opens to search for users
3. Enter the user's email address
4. Select from the search results
5. Choose the admin role:
   - **Support Admin** - User management and view-only payments
   - **Finance Admin** - Payment and subscription management
6. Click **Confirm**
7. The user is now an administrator
8. The action is logged in the audit log

### Changing an Admin's Role

1. Click on an admin in the list
2. Click the **Change Role** button
3. Select the new role
4. Click **Confirm**
5. The role is updated immediately
6. The action is logged in the audit log

### Revoking Admin Access

1. Click on an admin in the list
2. Click the **Revoke Role** button
3. Confirm the revocation
4. The user is no longer an administrator
5. They can no longer access Admin Center
6. The action is logged in the audit log

### Viewing Admin Activity

1. Click on an admin in the list
2. Scroll to the **Recent Activity** section
3. View recent actions performed by this admin
4. Click on an action to view details

### Admin Permissions Reference

**Super Admin**
- Full access to all features
- Can manage other administrators
- Can view and modify all user data
- Can process payments and refunds
- Can access all reports and audit logs

**Support Admin**
- View and manage user accounts
- Suspend and reactivate users
- View user sessions and terminate them
- View-only access to payments
- View audit logs
- Cannot process refunds
- Cannot manage subscriptions
- Cannot manage other administrators

**Finance Admin**
- View all users (read-only)
- View and process payments
- Process refunds
- Manage subscriptions (view, update, cancel)
- Generate and export financial reports
- View audit logs
- Cannot manage users
- Cannot manage other administrators



## Troubleshooting

### Common Issues and Solutions

#### I can't see the Admin Center button in Settings

**Possible Causes:**
- You don't have an admin role assigned
- Your admin role has been revoked
- Your session has expired

**Solutions:**
1. Contact a Super Admin to verify your admin role
2. Log out and log back in
3. Check the audit logs to see if your role was revoked

#### I'm getting an "Access Denied" error

**Possible Causes:**
- You're trying to access a feature your role doesn't have permission for
- Your session has expired
- Your admin role has been revoked

**Solutions:**
1. Verify your admin role has permission for this feature
2. Log out and log back in
3. Contact a Super Admin if you need additional permissions

#### Refund processing is failing

**Possible Causes:**
- The transaction is too old (older than 90 days)
- The payment method is no longer valid
- Stripe API is experiencing issues
- The refund amount exceeds the transaction amount

**Solutions:**
1. Check the error message for specific details
2. Verify the refund amount is correct
3. Try again in a few minutes
4. Contact support if the issue persists

#### User search is not returning results

**Possible Causes:**
- The user doesn't exist
- You're searching by the wrong field
- The search term is incomplete

**Solutions:**
1. Try searching by email address
2. Use the full email address
3. Check the spelling
4. Try a partial search (first few letters)

#### Reports are not generating

**Possible Causes:**
- The date range is invalid
- There's no data for the selected period
- The system is experiencing high load

**Solutions:**
1. Verify the date range is correct
2. Try a different date range
3. Try again in a few minutes
4. Contact support if the issue persists

#### Session expired while working

**Possible Causes:**
- You've been inactive for more than 24 hours
- Your main CloudToLocalLLM session expired
- You logged out of the main app

**Solutions:**
1. Log back in to CloudToLocalLLM
2. Open Admin Center again
3. Your session will be restored

#### Payment information is not displaying correctly

**Possible Causes:**
- The payment data is still loading
- There's a display issue with your browser
- The payment information is corrupted

**Solutions:**
1. Wait a few seconds for data to load
2. Refresh the page
3. Clear your browser cache
4. Try a different browser
5. Contact support if the issue persists

### Getting Help

#### Contacting Support

If you encounter an issue not covered in this guide:

1. Note the error message and timestamp
2. Check the audit logs for related entries
3. Gather any relevant transaction or user IDs
4. Contact the support team with:
   - Description of the issue
   - Steps to reproduce
   - Error messages
   - Relevant IDs (transaction, user, subscription)
   - Timestamp of the issue

#### Reporting Security Issues

If you discover a security vulnerability:

1. Do not share details publicly
2. Contact the security team immediately
3. Provide:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Your contact information

### Performance Tips

#### Improving Admin Center Performance

1. **Use Filters** - Narrow down results to reduce data loading
2. **Search Efficiently** - Use specific search terms
3. **Limit Date Ranges** - Smaller date ranges load faster
4. **Clear Browser Cache** - Improves page load times
5. **Use Modern Browser** - Latest browser versions perform better
6. **Check Internet Connection** - Ensure stable connection

#### Optimizing Report Generation

1. **Use Smaller Date Ranges** - Reports generate faster
2. **Generate During Off-Peak Hours** - Less system load
3. **Export to CSV** - Faster than PDF export
4. **Schedule Reports** - Generate automatically during off-peak times

### Best Practices

#### Security Best Practices

1. **Never Share Credentials** - Keep your admin password secure
2. **Log Out When Done** - Always log out after your session
3. **Use Strong Passwords** - Use unique, complex passwords
4. **Enable 2FA** - Use two-factor authentication if available
5. **Review Audit Logs** - Regularly check for suspicious activity

#### Operational Best Practices

1. **Document Actions** - Keep notes of important changes
2. **Verify Before Acting** - Double-check before processing refunds
3. **Use Filters** - Narrow down results before bulk operations
4. **Test First** - Test with a small dataset before large operations
5. **Review Audit Logs** - Verify actions were completed successfully

#### Data Management Best Practices

1. **Regular Backups** - Ensure data is backed up regularly
2. **Export Reports** - Keep copies of important reports
3. **Archive Old Data** - Archive data older than 1 year
4. **Verify Data Accuracy** - Regularly audit data for accuracy
5. **Document Changes** - Keep records of significant changes

