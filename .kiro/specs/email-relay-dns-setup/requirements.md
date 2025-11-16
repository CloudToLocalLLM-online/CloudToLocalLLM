# Email Relay & DNS Configuration - Requirements

## Overview
Implement a containerized email relay service with DNS configuration management for the CloudToLocalLLM platform. This enables transactional emails (password resets, notifications, admin alerts) and DNS record management for email authentication.

## Functional Requirements

### 1. Google Workspace Integration (Primary)
- **Service**: Google Workspace SMTP relay via Gmail API
- **Purpose**: Handle outbound email delivery using Google Workspace
- **Features**:
  - OAuth 2.0 authentication with Google Workspace
  - Gmail API for sending emails
  - SMTP relay fallback (smtp.gmail.com:587)
  - Service account support for system emails
  - Rate limiting per sender (Google Workspace limits)
  - Bounce handling via Gmail webhooks
  - Queue management
  - Logging and monitoring

### 2. Email Relay Container (Fallback)
- **Service**: Postfix-based SMTP relay container (optional fallback)
- **Purpose**: Handle outbound email delivery if Google Workspace is unavailable
- **Features**:
  - SMTP authentication support
  - TLS/SSL encryption
  - Rate limiting per sender
  - Bounce handling
  - Queue management
  - Logging and monitoring

### 3. DNS Configuration Management
- **Primary Provider**: Cloudflare (API key in GitHub Secrets)
- **Records to manage**:
  - MX records (mail exchange) - pointing to Google Workspace
  - SPF records (Sender Policy Framework) - Google Workspace SPF
  - DKIM records (DomainKeys Identified Mail) - Google Workspace DKIM
  - DMARC records (Domain-based Message Authentication)
  - CNAME records for mail server

- **Cloudflare Integration**:
  - Use existing `CLOUDFLARE_API_TOKEN` from GitHub Secrets
  - Automatic DNS record creation/update
  - DNS validation via Cloudflare API
  - Zone management for cloudtolocalllm.online domain

### 4. Email Configuration UI
- **Admin panel** for:
  - Google Workspace OAuth setup and authentication
  - Service account configuration (for system emails)
  - SMTP relay credentials (fallback)
  - DNS record configuration (auto-populated from Google Workspace)
  - Test email sending
  - Email template management
  - Bounce/delivery tracking
  - Google Workspace quota monitoring

### 5. Email Templates
- Password reset
- Account verification
- Admin notifications
- Subscription alerts
- Payment confirmations
- System alerts
- All sent from Google Workspace account

## Non-Functional Requirements

### Security
- Encrypt SMTP credentials at rest
- Use TLS for all SMTP connections
- Validate DNS records before activation
- Rate limit email sending (100/hour per user, 1000/hour per system)
- Audit log all email configuration changes

### Reliability
- Email queue persistence
- Retry logic (exponential backoff)
- Dead letter queue for failed emails
- Health checks for email service
- Fallback to alternative providers

### Performance
- Email delivery within 5 seconds
- Queue processing: 100+ emails/second
- DNS lookup caching (5 minute TTL)
- Connection pooling for SMTP

### Monitoring
- Email delivery metrics (sent, failed, bounced)
- SMTP connection health
- DNS record validation status
- Queue depth monitoring
- Delivery time percentiles (p50, p95, p99)

## Integration Points

### Backend API
- `POST /admin/email/config` - Save email configuration (Google Workspace OAuth)
- `GET /admin/email/config` - Get current configuration
- `POST /admin/email/oauth/callback` - Handle Google OAuth callback
- `POST /admin/email/test` - Send test email via Google Workspace
- `GET /admin/email/status` - Get email service status (Google Workspace quota)
- `GET /admin/email/quota` - Get Google Workspace quota usage
- `POST /admin/dns/records` - Create/update DNS records via Cloudflare
- `GET /admin/dns/records` - List DNS records from Cloudflare
- `DELETE /admin/dns/records/:id` - Delete DNS record from Cloudflare
- `POST /admin/dns/validate` - Validate DNS configuration via Cloudflare
- `GET /admin/dns/google-records` - Get recommended records from Google Workspace
- `POST /admin/email/webhook` - Handle Gmail bounce/delivery webhooks

### Frontend UI
- Email provider configuration tab in Admin Center
- DNS record management interface
- Email template editor
- Delivery tracking dashboard

### Kubernetes
- Email relay deployment
- ConfigMap for email templates
- Secret for SMTP credentials
- PersistentVolume for email queue
- Service for internal SMTP access

## Success Criteria

1. ✅ Email relay container deployed and operational
2. ✅ DNS records automatically configured via admin panel
3. ✅ Test emails sent successfully within 5 seconds
4. ✅ Email delivery metrics tracked and visible in dashboard
5. ✅ All email templates rendered correctly
6. ✅ SMTP credentials encrypted and secure
7. ✅ Bounce handling and retry logic working
8. ✅ Admin audit logs for all email configuration changes
