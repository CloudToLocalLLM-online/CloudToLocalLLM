-- Admin Center Database Migration Rollback
-- Version: 001
-- Description: Rolls back the admin center schema migration
-- WARNING: This will delete all admin center data including subscriptions, payments, and audit logs

-- ============================================================================
-- DROP TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
DROP TRIGGER IF EXISTS update_payment_transactions_updated_at ON payment_transactions;
DROP TRIGGER IF EXISTS update_payment_methods_updated_at ON payment_methods;
DROP TRIGGER IF EXISTS update_refunds_updated_at ON refunds;
DROP TRIGGER IF EXISTS update_admin_roles_updated_at ON admin_roles;

-- ============================================================================
-- DROP TABLES (in reverse order of dependencies)
-- ============================================================================
DROP TABLE IF EXISTS admin_audit_logs CASCADE;
DROP TABLE IF EXISTS admin_roles CASCADE;
DROP TABLE IF EXISTS refunds CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS payment_transactions CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;

-- ============================================================================
-- ROLLBACK COMPLETE
-- ============================================================================
-- Migration 001 rolled back successfully
-- All admin center tables, indexes, and triggers have been removed
