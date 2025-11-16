# Email Provider Configuration - Quick Reference

## Overview
The Email Provider Configuration Tab allows administrators to configure email settings for self-hosted CloudToLocalLLM instances. This feature is automatically hidden for cloud-hosted instances.

## File Location
`lib/screens/admin/email_provider_config_tab.dart`

## Visibility Rules

### Self-Hosted Instances
- ✅ Tab is visible
- ✅ Full configuration available
- ✅ Test email functionality enabled

### Cloud-Hosted Instances
- ❌ Tab shows "Not Available" message
- ❌ Configuration form hidden
- ℹ️ Informative message explains cloud instances use managed email services

## Detection Method
```dart
const deploymentType = String.fromEnvironment('DEPLOYMENT_TYPE', defaultValue: 'cloud');
return deploymentType == 'self-hosted';
```

## Supported Email Providers

### 1. SMTP Server
**Use Case:** Custom SMTP server or Gmail/Outlook with app passwords

**Configuration:**
- Host: SMTP server address (e.g., smtp.gmail.com)
- Port: 587 (TLS) or 465 (SSL)
- Username: Email address or SMTP username
- Password: SMTP password or app password
- Encryption: TLS, SSL, or None

**Default Ports:**
- TLS: 587
- SSL: 465

### 2. SendGrid
**Use Case:** SendGrid email service

**Configuration:**
- API Endpoint: SendGrid API URL
- API Key: SendGrid API key
- API Secret: SendGrid API secret

### 3. Mailgun
**Use Case:** Mailgun email service

**Configuration:**
- API Endpoint: Mailgun API URL
- API Key: Mailgun API key
- API Secret: Mailgun API secret

### 4. AWS SES
**Use Case:** Amazon Simple Email Service

**Configuration:**
- API Endpoint: AWS SES endpoint
- API Key: AWS access key ID
- API Secret: AWS secret access key

## Form Fields

### Provider Selection
- Dropdown with 4 options
- Changes form fields dynamically
- Updates default port for SMTP

### SMTP Configuration (SMTP Provider Only)
- **Host:** Required, text input
- **Port:** Required, number input (1-65535)
- **Encryption:** Required, dropdown (TLS/SSL/None)
- **Username:** Required, text input
- **Password:** Required, password input with visibility toggle

### API Configuration (Other Providers)
- **API Endpoint:** Required, text input
- **API Key:** Required, text input
- **API Secret:** Required, password input with visibility toggle

### Test Email
- **Email Address:** Optional, email input with validation
- **Send Test Button:** Sends test email to verify configuration

## Validation Rules

### Host/Endpoint
- Required field
- Cannot be empty

### Port (SMTP Only)
- Required field
- Must be a number
- Must be between 1 and 65535

### Username/API Key
- Required field
- Cannot be empty

### Password/API Secret
- Required field
- Cannot be empty

### Test Email Address
- Optional field
- Must be valid email format if provided
- Regex: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`

## Security Features

### Password Protection
- Password fields are obscured by default
- Visibility toggle button (eye icon)
- Passwords should be encrypted in database (TODO)

### Encryption Warnings
- Warning displayed when "None" encryption is selected
- Recommends TLS or SSL for production
- Orange warning banner with icon

### Permission Checks
- `viewConfiguration` - Required to view configuration
- `editConfiguration` - Required to save configuration and send test emails
- Error messages displayed if permissions are missing

## User Experience

### Loading States
- Initial load: Shows spinner while loading configuration
- Saving: Button shows "Saving..." with spinner
- Sending test: Button shows "Sending..." with spinner

### Success Messages
- Green banner with checkmark icon
- Auto-dismiss after 3-5 seconds
- Manual dismiss with close button

### Error Messages
- Red banner with error icon
- Stays visible until manually dismissed
- Clear error descriptions

### Dynamic Behavior
- Port updates when encryption type changes
- Form fields change based on provider selection
- Validation updates based on provider

## API Integration (TODO)

### Load Configuration
```dart
GET /api/admin/email-config

Response:
{
  "provider": "smtp",
  "smtp_host": "smtp.gmail.com",
  "smtp_port": 587,
  "smtp_username": "admin@example.com",
  "encryption": "tls",
  "status": "connected"
}
```

### Save Configuration
```dart
POST /api/admin/email-config

Request:
{
  "provider": "smtp",
  "smtp_host": "smtp.gmail.com",
  "smtp_port": 587,
  "smtp_username": "admin@example.com",
  "smtp_password": "app_password",
  "encryption": "tls"
}
```

### Send Test Email
```dart
POST /api/admin/email-config/test

Request:
{
  "to": "test@example.com"
}

Response:
{
  "success": true,
  "message": "Test email sent successfully",
  "delivery_status": "sent"
}
```

## Common Use Cases

### Gmail with App Password
1. Select "SMTP Server" provider
2. Host: `smtp.gmail.com`
3. Port: `587`
4. Encryption: `TLS`
5. Username: Your Gmail address
6. Password: Gmail app password (not regular password)
7. Click "Send Test" to verify

### SendGrid
1. Select "SendGrid" provider
2. API Endpoint: SendGrid API URL
3. API Key: Your SendGrid API key
4. API Secret: Your SendGrid API secret
5. Click "Send Test" to verify

### AWS SES
1. Select "AWS SES" provider
2. API Endpoint: AWS SES endpoint for your region
3. API Key: AWS access key ID
4. API Secret: AWS secret access key
5. Click "Send Test" to verify

## Troubleshooting

### Test Email Fails
1. Verify credentials are correct
2. Check firewall/network settings
3. Verify SMTP port is not blocked
4. Check encryption type matches server requirements
5. Review error message for specific details

### Configuration Won't Save
1. Verify all required fields are filled
2. Check form validation errors
3. Verify you have `editConfiguration` permission
4. Check network connectivity
5. Review error message

### Tab Not Visible
1. Verify instance is self-hosted
2. Check `DEPLOYMENT_TYPE` environment variable
3. Verify it's set to `self-hosted` (not `cloud`)
4. Restart application if environment variable was changed

## Best Practices

### Security
- ✅ Always use TLS or SSL encryption
- ✅ Use app passwords instead of regular passwords
- ✅ Rotate credentials regularly
- ✅ Test configuration before saving
- ❌ Never use "None" encryption in production

### Configuration
- ✅ Test email after any configuration change
- ✅ Keep backup of working configuration
- ✅ Document custom SMTP settings
- ✅ Monitor email delivery rates

### Maintenance
- ✅ Review email logs regularly
- ✅ Update credentials when they expire
- ✅ Test email functionality periodically
- ✅ Monitor for delivery failures

## Future Enhancements

The following features will be added in a separate email provider spec:

1. **Email Templates**
   - Template management interface
   - Variable substitution
   - Preview functionality

2. **Email Queue**
   - Queue management
   - Retry logic
   - Failed email handling

3. **Email Analytics**
   - Delivery tracking
   - Open rates
   - Click rates
   - Bounce handling

4. **Advanced Features**
   - Multiple sender addresses
   - Email scheduling
   - Bulk email sending
   - Attachment support

## Related Documentation

- **Requirements:** `.kiro/specs/admin-center/requirements.md` (Requirement 19)
- **Design:** `.kiro/specs/admin-center/design.md` (Email Provider Configuration section)
- **Tasks:** `.kiro/specs/admin-center/tasks.md` (Task 23)
- **Completion Summary:** `.kiro/specs/admin-center/TASK_23_COMPLETION_SUMMARY.md`

## Support

For issues or questions about email provider configuration:
1. Check this quick reference guide
2. Review the completion summary document
3. Check the design document for detailed specifications
4. Review the requirements document for feature requirements
