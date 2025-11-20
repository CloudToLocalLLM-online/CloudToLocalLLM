-- Webhook Payload Transformations Table
-- Stores webhook payload transformation configurations

CREATE TABLE IF NOT EXISTS webhook_payload_transformations (
  id UUID PRIMARY KEY,
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transform_config JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_webhook_payload_transformations_webhook_id 
  ON webhook_payload_transformations(webhook_id);

CREATE INDEX IF NOT EXISTS idx_webhook_payload_transformations_user_id 
  ON webhook_payload_transformations(user_id);

CREATE INDEX IF NOT EXISTS idx_webhook_payload_transformations_is_active 
  ON webhook_payload_transformations(is_active);

-- Create composite index for common queries
CREATE INDEX IF NOT EXISTS idx_webhook_payload_transformations_webhook_user 
  ON webhook_payload_transformations(webhook_id, user_id);
