-- Migration: Create API Keys table for service-to-service authentication
-- This migration creates the api_keys table for managing API key authentication
-- Requirements: 2.8

-- Create api_keys table
CREATE TABLE IF NOT EXISTS api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  key_hash TEXT UNIQUE NOT NULL,  -- SHA-256 hash of the actual key
  key_prefix TEXT NOT NULL,  -- First 8 characters of the key for display
  description TEXT,
  scopes TEXT[] DEFAULT ARRAY[]::TEXT[],  -- Array of allowed scopes
  rate_limit INTEGER DEFAULT 1000,  -- Requests per minute
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  rotation_required BOOLEAN DEFAULT false,
  rotated_from_id UUID REFERENCES api_keys(id) ON DELETE SET NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_api_keys_expires_at ON api_keys(expires_at);
CREATE INDEX IF NOT EXISTS idx_api_keys_created_at ON api_keys(created_at);

-- Create api_key_audit_logs table for tracking API key usage and rotations
CREATE TABLE IF NOT EXISTS api_key_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('created', 'used', 'rotated', 'revoked', 'expired')),
  details JSONB DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for audit logs
CREATE INDEX IF NOT EXISTS idx_api_key_audit_logs_api_key_id ON api_key_audit_logs(api_key_id);
CREATE INDEX IF NOT EXISTS idx_api_key_audit_logs_user_id ON api_key_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_api_key_audit_logs_action ON api_key_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_api_key_audit_logs_created_at ON api_key_audit_logs(created_at);

-- Apply updated_at trigger to api_keys
CREATE TRIGGER update_api_keys_updated_at BEFORE UPDATE ON api_keys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
