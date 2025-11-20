-- Migration: Webhook Rate Limiting
-- Adds webhook-specific rate limiting configuration and tracking
-- Validates: Requirements 10.7

-- Webhook rate limit configuration table
CREATE TABLE IF NOT EXISTS webhook_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rate_limit_per_minute INTEGER NOT NULL DEFAULT 60,
  rate_limit_per_hour INTEGER NOT NULL DEFAULT 1000,
  rate_limit_per_day INTEGER NOT NULL DEFAULT 10000,
  is_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT rate_limit_per_minute_positive CHECK (rate_limit_per_minute > 0),
  CONSTRAINT rate_limit_per_hour_positive CHECK (rate_limit_per_hour > 0),
  CONSTRAINT rate_limit_per_day_positive CHECK (rate_limit_per_day > 0),
  CONSTRAINT rate_limit_ordering CHECK (
    rate_limit_per_minute <= rate_limit_per_hour AND
    rate_limit_per_hour <= rate_limit_per_day
  ),
  UNIQUE(webhook_id, user_id)
);

-- Webhook rate limit tracking table for metrics
CREATE TABLE IF NOT EXISTS webhook_rate_limit_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivery_id UUID NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'failed', 'rate_limited')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limits_webhook_id ON webhook_rate_limits(webhook_id);
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limits_user_id ON webhook_rate_limits(user_id);
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limits_is_enabled ON webhook_rate_limits(is_enabled);

CREATE INDEX IF NOT EXISTS idx_webhook_rate_limit_tracking_webhook_id ON webhook_rate_limit_tracking(webhook_id);
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limit_tracking_user_id ON webhook_rate_limit_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limit_tracking_created_at ON webhook_rate_limit_tracking(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limit_tracking_status ON webhook_rate_limit_tracking(status);
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limit_tracking_webhook_user ON webhook_rate_limit_tracking(webhook_id, user_id);
