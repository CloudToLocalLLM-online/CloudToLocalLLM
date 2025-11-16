-- Email Relay & DNS Configuration Database Migration - Rollback
-- Version: 003
-- Description: Rollback script for email relay and DNS configuration tables

-- ============================================================================
-- DROP TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS email_config_audit_trigger ON email_configurations;
DROP TRIGGER IF EXISTS dns_record_audit_trigger ON dns_records;
DROP TRIGGER IF EXISTS email_configurations_updated_at_trigger ON email_configurations;
DROP TRIGGER IF EXISTS dns_records_updated_at_trigger ON dns_records;
DROP TRIGGER IF EXISTS email_queue_updated_at_trigger ON email_queue;
DROP TRIGGER IF EXISTS google_workspace_quota_updated_at_trigger ON google_workspace_quota;
DROP TRIGGER IF EXISTS email_templates_updated_at_trigger ON email_templates;

-- ============================================================================
-- DROP TRIGGER FUNCTIONS
-- ============================================================================
DROP FUNCTION IF EXISTS log_email_config_changes();
DROP FUNCTION IF EXISTS log_dns_record_changes();
DROP FUNCTION IF EXISTS update_updated_at_column();

-- ============================================================================
-- DROP TABLES
-- ============================================================================
DROP TABLE IF EXISTS email_templates CASCADE;
DROP TABLE IF EXISTS google_workspace_quota CASCADE;
DROP TABLE IF EXISTS email_delivery_logs CASCADE;
DROP TABLE IF EXISTS email_queue CASCADE;
DROP TABLE IF EXISTS dns_records CASCADE;
DROP TABLE IF EXISTS email_configurations CASCADE;
