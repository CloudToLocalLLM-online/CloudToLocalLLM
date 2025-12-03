-- Admin Center Database Migration
-- Version: 001
-- Description: Creates tables for admin center functionality including subscriptions,
--              payment transactions, payment methods, refunds, admin roles, and admin audit logs
-- Requirements: 17, 11, 10

-- Enable required extensions (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- ALTER USERS TABLE
-- ============================================================================
-- Add suspension-related columns to users table if they don't exist
DO $$ 
BEGIN
  -- Add is_suspended column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='users' AND column_name='is_suspended') THEN
    ALTER TABLE users ADD COLUMN is_suspended BOOLEAN DEFAULT false;
  END IF;

  -- Add suspended_at column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='users' AND column_name='suspended_at') THEN
    ALTER TABLE users ADD COLUMN suspended_at TIMESTAMPTZ;
  END IF;

  -- Add suspension_reason column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='users' AND column_name='suspension_reason') THEN
    ALTER TABLE users ADD COLUMN suspension_reason TEXT;
  END IF;

  -- Add deleted_at column for soft deletes
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='users' AND column_name='deleted_at') THEN
    ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;
  END IF;

  -- Add username column if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='users' AND column_name='username') THEN
    ALTER TABLE users ADD COLUMN username TEXT;
  END IF;
END $$;

-- Create indexes for suspension-related columns
CREATE INDEX IF NOT EXISTS idx_users_is_suspended ON users(is_suspended) WHERE is_suspended = true;
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NOT NULL;

-- ============================================================================
-- SUBSCRIPTIONS TABLE
-- ============================================================================
-- Stores user subscription information including tier, status, and billing periods
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stripe_subscription_id TEXT UNIQUE,  -- Stripe subscription ID
  stripe_customer_id TEXT,  -- Stripe customer ID
  tier TEXT NOT NULL CHECK (tier IN ('free', 'premium', 'enterprise')),
  status TEXT NOT NULL CHECK (status IN ('active', 'canceled', 'past_due', 'trialing', 'incomplete')),
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT false,
  canceled_at TIMESTAMPTZ,
  trial_start TIMESTAMPTZ,
  trial_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for subscriptions table
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_subscription_id ON subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_tier ON subscriptions(tier);
CREATE INDEX IF NOT EXISTS idx_subscriptions_current_period_end ON subscriptions(current_period_end);

-- ============================================================================
-- PAYMENT TRANSACTIONS TABLE
-- ============================================================================
-- Stores all payment transaction records including status and payment method details
CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  stripe_payment_intent_id TEXT UNIQUE,  -- Stripe PaymentIntent ID
  stripe_charge_id TEXT,  -- Stripe Charge ID
  amount DECIMAL(10, 2) NOT NULL,  -- Amount in dollars
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded', 'partially_refunded', 'disputed')),
  payment_method_type TEXT,  -- card, paypal, etc.
  payment_method_last4 TEXT,  -- Last 4 digits of card
  failure_code TEXT,
  failure_message TEXT,
  receipt_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for payment_transactions table
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_id ON payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_subscription_id ON payment_transactions(subscription_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_stripe_payment_intent_id ON payment_transactions(stripe_payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created_at ON payment_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_amount ON payment_transactions(amount);

-- ============================================================================
-- PAYMENT METHODS TABLE
-- ============================================================================
-- Stores user payment method information (cards, PayPal, etc.)
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stripe_payment_method_id TEXT UNIQUE NOT NULL,  -- Stripe PaymentMethod ID
  type TEXT NOT NULL,  -- card, paypal, etc.
  card_brand TEXT,  -- visa, mastercard, etc.
  card_last4 TEXT,
  card_exp_month INTEGER,
  card_exp_year INTEGER,
  billing_email TEXT,
  billing_name TEXT,
  billing_address JSONB,
  is_default BOOLEAN DEFAULT false,
  status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'failed_verification')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for payment_methods table
CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_stripe_payment_method_id ON payment_methods(stripe_payment_method_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_status ON payment_methods(status);
CREATE INDEX IF NOT EXISTS idx_payment_methods_is_default ON payment_methods(is_default) WHERE is_default = true;

-- ============================================================================
-- REFUNDS TABLE
-- ============================================================================
-- Stores refund records for payment transactions
CREATE TABLE IF NOT EXISTS refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE CASCADE,
  stripe_refund_id TEXT UNIQUE NOT NULL,  -- Stripe Refund ID
  amount DECIMAL(10, 2) NOT NULL,  -- Refund amount in dollars
  currency TEXT NOT NULL DEFAULT 'USD',
  reason TEXT NOT NULL CHECK (reason IN ('customer_request', 'billing_error', 'service_issue', 'duplicate', 'fraudulent', 'other')),
  reason_details TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'canceled')),
  failure_reason TEXT,
  admin_user_id UUID REFERENCES users(id),  -- Admin who processed refund
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for refunds table
CREATE INDEX IF NOT EXISTS idx_refunds_transaction_id ON refunds(transaction_id);
CREATE INDEX IF NOT EXISTS idx_refunds_stripe_refund_id ON refunds(stripe_refund_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON refunds(status);
CREATE INDEX IF NOT EXISTS idx_refunds_created_at ON refunds(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refunds_admin_user_id ON refunds(admin_user_id);

-- ============================================================================
-- ADMIN ROLES TABLE
-- ============================================================================
-- Stores administrator role assignments and permissions
CREATE TABLE IF NOT EXISTS admin_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('super_admin', 'support_admin', 'finance_admin')),
  granted_by UUID REFERENCES users(id) ON DELETE SET NULL,  -- Admin who granted the role
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)  -- User can have multiple roles but not duplicate roles
);

-- Indexes for admin_roles table
CREATE INDEX IF NOT EXISTS idx_admin_roles_user_id ON admin_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_roles_role ON admin_roles(role);
CREATE INDEX IF NOT EXISTS idx_admin_roles_is_active ON admin_roles(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_admin_roles_granted_by ON admin_roles(granted_by);

-- ============================================================================
-- ADMIN AUDIT LOGS TABLE
-- ============================================================================
-- Stores comprehensive audit trail of all administrative actions
CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  admin_role TEXT NOT NULL,  -- Role of admin at time of action
  action TEXT NOT NULL,  -- e.g., 'user_suspended', 'subscription_upgraded', 'refund_processed'
  resource_type TEXT NOT NULL,  -- e.g., 'user', 'subscription', 'transaction'
  resource_id TEXT NOT NULL,  -- ID of affected resource
  affected_user_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- User affected by action
  details JSONB DEFAULT '{}'::jsonb,  -- Additional action details
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for admin_audit_logs table
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin_user_id ON admin_audit_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action ON admin_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_resource_type ON admin_audit_logs(resource_type);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_resource_id ON admin_audit_logs(resource_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_affected_user_id ON admin_audit_logs(affected_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);

-- ============================================================================
-- TRIGGERS FOR UPDATED_AT COLUMNS
-- ============================================================================
-- Apply updated_at triggers to new tables (reusing existing trigger function)

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_transactions_updated_at BEFORE UPDATE ON payment_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_refunds_updated_at BEFORE UPDATE ON refunds
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_roles_updated_at BEFORE UPDATE ON admin_roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- DEFAULT DATA INSERTION
-- ============================================================================
-- Insert default Super Admin role for christopher.maltais@gmail.com
-- This will be executed during initial database setup
INSERT INTO admin_roles (user_id, role, is_active)
SELECT id, 'super_admin', true
FROM users
WHERE email = 'christopher.maltais@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- Migration 001 completed successfully
-- Tables created: subscriptions, payment_transactions, payment_methods, refunds, admin_roles, admin_audit_logs
-- Indexes created: 30+ indexes for query optimization
-- Triggers created: 5 updated_at triggers
-- Default data: Super Admin role for christopher.maltais@gmail.com
