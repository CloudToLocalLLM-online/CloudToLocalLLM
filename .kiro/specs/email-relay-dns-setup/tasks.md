# Email Relay & DNS Configuration - Implementation Tasks

## Phase 1: Backend Infrastructure

- [x] 1. Create database schema for email and DNS management





  - Create `email_configurations` table with Google Workspace OAuth token storage (encrypted)
  - Create `dns_records` table for Cloudflare DNS record tracking
  - Create `email_queue` table for email delivery queue
  - Create `email_delivery_logs` table for delivery tracking
  - Create `google_workspace_quota` table for quota monitoring
  - Add indexes on user_id, status, created_at for performance
  - _Requirements: 1.1, 1.2, 1.3_


- [x] 2. Implement Google Workspace Integration Service




  - Create `services/api-backend/services/google-workspace-service.js`
  - Implement OAuth 2.0 authentication flow with Google Workspace
  - Implement Gmail API integration for sending emails
  - Implement service account support for system-generated emails
  - Implement quota monitoring and tracking
  - Implement webhook handling for bounce/delivery notifications
  - Add comprehensive error handling and logging
  - _Requirements: 1.1, 1.2_

- [x] 3. Implement Cloudflare DNS Configuration Service





  - Create `services/api-backend/services/cloudflare-dns-service.js`
  - Implement Cloudflare API integration using `CLOUDFLARE_API_TOKEN` from GitHub Secrets
  - Implement DNS record CRUD operations (create, read, update, delete)
  - Implement DNS record validation against Google Workspace requirements
  - Implement record caching with 5-minute TTL
  - Implement rate limiting handling for Cloudflare API
  - Add error handling and logging
  - _Requirements: 1.3, 1.4_

- [x] 4. Implement Email Configuration Service





  - Create `services/api-backend/services/email-config-service.js`
  - Implement Google OAuth token encryption/decryption (AES-256-GCM)
  - Implement configuration validation and persistence
  - Implement email template management
  - Implement delivery metrics tracking
  - Add error handling and logging
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 5. Implement Email Queue Service




  - Create `services/api-backend/services/email-queue-service.js`
  - Implement queue persistence in PostgreSQL
  - Implement retry logic with exponential backoff
  - Implement dead letter queue for failed emails
  - Implement rate limiting (100/hour per user, 1000/hour per system)
  - Implement delivery tracking and status updates
  - Implement fallback to SMTP relay if Gmail API fails
  - _Requirements: 1.1, 1.2_

## Phase 2: API Routes

- [x] 6. Implement Email Configuration API Routes





  - Create `services/api-backend/routes/admin/email.js`
  - Implement `POST /admin/email/oauth/start` - Start Google OAuth flow
  - Implement `POST /admin/email/oauth/callback` - Handle OAuth callback
  - Implement `GET /admin/email/config` - Get current configuration
  - Implement `DELETE /admin/email/config` - Delete configuration
  - Implement `POST /admin/email/test` - Send test email
  - Implement `GET /admin/email/status` - Get email service status
  - Implement `GET /admin/email/quota` - Get Google Workspace quota usage
  - Add permission checks and audit logging
  - _Requirements: 2.1, 2.2, 2.3_
- [x] 7. Implement Cloudflare DNS API Routes



- [ ] 7. Implement Cloudflare DNS API Routes

  - Create `services/api-backend/routes/admin/dns.js`
  - Implement `POST /admin/dns/records` - Create DNS record via Cloudflare
  - Implement `GET /admin/dns/records` - List DNS records from Cloudflare
  - Implement `PUT /admin/dns/records/:id` - Update DNS record via Cloudflare
  - Implement `DELETE /admin/dns/records/:id` - Delete DNS record via Cloudflare
  - Implement `POST /admin/dns/validate` - Validate DNS configuration
  - Implement `GET /admin/dns/google-records` - Get Google Workspace DNS recommendations
  - Implement `POST /admin/dns/setup-google` - One-click Google Workspace setup
  - Add permission checks and audit logging
  - _Requirements: 2.1, 2.2, 2.3_
-

- [x] 8. Implement Email Template Management Routes




  - Add to `services/api-backend/routes/admin/email.js`
  - Implement `GET /admin/email/templates` - List email templates
  - Implement `POST /admin/email/templates` - Create/update template
  - Implement `PUT /admin/email/templates/:id` - Update specific template
  - Implement `DELETE /admin/email/templates/:id` - Delete template
  - Implement template validation and rendering
  - Add audit logging for template changes
  - _Requirements: 2.1, 2.2_

- [x] 9. Implement Email Metrics and Delivery Tracking Routes




  - Add to `services/api-backend/routes/admin/email.js`
  - Implement `GET /admin/email/metrics` - Get delivery metrics (sent, failed, bounced)
  - Implement `GET /admin/email/delivery-logs` - Get delivery logs with filtering
  - Implement time range filtering, status filtering, and pagination
  - Add audit logging for metric queries
  - _Requirements: 2.1, 2.2_

## Phase 3: Flutter UI Integration

- [x] 10. Connect Email Provider Configuration Tab to Backend





  - Update `lib/screens/admin/email_provider_config_tab.dart`
  - Implement API calls to load email configuration from backend
  - Implement API calls to save email configuration to backend
  - Implement API calls to send test emails
  - Connect form validation to backend validation
  - Add proper error handling and user feedback
  - _Requirements: 3.1, 3.2_
-

- [x] 11. Connect DNS Configuration Tab to Backend




  - Update `lib/screens/admin/dns_config_tab.dart`
  - Implement API calls to load DNS records from Cloudflare via backend
  - Implement API calls to create/update DNS records via backend
  - Implement API calls to delete DNS records via backend
  - Implement API calls to validate DNS records via backend
  - Connect form validation to backend validation
  - Add proper error handling and user feedback
  - _Requirements: 3.1, 3.2_

- [x] 12. Create Email Metrics Dashboard Tab




  - Create `lib/screens/admin/email_metrics_tab.dart`
  - Display email delivery metrics (sent, failed, bounced)
  - Display delivery time distribution chart
  - Display queue depth over time
  - Implement time range filtering
  - Implement status filtering
  - Add real-time metric updates
  - _Requirements: 3.1, 3.2_

- [x] 13. Create Email Template Editor UI




  - Create `lib/screens/admin/email_template_editor.dart`
  - Implement template list view with search/filter
  - Implement template editor with syntax highlighting
  - Implement template preview functionality
  - Implement template validation
  - Add CRUD operations (create, read, update, delete)
  - _Requirements: 3.1, 3.2_

## Phase 4: Email Relay Container (Optional - Local Deployments Only)

- [ ]* 14. Create Email Relay Container (Postfix Fallback for Local Deployments)
  - Create `config/docker/Dockerfile.email-relay`
  - Configure Postfix for SMTP relay
  - Create `config/postfix/main.cf` configuration
  - Create `config/postfix/master.cf` configuration
  - Create entrypoint script for container initialization
  - Test container locally
  - Note: Only required for local/self-hosted deployments; cloud deployments use Google Workspace
  - _Requirements: 1.4_

- [ ]* 15. Create Kubernetes Deployment Manifests for Email Relay (Local Deployments Only)
  - Create `k8s/email-relay-deployment.yaml`
  - Create `k8s/email-relay-service.yaml`
  - Create `k8s/email-relay-configmap.yaml`
  - Create `k8s/email-relay-secret.yaml`
  - Create `k8s/email-relay-pvc.yaml` for queue persistence
  - Add health checks and resource limits
  - Note: Only required for local/self-hosted Kubernetes deployments
  - _Requirements: 1.4_

- [ ]* 16. Set up Email Relay Monitoring (Local Deployments Only)
  - Add Prometheus metrics export to email relay container
  - Create Grafana dashboard for email relay metrics
  - Add alerting rules for email service health
  - Configure log aggregation for email relay logs
  - Note: Only required for local/self-hosted deployments
  - _Requirements: 1.4_

## Phase 5: Testing

- [ ]* 17. Write Integration Tests
  - Test email configuration API endpoints
  - Test DNS configuration API endpoints
  - Test email sending flow end-to-end
  - Test retry logic and exponential backoff
  - Test rate limiting enforcement
  - Test credential encryption/decryption
  - _Requirements: 2.1, 2.2, 2.3_

- [ ]* 18. Write End-to-End Tests
  - Test complete email sending flow from UI to delivery
  - Test DNS record creation and validation flow
  - Test admin UI workflows for email and DNS configuration
  - Test error handling and user feedback
  - Test audit logging for all operations
  - _Requirements: 2.1, 2.2, 2.3_

## Dependencies

**Core (Required for all deployments):**
- PostgreSQL (database)
- Google Workspace account with Gmail API enabled
- Cloudflare API token (CLOUDFLARE_API_TOKEN in GitHub Secrets)
- Node.js Express backend
- Flutter admin UI

**Optional (Local/Self-Hosted Deployments Only):**
- Postfix (for local email relay fallback)
- Kubernetes (for local/self-hosted deployments)

## Success Criteria

✅ Database schema created with all required tables
✅ Google Workspace Gmail API integration working
✅ Cloudflare DNS service operational
✅ Email configuration API endpoints functional
✅ DNS configuration API endpoints functional
✅ Flutter UI connected to backend APIs
✅ Email delivery metrics tracked and visible
✅ Google OAuth tokens encrypted and secure
✅ Audit logging for all configuration changes
✅ DNS validation working correctly
