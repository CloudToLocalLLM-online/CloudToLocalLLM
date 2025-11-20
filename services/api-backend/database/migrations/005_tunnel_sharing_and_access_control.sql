-- Migration: Tunnel Sharing and Access Control
-- Adds tables for managing tunnel sharing and access control
-- Validates: Requirements 4.8

-- Tunnel shares table for managing shared tunnel access
CREATE TABLE IF NOT EXISTS tunnel_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  shared_with_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  permission VARCHAR(50) NOT NULL DEFAULT 'read' CHECK (permission IN ('read', 'write', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  CONSTRAINT tunnel_share_unique UNIQUE (tunnel_id, owner_id, shared_with_user_id)
);

-- Tunnel share tokens for temporary access (e.g., for sharing links)
CREATE TABLE IF NOT EXISTS tunnel_share_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(255) NOT NULL UNIQUE,
  permission VARCHAR(50) NOT NULL DEFAULT 'read' CHECK (permission IN ('read', 'write', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT true,
  max_uses INTEGER,
  use_count INTEGER DEFAULT 0
);

-- Tunnel access logs for audit trail
CREATE TABLE IF NOT EXISTS tunnel_access_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action VARCHAR(50) NOT NULL,
  permission VARCHAR(50),
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tunnel_shares_tunnel_id ON tunnel_shares(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_shares_owner_id ON tunnel_shares(owner_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_shares_shared_with_user_id ON tunnel_shares(shared_with_user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_shares_is_active ON tunnel_shares(is_active);
CREATE INDEX IF NOT EXISTS idx_tunnel_share_tokens_tunnel_id ON tunnel_share_tokens(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_share_tokens_token ON tunnel_share_tokens(token);
CREATE INDEX IF NOT EXISTS idx_tunnel_share_tokens_is_active ON tunnel_share_tokens(is_active);
CREATE INDEX IF NOT EXISTS idx_tunnel_access_logs_tunnel_id ON tunnel_access_logs(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_access_logs_user_id ON tunnel_access_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_access_logs_created_at ON tunnel_access_logs(created_at);
