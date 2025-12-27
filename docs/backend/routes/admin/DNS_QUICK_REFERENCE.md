# DNS API Quick Reference

## Endpoints Summary

| Method | Endpoint                        | Permission          | Purpose                              |
| ------ | ------------------------------- | ------------------- | ------------------------------------ |
| POST   | `/api/admin/dns/records`        | `manage_dns_config` | Create DNS record                    |
| GET    | `/api/admin/dns/records`        | `view_dns_config`   | List DNS records                     |
| PUT    | `/api/admin/dns/records/:id`    | `manage_dns_config` | Update DNS record                    |
| DELETE | `/api/admin/dns/records/:id`    | `manage_dns_config` | Delete DNS record                    |
| POST   | `/api/admin/dns/validate`       | `view_dns_config`   | Validate DNS records                 |
| GET    | `/api/admin/dns/google-records` | `view_dns_config`   | Get Google Workspace recommendations |
| POST   | `/api/admin/dns/setup-google`   | `manage_dns_config` | One-click Google Workspace setup     |

## Common Tasks

### Create MX Record

```bash
POST /api/admin/dns/records
{
  "recordType": "MX",
  "name": "mail.example.com",
  "value": "5 gmail-smtp-in.l.google.com",
  "ttl": 3600,
  "priority": 5
}
```

### Create SPF Record

```bash
POST /api/admin/dns/records
{
  "recordType": "TXT",
  "name": "example.com",
  "value": "v=spf1 include:_spf.google.com ~all",
  "ttl": 3600
}
```

### Create DKIM Record

```bash
POST /api/admin/dns/records
{
  "recordType": "TXT",
  "name": "default._domainkey.example.com",
  "value": "v=DKIM1; k=rsa; p=MIGfMA0BgkqhkiG9w0BAQEFAANGAADCgQ...",
  "ttl": 3600
}
```

### Create DMARC Record

```bash
POST /api/admin/dns/records
{
  "recordType": "TXT",
  "name": "_dmarc.example.com",
  "value": "v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com",
  "ttl": 3600
}
```

### List All Records

```bash
GET /api/admin/dns/records
```

### Filter Records by Type

```bash
GET /api/admin/dns/records?recordType=MX
```

### Update Record

```bash
PUT /api/admin/dns/records/:id
{
  "value": "10 alt1.gmail-smtp-in.l.google.com",
  "priority": 10
}
```

### Delete Record

```bash
DELETE /api/admin/dns/records/:id
```

### Validate Records

```bash
POST /api/admin/dns/validate
```

### Get Google Workspace Recommendations

```bash
GET /api/admin/dns/google-records?domain=example.com
```

### Setup Google Workspace DNS (One-Click)

```bash
POST /api/admin/dns/setup-google
{
  "domain": "example.com",
  "recordTypes": ["mx", "spf", "dmarc"]
}
```

## Valid Record Types

- `A` - IPv4 address
- `AAAA` - IPv6 address
- `CNAME` - Canonical name
- `MX` - Mail exchange
- `TXT` - Text record
- `SPF` - Sender Policy Framework
- `DKIM` - DomainKeys Identified Mail
- `DMARC` - Domain-based Message Authentication
- `NS` - Name server
- `SRV` - Service record

## TTL Values

- Minimum: 60 seconds
- Maximum: 86400 seconds (24 hours)
- Default: 3600 seconds (1 hour)

## Response Status Codes

- `201 Created` - Record created successfully
- `200 OK` - Request successful
- `400 Bad Request` - Invalid input
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Record not found
- `500 Internal Server Error` - Server error

## Error Codes

| Code                       | Meaning                       |
| -------------------------- | ----------------------------- |
| `MISSING_FIELDS`           | Required fields missing       |
| `INVALID_RECORD_TYPE`      | Invalid DNS record type       |
| `INVALID_TTL`              | TTL outside valid range       |
| `NO_UPDATE_FIELDS`         | No fields provided for update |
| `RECORD_CREATE_FAILED`     | Failed to create record       |
| `RECORD_UPDATE_FAILED`     | Failed to update record       |
| `RECORD_DELETE_FAILED`     | Failed to delete record       |
| `RECORDS_RETRIEVAL_FAILED` | Failed to retrieve records    |
| `VALIDATION_FAILED`        | Failed to validate records    |
| `RECOMMENDATIONS_FAILED`   | Failed to get recommendations |
| `SETUP_FAILED`             | Failed to setup DNS           |

## Rate Limits

- **Read Operations**: 200 req/min
- **Write Operations**: 50 req/min

## Authentication

All requests require:

- Valid JWT token in `Authorization: Bearer <token>` header
- Admin role
- Appropriate permission scope

## Audit Logging

All operations are logged with:

- Admin user ID
- Action performed
- Resource ID
- Timestamp
- IP address
- User agent

## Integration Points

- **Cloudflare API**: Uses `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ZONE_ID`
- **Database**: Stores records in `dns_records` table
- **Audit Logger**: Logs all operations for compliance
- **Admin Auth**: Validates permissions for each operation

## Related Services

- `CloudflareDNSService` - Handles Cloudflare API integration
- `GoogleWorkspaceService` - Provides email configuration
- `EmailConfigService` - Manages email settings
