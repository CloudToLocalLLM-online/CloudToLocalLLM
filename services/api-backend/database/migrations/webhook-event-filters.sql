-- Create webhook event filters table
-- Stores filter configurations for webhook events

CREATE TABLE IF NOT EXISTS webhook_event_filters (
  id UUID PRIMARY KEY,
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  filter_config JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_webhook_event_filters_webhook_id 
  ON webhook_event_filters(webhook_id);

CREATE INDEX IF NOT EXISTS idx_webhook_event_filters_user_id 
  ON webhook_event_filters(user_id);

CREATE INDEX IF NOT EXISTS idx_webhook_event_filters_is_active 
  ON webhook_event_filters(is_active);

-- Add comment
COMMENT ON TABLE webhook_event_filters IS 'Stores webhook event filter configurations for filtering which events trigger webhook deliveries';
COMMENT ON COLUMN webhook_event_filters.filter_config IS 'JSON configuration for event filtering (type, eventPatterns, propertyFilters, rateLimit)';
