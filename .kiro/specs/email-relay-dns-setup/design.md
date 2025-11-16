# Email Relay & DNS Configuration - Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Admin Center UI                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Email Provider Config Tab                           │   │
│  │  - Google Workspace OAuth setup                      │   │
│  │  - Service account configuration                     │   │
│  │  - SMTP relay fallback credentials                   │   │
│  │  - Test email sending                                │   │
│  │  - Email template management                         │   │
│  │  - Quota monitoring                                  │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  DNS Configuration Tab                               │   │
│  │  - MX, SPF, DKIM, DMARC records                       │   │
│  │  - Auto-populated from Google Workspace              │   │
│  │  - DNS provider selection                            │   │
│  │  - Record validation                                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    API Backend (Node.js)                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Admin Routes: /admin/email, /admin/dns              │   │
│  │  - Google Workspace OAuth handling                   │   │
│  │  - Configuration management                          │   │
│  │  - Credential encryption/decryption                  │   │
│  │  - DNS provider integration                          │   │
│  │  - Audit logging                                     │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Email Service                                       │   │
│  │  - Google Workspace Gmail API integration            │   │
│  │  - Queue management                                  │   │
│  │  - Template rendering                               │   │
│  │  - Delivery tracking                                 │   │
│  │  - Bounce handling via Gmail webhooks                │   │
│  │  - Fallback to SMTP relay if needed                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         ↓                              ↓
    ┌──────────────────┐      ┌──────────────────┐
    │ Google Workspace │      │ DNS Providers    │
    │ Gmail API        │      │ (Cloudflare,     │
    │ (Primary)        │      │  Azure, Route53) │
    └──────────────────┘      └──────────────────┘
         ↓                              ↓
    ┌──────────────────┐      ┌──────────────────┐
    │ SMTP Relay       │      │ DNS Records      │
    │ (Fallback)       │      │ (MX, SPF, etc)   │
    └──────────────────┘      └──────────────────┘
```

## Component Design

### 1. Google Workspace Integration Service

**Location**: `services/api-backend/services/google-workspace-service.js`

**Features**:
- OAuth 2.0 authentication with Google Workspace
- Gmail API integration for sending emails
- Service account support for system emails
- Quota monitoring and tracking
- Bounce/delivery webhook handling
- Token refresh and management

**Configuration**:
```javascript
{
  clientId: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  redirectUri: 'https://api.cloudtolocalllm.online/admin/email/oauth/callback',
  scopes: [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.readonly'
  ]
}
```

### 2. Email Relay Container (Kubernetes - Fallback)

**Dockerfile**: `config/docker/Dockerfile.email-relay`
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y postfix
COPY postfix-config/ /etc/postfix/
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
```

**Deployment**: `k8s/email-relay-deployment.yaml`
- Single replica (or HA with 2-3 replicas)
- ConfigMap for Postfix configuration
- Secret for SMTP credentials
- PersistentVolume for mail queue
- Service for internal SMTP access (port 25)
- Only deployed if Google Workspace is unavailable

### 3. DNS Configuration Service (Cloudflare)

**Location**: `services/api-backend/services/cloudflare-dns-service.js`

**Configuration**:
```javascript
{
  apiToken: process.env.CLOUDFLARE_API_TOKEN, // From GitHub Secrets
  apiUrl: 'https://api.cloudflare.com/client/v4',
  zoneId: process.env.CLOUDFLARE_ZONE_ID, // cloudtolocalllm.online
  methods: ['createRecord', 'updateRecord', 'deleteRecord', 'listRecords', 'validateRecords']
}
```

**Features**:
- Create/update/delete DNS records via Cloudflare API
- List all DNS records for the domain
- Validate DNS records (MX, SPF, DKIM, DMARC)
- Auto-retry on rate limiting
- Caching of DNS records (5 minute TTL)

**Auto-Population from Google Workspace**:
- Fetch recommended MX, SPF, DKIM records from Google Workspace
- Pre-populate DNS configuration tab
- Validate records match Google Workspace requirements
- One-click DNS setup

### 4. Email Configuration Service

**Location**: `services/api-backend/services/email-config-service.js`

**Responsibilities**:
- Store/retrieve Google Workspace OAuth tokens
- Encrypt/decrypt credentials
- Validate email configuration
- Manage email templates
- Track delivery metrics
- Monitor Google Workspace quota

### 5. Email Queue Service

**Location**: `services/api-backend/services/email-queue-service.js`

**Features**:
- Queue persistence (PostgreSQL)
- Retry logic with exponential backoff
- Dead letter queue
- Rate limiting (respecting Google Workspace limits)
- Delivery tracking
- Fallback to SMTP relay if Gmail API fails

### 6. Admin API Routes

**Location**: `services/api-backend/routes/admin/email.js`

**Endpoints**:
```
POST   /admin/email/oauth/start     - Start Google Workspace OAuth flow
POST   /admin/email/oauth/callback  - Handle Google OAuth callback
GET    /admin/email/config          - Get current configuration
DELETE /admin/email/config          - Delete configuration
POST   /admin/email/test            - Send test email via Google Workspace
GET    /admin/email/status          - Get email service status
GET    /admin/email/quota           - Get Google Workspace quota usage
GET    /admin/email/templates       - List email templates
POST   /admin/email/templates       - Create/update template
GET    /admin/email/metrics         - Get delivery metrics
POST   /admin/email/webhook         - Handle Gmail bounce/delivery webhooks
```

**Location**: `services/api-backend/routes/admin/dns.js`

**Endpoints**:
```
POST   /admin/dns/records           - Create DNS record via Cloudflare
GET    /admin/dns/records           - List DNS records from Cloudflare
PUT    /admin/dns/records/:id       - Update DNS record via Cloudflare
DELETE /admin/dns/records/:id       - Delete DNS record via Cloudflare
POST   /admin/dns/validate          - Validate DNS configuration via Cloudflare
GET    /admin/dns/google-records    - Get recommended records from Google Workspace
POST   /admin/dns/setup-google      - One-click setup of Google Workspace DNS records
```

### 7. Flutter UI Components

**Location**: `lib/screens/admin/email_provider_config_tab.dart`

**Features**:
- Provider selection dropdown
- SMTP credential input fields
- Test email button
- Configuration validation
- Success/error messages

**Location**: `lib/screens/admin/dns_config_tab.dart` (NEW)

**Features**:
- DNS provider selection
- Record type selection (MX, SPF, DKIM, DMARC)
- Record value input
- Validation status indicator
- Record management table

### 7. Database Schema

**Email Configuration Table**:
```sql
CREATE TABLE email_configurations (
  id UUID PRIMARY KEY,
  provider VARCHAR(50) NOT NULL,
  smtp_host VARCHAR(255),
  smtp_port INT,
  smtp_username VARCHAR(255),
  smtp_password_encrypted TEXT,
  from_address VARCHAR(255),
  from_name VARCHAR(255),
  tls_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id)
);

CREATE TABLE dns_records (
  id UUID PRIMARY KEY,
  provider VARCHAR(50) NOT NULL,
  record_type VARCHAR(10) NOT NULL,
  name VARCHAR(255) NOT NULL,
  value TEXT NOT NULL,
  ttl INT DEFAULT 3600,
  status VARCHAR(20),
  validated_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  created_by UUID REFERENCES users(id)
);

CREATE TABLE email_queue (
  id UUID PRIMARY KEY,
  recipient_email VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  template_name VARCHAR(100),
  template_data JSONB,
  status VARCHAR(20),
  retry_count INT DEFAULT 0,
  last_error TEXT,
  sent_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

## Data Flow

### Email Sending Flow
1. Application calls `EmailService.sendEmail()`
2. Email queued in database
3. Queue worker picks up email
4. Template rendered with data
5. Email sent via configured provider
6. Delivery status tracked
7. Retry on failure (exponential backoff)

### DNS Configuration Flow
1. Admin selects DNS provider
2. Admin enters provider credentials
3. Admin creates/updates DNS records
4. System validates records via DNS lookup
5. Records stored in database
6. Audit log created

## Security Considerations

1. **Credential Encryption**:
   - Use AES-256-GCM for SMTP password encryption
   - Store encryption key in Kubernetes Secret
   - Rotate keys periodically

2. **Rate Limiting**:
   - Per-user: 100 emails/hour
   - Per-system: 1000 emails/hour
   - Per-recipient: 5 emails/hour

3. **Audit Logging**:
   - Log all configuration changes
   - Log all email sends (recipient, subject, status)
   - Log DNS record changes

4. **DNS Validation**:
   - Verify DNS records before marking as active
   - Check SPF, DKIM, DMARC records
   - Alert on validation failures

## Monitoring & Observability

### Metrics
- `email_sent_total` - Total emails sent
- `email_failed_total` - Total failed emails
- `email_delivery_time_seconds` - Delivery time histogram
- `email_queue_depth` - Current queue size
- `dns_validation_status` - DNS record validation status

### Logs
- Email configuration changes
- Email send attempts
- DNS record updates
- SMTP connection errors
- Queue processing events

### Alerts
- Email service down
- Queue depth > 1000
- DNS validation failed
- SMTP authentication failed
- High email failure rate (>5%)
