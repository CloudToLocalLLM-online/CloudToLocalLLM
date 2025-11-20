-- Migration: Proxy Usage Tracking
-- Description: Create tables for tracking proxy usage for billing and analytics
-- Validates: Requirements 5.9

-- Create proxy_usage_events table for raw usage events
CREATE TABLE IF NOT EXISTS proxy_usage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  connection_id VARCHAR(255),
  data_bytes BIGINT DEFAULT 0,
  duration_seconds INTEGER,
  error_message TEXT,
  ip_address VARCHAR(45),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_usage_metrics table for aggregated daily usage metrics
CREATE TABLE IF NOT EXISTS proxy_usage_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  date DATE NOT NULL,
  connection_count INTEGER DEFAULT 0,
  data_transferred_bytes BIGINT DEFAULT 0,
  data_received_bytes BIGINT DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_connection_duration_seconds FLOAT DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(proxy_id, date)
);

-- Create proxy_usage_aggregation table for period-based aggregation
CREATE TABLE IF NOT EXISTS proxy_usage_aggregation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  user_tier VARCHAR(50) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_connections INTEGER DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  total_data_received_bytes BIGINT DEFAULT 0,
  proxy_count INTEGER DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_connection_duration_seconds FLOAT DEFAULT 0,
  total_error_count INTEGER DEFAULT 0,
  total_success_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, period_start, period_end)
);

-- Create proxy_usage_summary table for quick access to current usage
CREATE TABLE IF NOT EXISTS proxy_usage_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  connection_count_1h INTEGER DEFAULT 0,
  connection_count_24h INTEGER DEFAULT 0,
  success_rate_1h FLOAT DEFAULT 100,
  success_rate_24h FLOAT DEFAULT 100,
  data_transferred_1h_bytes BIGINT DEFAULT 0,
  data_transferred_24h_bytes BIGINT DEFAULT 0,
  error_count_1h INTEGER DEFAULT 0,
  error_count_24h INTEGER DEFAULT 0,
  concurrent_connections INTEGER DEFAULT 0,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_proxy_usage_events_proxy_id ON proxy_usage_events(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_events_user_id ON proxy_usage_events(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_events_created_at ON proxy_usage_events(created_at);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_events_event_type ON proxy_usage_events(event_type);

CREATE INDEX IF NOT EXISTS idx_proxy_usage_metrics_proxy_id ON proxy_usage_metrics(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_metrics_user_id ON proxy_usage_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_metrics_date ON proxy_usage_metrics(date);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_metrics_proxy_date ON proxy_usage_metrics(proxy_id, date);

CREATE INDEX IF NOT EXISTS idx_proxy_usage_aggregation_user_id ON proxy_usage_aggregation(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_aggregation_period ON proxy_usage_aggregation(period_start, period_end);

CREATE INDEX IF NOT EXISTS idx_proxy_usage_summary_proxy_id ON proxy_usage_summary(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_usage_summary_user_id ON proxy_usage_summary(user_id);

-- Add comments for documentation
COMMENT ON TABLE proxy_usage_events IS 'Raw usage events collected from proxy instances';
COMMENT ON TABLE proxy_usage_metrics IS 'Aggregated daily usage metrics for proxy instances';
COMMENT ON TABLE proxy_usage_aggregation IS 'Period-based aggregated usage metrics for billing';
COMMENT ON TABLE proxy_usage_summary IS 'Current summary usage metrics for quick access';

COMMENT ON COLUMN proxy_usage_events.event_type IS 'Type of usage event: connection_start, connection_end, data_transfer, error';
COMMENT ON COLUMN proxy_usage_metrics.data_transferred_bytes IS 'Data sent from proxy to client in bytes';
COMMENT ON COLUMN proxy_usage_metrics.data_received_bytes IS 'Data received by proxy from client in bytes';
COMMENT ON COLUMN proxy_usage_aggregation.user_tier IS 'User tier at time of aggregation: free, premium, enterprise';
COMMENT ON COLUMN proxy_usage_summary.connection_count_1h IS 'Connection count in the last hour';
COMMENT ON COLUMN proxy_usage_summary.connection_count_24h IS 'Connection count in the last 24 hours';
