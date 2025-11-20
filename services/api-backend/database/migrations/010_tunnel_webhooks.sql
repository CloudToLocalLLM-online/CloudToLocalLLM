-- Migration: Tunnel Status Webhooks
-- Adds webhook registration and delivery tracking for tunnel status events
-- Validates: Requirements 4.10, 10.1, 10.2, 10.3, 10.4

-- Tunnel webhook registrations table
CREATE TABLE IF NOT EXISTS tunnel_webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tunnel_id UUID REFERENCES tunnels(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  events TEXT[] NOT NULL DEFAULT ARRAY['tunnel.status_changed'],
  secret VARCHAR(255) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT webhook_url_not_empty CHECK (url != ''),
  CONSTRAINT webhook_events_not_empty CHECK (array_length(events, 1) > 0)
);

-- Tunnel webhook delivery tracking table
CREATE TABLE IF NOT EXISTS tunnel_webhook_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id) ON DELETE CASCADE,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'failed', 'retrying')),
  http_status_code INTEGER,
  error_message TEXT,
  attempt_count INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 5,
  next_retry_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tunnel webhook event log table for audit purposes
CREATE TABLE IF NOT EXISTS tunnel_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id) ON DELETE CASCADE,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tunnel_webhooks_user_id ON tunnel_webhooks(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhooks_tunnel_id ON tunnel_webhooks(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhooks_is_active ON tunnel_webhooks(is_active);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhooks_user_tunnel ON tunnel_webhooks(user_id, tunnel_id);

CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_deliveries_webhook_id ON tunnel_webhook_deliveries(webhook_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_deliveries_tunnel_id ON tunnel_webhook_deliveries(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_deliveries_user_id ON tunnel_webhook_deliveries(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_deliveries_status ON tunnel_webhook_deliveries(status);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_deliveries_next_retry ON tunnel_webhook_deliveries(next_retry_at) WHERE status = 'retrying';
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_deliveries_created_at ON tunnel_webhook_deliveries(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_events_webhook_id ON tunnel_webhook_events(webhook_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_events_tunnel_id ON tunnel_webhook_events(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_events_user_id ON tunnel_webhook_events(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_events_event_type ON tunnel_webhook_events(event_type);
CREATE INDEX IF NOT EXISTS idx_tunnel_webhook_events_created_at ON tunnel_webhook_events(created_at DESC);
