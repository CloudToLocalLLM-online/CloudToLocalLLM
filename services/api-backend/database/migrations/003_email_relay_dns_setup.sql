-- Email Relay & DNS Configuration Database Migration
-- Version: 003
-- Description: Creates tables for email relay service and DNS configuration management
--              including email configurations, DNS records, email queue, delivery logs,
--              and Google Workspace quota tracking
-- Requirements: 1.1, 1.2, 1.3

-- Enable required extensions (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- EMAIL CONFIGURATIONS TABLE
-- ============================================================================
-- Stores email provider configuration including Google Workspace OAuth tokens
CREATE TABLE IF NOT EXISTS email_configurations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL CHECK (provider IN ('google_workspace', 'smtp_relay', 'sendgrid')),
  
  -- Google Workspace OAuth configuration
  google_oauth_token_encrypted TEXT,  -- Encrypted OAuth access token
  google_oauth_refresh_token_encrypted TEXT,  -- Encrypted refresh token
  google_service_account_encrypted TEXT,  -- Encrypted service account JSON
  google_workspace_domain VARCHAR(255),  -- Domain for Google Workspace
  
  -- SMTP relay configuration (fallback)
  smtp_host VARCHAR(255),
  smtp_port INT,
  smtp_username VARCHAR(255),
  smtp_password_encrypted TEXT,  -- Encrypted SMTP password
  
  -- Email configuration
  from_address VARCHAR(255) NOT NULL,
  from_name VARCHAR(255),
  reply_to_address VARCHAR(255),
  
  -- Connection settings
  tls_enabled BOOLEAN DEFAULT true,
  verify_ssl BOOLEAN DEFAULT true,
  
  -- Status and metadata
  is_active BOOLEAN DEFAULT false,
  is_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMPTZ,
  last_tested_at TIMESTAMPTZ,
  last_test_status VARCHAR(20),  -- 'success', 'failed'
  last_test_error TEXT,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for email_configurations
CREATE INDEX IF NOT EXISTS idx_email_configurations_user_id ON email_configurations(user_id);
CREATE INDEX IF NOT EXISTS idx_email_configurations_provider ON email_configurations(provider);
CREATE INDEX IF NOT EXISTS idx_email_configurations_is_active ON email_configurations(is_active);
CREATE INDEX IF NOT EXISTS idx_email_configurations_is_verified ON email_configurations(is_verified);
CREATE INDEX IF NOT EXISTS idx_email_configurations_created_at ON email_configurations(created_at);

-- ============================================================================
-- DNS RECORDS TABLE
-- ============================================================================
-- Stores DNS records managed via Cloudflare or other DNS providers
CREATE TABLE IF NOT EXISTS dns_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL CHECK (provider IN ('cloudflare', 'route53', 'azure_dns')),
  provider_record_id VARCHAR(255),  -- ID from DNS provider (e.g., Cloudflare record ID)
  
  -- DNS record details
  record_type VARCHAR(10) NOT NULL CHECK (record_type IN ('A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SPF', 'DKIM', 'DMARC')),
  name VARCHAR(255) NOT NULL,  -- Full domain name (e.g., mail.example.com)
  value TEXT NOT NULL,  -- Record value
  ttl INT DEFAULT 3600,
  priority INT,  -- For MX records
  
  -- Validation and status
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'failed', 'invalid')),
  validation_status VARCHAR(20),  -- 'valid', 'invalid', 'pending'
  validated_at TIMESTAMPTZ,
  validation_error TEXT,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for dns_records
CREATE INDEX IF NOT EXISTS idx_dns_records_user_id ON dns_records(user_id);
CREATE INDEX IF NOT EXISTS idx_dns_records_provider ON dns_records(provider);
CREATE INDEX IF NOT EXISTS idx_dns_records_record_type ON dns_records(record_type);
CREATE INDEX IF NOT EXISTS idx_dns_records_name ON dns_records(name);
CREATE INDEX IF NOT EXISTS idx_dns_records_status ON dns_records(status);
CREATE INDEX IF NOT EXISTS idx_dns_records_created_at ON dns_records(created_at);

-- ============================================================================
-- EMAIL QUEUE TABLE
-- ============================================================================
-- Stores pending and processed emails for delivery tracking
CREATE TABLE IF NOT EXISTS email_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Email details
  recipient_email VARCHAR(255) NOT NULL,
  recipient_name VARCHAR(255),
  subject VARCHAR(255) NOT NULL,
  
  -- Template information
  template_name VARCHAR(100),
  template_data JSONB DEFAULT '{}'::jsonb,
  
  -- Email content
  html_body TEXT,
  text_body TEXT,
  
  -- Delivery tracking
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'queued', 'sending', 'sent', 'failed', 'bounced', 'spam')),
  retry_count INT DEFAULT 0,
  max_retries INT DEFAULT 3,
  last_error TEXT,
  last_retry_at TIMESTAMPTZ,
  
  -- Delivery metadata
  message_id VARCHAR(255),  -- Provider's message ID (e.g., Gmail message ID)
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  bounced_at TIMESTAMPTZ,
  bounce_type VARCHAR(20),  -- 'permanent', 'temporary'
  bounce_reason TEXT,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for email_queue
CREATE INDEX IF NOT EXISTS idx_email_queue_user_id ON email_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_email_queue_status ON email_queue(status);
CREATE INDEX IF NOT EXISTS idx_email_queue_recipient_email ON email_queue(recipient_email);
CREATE INDEX IF NOT EXISTS idx_email_queue_created_at ON email_queue(created_at);
CREATE INDEX IF NOT EXISTS idx_email_queue_sent_at ON email_queue(sent_at);
CREATE INDEX IF NOT EXISTS idx_email_queue_status_created ON email_queue(status, created_at);

-- ============================================================================
-- EMAIL DELIVERY LOGS TABLE
-- ============================================================================
-- Stores detailed delivery logs for auditing and troubleshooting
CREATE TABLE IF NOT EXISTS email_delivery_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email_queue_id UUID NOT NULL REFERENCES email_queue(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Event details
  event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('queued', 'sending', 'sent', 'failed', 'bounced', 'opened', 'clicked', 'complained')),
  event_status VARCHAR(20),
  
  -- Error information
  error_code VARCHAR(50),
  error_message TEXT,
  
  -- Provider information
  provider VARCHAR(50),
  provider_event_id VARCHAR(255),
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for email_delivery_logs
CREATE INDEX IF NOT EXISTS idx_email_delivery_logs_email_queue_id ON email_delivery_logs(email_queue_id);
CREATE INDEX IF NOT EXISTS idx_email_delivery_logs_user_id ON email_delivery_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_email_delivery_logs_event_type ON email_delivery_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_email_delivery_logs_created_at ON email_delivery_logs(created_at);

-- ============================================================================
-- GOOGLE WORKSPACE QUOTA TABLE
-- ============================================================================
-- Tracks Google Workspace API quota usage and limits
CREATE TABLE IF NOT EXISTS google_workspace_quota (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Quota metrics
  daily_quota_limit INT DEFAULT 100,  -- Emails per day
  daily_quota_used INT DEFAULT 0,
  daily_quota_reset_at TIMESTAMPTZ,
  
  hourly_quota_limit INT DEFAULT 10,  -- Emails per hour
  hourly_quota_used INT DEFAULT 0,
  hourly_quota_reset_at TIMESTAMPTZ,
  
  -- Status
  is_quota_exceeded BOOLEAN DEFAULT false,
  quota_exceeded_at TIMESTAMPTZ,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for google_workspace_quota
CREATE INDEX IF NOT EXISTS idx_google_workspace_quota_user_id ON google_workspace_quota(user_id);
CREATE INDEX IF NOT EXISTS idx_google_workspace_quota_is_quota_exceeded ON google_workspace_quota(is_quota_exceeded);
CREATE INDEX IF NOT EXISTS idx_google_workspace_quota_updated_at ON google_workspace_quota(updated_at);

-- ============================================================================
-- EMAIL TEMPLATES TABLE
-- ============================================================================
-- Stores email templates for different notification types
CREATE TABLE IF NOT EXISTS email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,  -- NULL for system templates
  
  -- Template details
  name VARCHAR(100) NOT NULL,
  description TEXT,
  subject VARCHAR(255) NOT NULL,
  html_body TEXT NOT NULL,
  text_body TEXT,
  
  -- Template variables (for documentation)
  variables JSONB DEFAULT '[]'::jsonb,  -- Array of variable names used in template
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  is_system_template BOOLEAN DEFAULT false,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for email_templates
CREATE INDEX IF NOT EXISTS idx_email_templates_user_id ON email_templates(user_id);
CREATE INDEX IF NOT EXISTS idx_email_templates_name ON email_templates(name);
CREATE INDEX IF NOT EXISTS idx_email_templates_is_active ON email_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_email_templates_is_system_template ON email_templates(is_system_template);

-- ============================================================================
-- AUDIT LOGGING FOR EMAIL CONFIGURATION CHANGES
-- ============================================================================
-- Add email configuration audit logging to existing audit_logs table
-- (Assumes audit_logs table exists from schema.pg.sql)

-- Create a trigger function to log email configuration changes
CREATE OR REPLACE FUNCTION log_email_config_changes()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (
    user_id,
    action,
    resource_type,
    resource_id,
    changes,
    created_at
  ) VALUES (
    NEW.updated_by,
    CASE WHEN TG_OP = 'INSERT' THEN 'CREATE' ELSE 'UPDATE' END,
    'email_configuration',
    NEW.id::TEXT,
    jsonb_build_object(
      'provider', NEW.provider,
      'from_address', NEW.from_address,
      'is_active', NEW.is_active,
      'is_verified', NEW.is_verified
    ),
    NOW()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for email configuration changes
CREATE TRIGGER email_config_audit_trigger
AFTER INSERT OR UPDATE ON email_configurations
FOR EACH ROW
EXECUTE FUNCTION log_email_config_changes();

-- Create a trigger function to log DNS record changes
CREATE OR REPLACE FUNCTION log_dns_record_changes()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (
    user_id,
    action,
    resource_type,
    resource_id,
    changes,
    created_at
  ) VALUES (
    NEW.created_by,
    CASE WHEN TG_OP = 'INSERT' THEN 'CREATE' WHEN TG_OP = 'UPDATE' THEN 'UPDATE' ELSE 'DELETE' END,
    'dns_record',
    NEW.id::TEXT,
    jsonb_build_object(
      'provider', NEW.provider,
      'record_type', NEW.record_type,
      'name', NEW.name,
      'status', NEW.status
    ),
    NOW()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for DNS record changes
CREATE TRIGGER dns_record_audit_trigger
AFTER INSERT OR UPDATE ON dns_records
FOR EACH ROW
EXECUTE FUNCTION log_dns_record_changes();

-- ============================================================================
-- UPDATED_AT TRIGGERS
-- ============================================================================
-- Create a generic function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at columns
CREATE TRIGGER email_configurations_updated_at_trigger
BEFORE UPDATE ON email_configurations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER dns_records_updated_at_trigger
BEFORE UPDATE ON dns_records
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER email_queue_updated_at_trigger
BEFORE UPDATE ON email_queue
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER google_workspace_quota_updated_at_trigger
BEFORE UPDATE ON google_workspace_quota
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER email_templates_updated_at_trigger
BEFORE UPDATE ON email_templates
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
