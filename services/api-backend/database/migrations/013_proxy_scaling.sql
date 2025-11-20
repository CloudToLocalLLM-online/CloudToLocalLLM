-- Migration: Proxy Scaling Based on Load
-- Description: Create tables for tracking proxy scaling events, load metrics, and scaling policies
-- Validates: Requirements 5.5

-- Create proxy_scaling_policies table
CREATE TABLE IF NOT EXISTS proxy_scaling_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  min_replicas INTEGER NOT NULL DEFAULT 1,
  max_replicas INTEGER NOT NULL DEFAULT 10,
  target_cpu_percent FLOAT NOT NULL DEFAULT 70.0,
  target_memory_percent FLOAT NOT NULL DEFAULT 80.0,
  target_request_rate FLOAT NOT NULL DEFAULT 1000.0,
  scale_up_threshold FLOAT NOT NULL DEFAULT 80.0,
  scale_down_threshold FLOAT NOT NULL DEFAULT 30.0,
  scale_up_cooldown_seconds INTEGER NOT NULL DEFAULT 60,
  scale_down_cooldown_seconds INTEGER NOT NULL DEFAULT 300,
  enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_load_metrics table
CREATE TABLE IF NOT EXISTS proxy_load_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  current_replicas INTEGER NOT NULL,
  cpu_percent FLOAT NOT NULL,
  memory_percent FLOAT NOT NULL,
  request_rate FLOAT NOT NULL,
  average_latency_ms FLOAT NOT NULL,
  error_rate FLOAT NOT NULL,
  connection_count INTEGER NOT NULL,
  load_score FLOAT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_scaling_events table
CREATE TABLE IF NOT EXISTS proxy_scaling_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  previous_replicas INTEGER NOT NULL,
  new_replicas INTEGER NOT NULL,
  reason VARCHAR(255) NOT NULL,
  triggered_by VARCHAR(50) NOT NULL,
  load_metrics JSONB,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  error_message TEXT,
  duration_ms INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_scaling_history table
CREATE TABLE IF NOT EXISTS proxy_scaling_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  scaling_event_id UUID NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  replicas INTEGER NOT NULL,
  cpu_percent FLOAT NOT NULL,
  memory_percent FLOAT NOT NULL,
  request_rate FLOAT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (scaling_event_id) REFERENCES proxy_scaling_events(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_proxy_scaling_policies_proxy_id ON proxy_scaling_policies(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_scaling_policies_user_id ON proxy_scaling_policies(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_scaling_policies_enabled ON proxy_scaling_policies(enabled);

CREATE INDEX IF NOT EXISTS idx_proxy_load_metrics_proxy_id ON proxy_load_metrics(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_load_metrics_user_id ON proxy_load_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_load_metrics_created_at ON proxy_load_metrics(created_at);

CREATE INDEX IF NOT EXISTS idx_proxy_scaling_events_proxy_id ON proxy_scaling_events(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_scaling_events_user_id ON proxy_scaling_events(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_scaling_events_created_at ON proxy_scaling_events(created_at);
CREATE INDEX IF NOT EXISTS idx_proxy_scaling_events_status ON proxy_scaling_events(status);

CREATE INDEX IF NOT EXISTS idx_proxy_scaling_history_proxy_id ON proxy_scaling_history(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_scaling_history_created_at ON proxy_scaling_history(created_at);

-- Add comments for documentation
COMMENT ON TABLE proxy_scaling_policies IS 'Defines scaling policies for proxy instances based on load';
COMMENT ON TABLE proxy_load_metrics IS 'Stores current load metrics for proxy instances';
COMMENT ON TABLE proxy_scaling_events IS 'Records scaling events and their outcomes';
COMMENT ON TABLE proxy_scaling_history IS 'Historical record of scaling decisions and metrics';

COMMENT ON COLUMN proxy_scaling_policies.min_replicas IS 'Minimum number of proxy replicas to maintain';
COMMENT ON COLUMN proxy_scaling_policies.max_replicas IS 'Maximum number of proxy replicas allowed';
COMMENT ON COLUMN proxy_scaling_policies.target_cpu_percent IS 'Target CPU utilization percentage';
COMMENT ON COLUMN proxy_scaling_policies.target_memory_percent IS 'Target memory utilization percentage';
COMMENT ON COLUMN proxy_scaling_policies.target_request_rate IS 'Target request rate per second';
COMMENT ON COLUMN proxy_scaling_policies.scale_up_threshold IS 'Threshold percentage to trigger scale up';
COMMENT ON COLUMN proxy_scaling_policies.scale_down_threshold IS 'Threshold percentage to trigger scale down';
COMMENT ON COLUMN proxy_scaling_policies.scale_up_cooldown_seconds IS 'Cooldown period after scale up in seconds';
COMMENT ON COLUMN proxy_scaling_policies.scale_down_cooldown_seconds IS 'Cooldown period after scale down in seconds';

COMMENT ON COLUMN proxy_load_metrics.load_score IS 'Composite load score (0-100) based on all metrics';
COMMENT ON COLUMN proxy_scaling_events.triggered_by IS 'Source of scaling trigger: auto, manual, admin';
COMMENT ON COLUMN proxy_scaling_events.status IS 'Status of scaling event: pending, in_progress, completed, failed';
