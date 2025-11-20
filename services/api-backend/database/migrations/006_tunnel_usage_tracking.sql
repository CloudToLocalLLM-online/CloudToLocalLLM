-- Migration: Tunnel Usage Tracking for Billing
-- Adds comprehensive tunnel usage tracking tables for billing and analytics
-- Validates: Requirements 4.9

-- Tunnel usage metrics table for tracking connections and data transfer
CREATE TABLE IF NOT EXISTS tunnel_usage_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  connection_count INTEGER DEFAULT 0,
  data_transferred_bytes BIGINT DEFAULT 0,
  data_received_bytes BIGINT DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_connection_duration_seconds INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT tunnel_usage_unique_per_day UNIQUE (tunnel_id, date)
);

-- Tunnel usage aggregation table for per-user/tier aggregation
CREATE TABLE IF NOT EXISTS tunnel_usage_aggregation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_tier VARCHAR(50) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_connections BIGINT DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  total_data_received_bytes BIGINT DEFAULT 0,
  tunnel_count INTEGER DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_connection_duration_seconds INTEGER DEFAULT 0,
  total_error_count INTEGER DEFAULT 0,
  total_success_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT usage_aggregation_unique_per_period UNIQUE (user_id, period_start, period_end)
);

-- Tunnel usage events table for detailed event tracking
CREATE TABLE IF NOT EXISTS tunnel_usage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('connection_start', 'connection_end', 'data_transfer', 'error')),
  connection_id VARCHAR(255),
  data_bytes BIGINT DEFAULT 0,
  duration_seconds INTEGER,
  error_message TEXT,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_metrics_tunnel_id ON tunnel_usage_metrics(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_metrics_user_id ON tunnel_usage_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_metrics_date ON tunnel_usage_metrics(date);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_metrics_user_date ON tunnel_usage_metrics(user_id, date);

CREATE INDEX IF NOT EXISTS idx_tunnel_usage_aggregation_user_id ON tunnel_usage_aggregation(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_aggregation_period ON tunnel_usage_aggregation(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_aggregation_user_period ON tunnel_usage_aggregation(user_id, period_start, period_end);

CREATE INDEX IF NOT EXISTS idx_tunnel_usage_events_tunnel_id ON tunnel_usage_events(tunnel_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_events_user_id ON tunnel_usage_events(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_events_type ON tunnel_usage_events(event_type);
CREATE INDEX IF NOT EXISTS idx_tunnel_usage_events_created_at ON tunnel_usage_events(created_at);
