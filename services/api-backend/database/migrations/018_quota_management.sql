/**
 * Quota Management Schema Migration
 *
 * Creates tables for tracking and enforcing resource quotas:
 * - quota_definitions: Define quota limits per tier
 * - user_quotas: Track current quota usage per user
 * - quota_events: Log quota-related events
 *
 * Validates: Requirements 6.6
 * - Implements quota management for resource usage
 * - Tracks quota usage per user
 * - Enforces quota limits
 * - Provides quota reporting
 */

-- Create quota_definitions table
CREATE TABLE IF NOT EXISTS quota_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tier VARCHAR(50) NOT NULL UNIQUE,
  resource_type VARCHAR(100) NOT NULL,
  limit_value BIGINT NOT NULL,
  limit_unit VARCHAR(50) NOT NULL,
  reset_period VARCHAR(50) NOT NULL DEFAULT 'monthly',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_quotas table
CREATE TABLE IF NOT EXISTS user_quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource_type VARCHAR(100) NOT NULL,
  limit_value BIGINT NOT NULL,
  current_usage BIGINT NOT NULL DEFAULT 0,
  reset_period VARCHAR(50) NOT NULL DEFAULT 'monthly',
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  is_exceeded BOOLEAN DEFAULT FALSE,
  exceeded_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, resource_type, period_start, period_end)
);

-- Create quota_events table
CREATE TABLE IF NOT EXISTS quota_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource_type VARCHAR(100) NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  usage_delta BIGINT NOT NULL,
  total_usage BIGINT NOT NULL,
  limit_value BIGINT NOT NULL,
  percentage_used NUMERIC(5, 2) NOT NULL,
  details JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_quota_definitions_tier ON quota_definitions(tier);
CREATE INDEX IF NOT EXISTS idx_user_quotas_user_id ON user_quotas(user_id);
CREATE INDEX IF NOT EXISTS idx_user_quotas_resource_type ON user_quotas(resource_type);
CREATE INDEX IF NOT EXISTS idx_user_quotas_period ON user_quotas(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_quota_events_user_id ON quota_events(user_id);
CREATE INDEX IF NOT EXISTS idx_quota_events_resource_type ON quota_events(resource_type);
CREATE INDEX IF NOT EXISTS idx_quota_events_created_at ON quota_events(created_at);

-- Insert default quota definitions
INSERT INTO quota_definitions (tier, resource_type, limit_value, limit_unit, reset_period)
VALUES 
  ('free', 'api_requests', 10000, 'requests', 'monthly'),
  ('free', 'data_transfer', 1073741824, 'bytes', 'monthly'),
  ('free', 'concurrent_connections', 5, 'connections', 'unlimited'),
  ('free', 'tunnels', 3, 'tunnels', 'unlimited'),
  ('premium', 'api_requests', 1000000, 'requests', 'monthly'),
  ('premium', 'data_transfer', 107374182400, 'bytes', 'monthly'),
  ('premium', 'concurrent_connections', 100, 'connections', 'unlimited'),
  ('premium', 'tunnels', 50, 'tunnels', 'unlimited'),
  ('enterprise', 'api_requests', 9223372036854775807, 'requests', 'monthly'),
  ('enterprise', 'data_transfer', 9223372036854775807, 'bytes', 'monthly'),
  ('enterprise', 'concurrent_connections', 9223372036854775807, 'connections', 'unlimited'),
  ('enterprise', 'tunnels', 9223372036854775807, 'tunnels', 'unlimited')
ON CONFLICT (tier, resource_type) DO NOTHING;
