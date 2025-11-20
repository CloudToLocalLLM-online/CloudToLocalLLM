-- Migration: Proxy Metrics Collection
-- Description: Create tables for collecting and aggregating proxy performance metrics
-- Validates: Requirements 5.6

-- Create proxy_metrics_events table for raw metric events
CREATE TABLE IF NOT EXISTS proxy_metrics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  request_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  total_latency_ms BIGINT DEFAULT 0,
  min_latency_ms INTEGER DEFAULT 0,
  max_latency_ms INTEGER DEFAULT 0,
  data_transferred_bytes BIGINT DEFAULT 0,
  data_received_bytes BIGINT DEFAULT 0,
  connection_count INTEGER DEFAULT 0,
  concurrent_connections INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_metrics_daily table for aggregated daily metrics
CREATE TABLE IF NOT EXISTS proxy_metrics_daily (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  date DATE NOT NULL,
  request_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  average_latency_ms FLOAT DEFAULT 0,
  min_latency_ms INTEGER DEFAULT 0,
  max_latency_ms INTEGER DEFAULT 0,
  p95_latency_ms FLOAT DEFAULT 0,
  p99_latency_ms FLOAT DEFAULT 0,
  data_transferred_bytes BIGINT DEFAULT 0,
  data_received_bytes BIGINT DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_concurrent_connections FLOAT DEFAULT 0,
  uptime_percentage FLOAT DEFAULT 100,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(proxy_id, date)
);

-- Create proxy_metrics_aggregation table for period-based aggregation
CREATE TABLE IF NOT EXISTS proxy_metrics_aggregation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_request_count INTEGER DEFAULT 0,
  total_success_count INTEGER DEFAULT 0,
  total_error_count INTEGER DEFAULT 0,
  average_latency_ms FLOAT DEFAULT 0,
  min_latency_ms INTEGER DEFAULT 0,
  max_latency_ms INTEGER DEFAULT 0,
  p95_latency_ms FLOAT DEFAULT 0,
  p99_latency_ms FLOAT DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  total_data_received_bytes BIGINT DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_concurrent_connections FLOAT DEFAULT 0,
  average_uptime_percentage FLOAT DEFAULT 100,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(proxy_id, period_start, period_end)
);

-- Create proxy_metrics_summary table for quick access to current metrics
CREATE TABLE IF NOT EXISTS proxy_metrics_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  request_count_1h INTEGER DEFAULT 0,
  request_count_24h INTEGER DEFAULT 0,
  success_rate_1h FLOAT DEFAULT 100,
  success_rate_24h FLOAT DEFAULT 100,
  average_latency_ms_1h FLOAT DEFAULT 0,
  average_latency_ms_24h FLOAT DEFAULT 0,
  error_count_1h INTEGER DEFAULT 0,
  error_count_24h INTEGER DEFAULT 0,
  data_transferred_1h_bytes BIGINT DEFAULT 0,
  data_transferred_24h_bytes BIGINT DEFAULT 0,
  concurrent_connections INTEGER DEFAULT 0,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_events_proxy_id ON proxy_metrics_events(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_events_user_id ON proxy_metrics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_events_created_at ON proxy_metrics_events(created_at);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_events_event_type ON proxy_metrics_events(event_type);

CREATE INDEX IF NOT EXISTS idx_proxy_metrics_daily_proxy_id ON proxy_metrics_daily(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_daily_user_id ON proxy_metrics_daily(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_daily_date ON proxy_metrics_daily(date);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_daily_proxy_date ON proxy_metrics_daily(proxy_id, date);

CREATE INDEX IF NOT EXISTS idx_proxy_metrics_aggregation_proxy_id ON proxy_metrics_aggregation(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_aggregation_user_id ON proxy_metrics_aggregation(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_aggregation_period ON proxy_metrics_aggregation(period_start, period_end);

CREATE INDEX IF NOT EXISTS idx_proxy_metrics_summary_proxy_id ON proxy_metrics_summary(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_summary_user_id ON proxy_metrics_summary(user_id);

-- Add comments for documentation
COMMENT ON TABLE proxy_metrics_events IS 'Raw metric events collected from proxy instances';
COMMENT ON TABLE proxy_metrics_daily IS 'Aggregated daily metrics for proxy instances';
COMMENT ON TABLE proxy_metrics_aggregation IS 'Period-based aggregated metrics for proxy instances';
COMMENT ON TABLE proxy_metrics_summary IS 'Current summary metrics for quick access';

COMMENT ON COLUMN proxy_metrics_events.event_type IS 'Type of metric event: request, error, connection, latency';
COMMENT ON COLUMN proxy_metrics_daily.uptime_percentage IS 'Percentage of time proxy was healthy during the day';
COMMENT ON COLUMN proxy_metrics_daily.p95_latency_ms IS '95th percentile latency in milliseconds';
COMMENT ON COLUMN proxy_metrics_daily.p99_latency_ms IS '99th percentile latency in milliseconds';

COMMENT ON COLUMN proxy_metrics_summary.request_count_1h IS 'Request count in the last hour';
COMMENT ON COLUMN proxy_metrics_summary.request_count_24h IS 'Request count in the last 24 hours';
COMMENT ON COLUMN proxy_metrics_summary.success_rate_1h IS 'Success rate percentage in the last hour';
COMMENT ON COLUMN proxy_metrics_summary.success_rate_24h IS 'Success rate percentage in the last 24 hours';
