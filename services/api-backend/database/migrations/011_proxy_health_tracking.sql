-- Migration: Proxy Health Tracking
-- Description: Create tables for tracking proxy health status and recovery attempts
-- Validates: Requirements 5.3

-- Create proxy_health_status table
CREATE TABLE IF NOT EXISTS proxy_health_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'unknown',
  last_check TIMESTAMP,
  consecutive_failures INTEGER DEFAULT 0,
  recovery_attempts INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_metrics table
CREATE TABLE IF NOT EXISTS proxy_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  request_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  average_latency FLOAT DEFAULT 0,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (proxy_id) REFERENCES proxy_health_status(proxy_id) ON DELETE CASCADE
);

-- Create proxy_recovery_log table
CREATE TABLE IF NOT EXISTS proxy_recovery_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  recovery_attempt_number INTEGER NOT NULL,
  status VARCHAR(50) NOT NULL,
  error_message TEXT,
  recovery_duration_ms INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (proxy_id) REFERENCES proxy_health_status(proxy_id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_proxy_health_status_user_id ON proxy_health_status(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_health_status_status ON proxy_health_status(status);
CREATE INDEX IF NOT EXISTS idx_proxy_metrics_proxy_id ON proxy_metrics(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_recovery_log_proxy_id ON proxy_recovery_log(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_recovery_log_user_id ON proxy_recovery_log(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_recovery_log_created_at ON proxy_recovery_log(created_at);

-- Add comments for documentation
COMMENT ON TABLE proxy_health_status IS 'Tracks health status of streaming proxy instances';
COMMENT ON TABLE proxy_metrics IS 'Stores performance metrics for proxy instances';
COMMENT ON TABLE proxy_recovery_log IS 'Logs recovery attempts and outcomes for proxy instances';

COMMENT ON COLUMN proxy_health_status.status IS 'Current health status: healthy, degraded, unhealthy, unknown';
COMMENT ON COLUMN proxy_health_status.consecutive_failures IS 'Number of consecutive failed health checks';
COMMENT ON COLUMN proxy_health_status.recovery_attempts IS 'Number of recovery attempts made';

COMMENT ON COLUMN proxy_metrics.request_count IS 'Total number of requests processed';
COMMENT ON COLUMN proxy_metrics.success_count IS 'Number of successful requests';
COMMENT ON COLUMN proxy_metrics.error_count IS 'Number of failed requests';
COMMENT ON COLUMN proxy_metrics.average_latency IS 'Average request latency in milliseconds';

COMMENT ON COLUMN proxy_recovery_log.recovery_attempt_number IS 'Sequential number of recovery attempt';
COMMENT ON COLUMN proxy_recovery_log.status IS 'Outcome of recovery attempt: success, failed, timeout';
COMMENT ON COLUMN proxy_recovery_log.recovery_duration_ms IS 'Time taken for recovery attempt in milliseconds';
