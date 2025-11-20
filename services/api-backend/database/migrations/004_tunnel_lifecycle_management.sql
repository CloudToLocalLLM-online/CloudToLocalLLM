-- Migration: Tunnel Lifecycle Management
-- Adds comprehensive tunnel management tables for tunnel lifecycle operations
-- Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.6

-- Tunnels table for managing tunnel instances
CREATE TABLE IF NOT EXISTS tunnels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'connecting', 'connected', 'disconnected', 'error')),
  config JSONB DEFAULT '{}'::jsonb,
  metrics JSONB DEFAULT '{"requestCount": 0, "successCount": 0, "errorCount": 0, "averageLatency": 0}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by_ip INET,
  created_by_user_agent TEXT,
  CONSTRAINT tunnel_name_per_user UNIQUE (user_id, name)
);

-- Tunnel endpoints table for managing multiple endpoints per tunnel
CREATE TABLE IF NOT EXISTS tunnel_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  url VARCHAR(255) NOT NULL,
  priority INTEGER DEFAULT 0,
  weight INTEGER DEFAULT 1,
  health_status VARCHAR(50) DEFAULT 'unknown' CHECK (health_status IN ('healthy', 'unhealthy', 'unknown')),
  last_health_check TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tunnel activity log for tracking tunnel operations
CREATE TABLE IF NOT EXISTS tunnel_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action VARCHAR(50) NOT NULL,
  status VARCHAR(50) NOT NULL,
  details JSONB DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tunnels_user_id ON tunnels(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnels_status ON tunnels(status);
CREATE INDEX IF NOT EXISTS idx_tunnel_endpoints_tunnel_id ON tunnel_endpoints(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_activity_tunnel_id ON tunnel_activity_logs(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_activity_user_id ON tunnel_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_activity_created_at ON tunnel_activity_logs(created_at);
