-- Migration: Proxy Failover and Redundancy
-- Description: Create tables for tracking proxy instances, failover configurations, and redundancy management
-- Validates: Requirements 5.8

-- Create proxy_instances table
CREATE TABLE IF NOT EXISTS proxy_instances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  instance_name VARCHAR(255) NOT NULL,
  instance_type VARCHAR(50) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'unknown',
  priority INTEGER NOT NULL DEFAULT 100,
  weight INTEGER NOT NULL DEFAULT 100,
  health_status VARCHAR(50) NOT NULL DEFAULT 'unknown',
  last_health_check TIMESTAMP,
  consecutive_failures INTEGER NOT NULL DEFAULT 0,
  total_requests BIGINT NOT NULL DEFAULT 0,
  successful_requests BIGINT NOT NULL DEFAULT 0,
  failed_requests BIGINT NOT NULL DEFAULT 0,
  average_latency_ms FLOAT NOT NULL DEFAULT 0,
  error_rate FLOAT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(proxy_id, instance_name)
);

-- Create proxy_failover_configurations table
CREATE TABLE IF NOT EXISTS proxy_failover_configurations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  failover_strategy VARCHAR(50) NOT NULL DEFAULT 'priority',
  health_check_interval_seconds INTEGER NOT NULL DEFAULT 30,
  health_check_timeout_seconds INTEGER NOT NULL DEFAULT 5,
  unhealthy_threshold INTEGER NOT NULL DEFAULT 3,
  healthy_threshold INTEGER NOT NULL DEFAULT 2,
  max_recovery_attempts INTEGER NOT NULL DEFAULT 3,
  recovery_backoff_seconds INTEGER NOT NULL DEFAULT 5,
  enable_auto_failover BOOLEAN NOT NULL DEFAULT true,
  enable_auto_recovery BOOLEAN NOT NULL DEFAULT true,
  enable_load_balancing BOOLEAN NOT NULL DEFAULT false,
  load_balancing_algorithm VARCHAR(50) DEFAULT 'round_robin',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_failover_events table
CREATE TABLE IF NOT EXISTS proxy_failover_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  source_instance_id UUID,
  target_instance_id UUID,
  reason VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  error_message TEXT,
  duration_ms INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (source_instance_id) REFERENCES proxy_instances(id) ON DELETE SET NULL,
  FOREIGN KEY (target_instance_id) REFERENCES proxy_instances(id) ON DELETE SET NULL
);

-- Create proxy_redundancy_status table
CREATE TABLE IF NOT EXISTS proxy_redundancy_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  total_instances INTEGER NOT NULL DEFAULT 0,
  healthy_instances INTEGER NOT NULL DEFAULT 0,
  unhealthy_instances INTEGER NOT NULL DEFAULT 0,
  active_instance_id UUID,
  backup_instance_ids UUID[] DEFAULT ARRAY[]::UUID[],
  last_failover_at TIMESTAMP,
  last_failover_reason VARCHAR(255),
  redundancy_level VARCHAR(50) NOT NULL DEFAULT 'single',
  is_degraded BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (active_instance_id) REFERENCES proxy_instances(id) ON DELETE SET NULL
);

-- Create proxy_instance_metrics table
CREATE TABLE IF NOT EXISTS proxy_instance_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instance_id UUID NOT NULL,
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  cpu_percent FLOAT NOT NULL,
  memory_percent FLOAT NOT NULL,
  request_rate FLOAT NOT NULL,
  average_latency_ms FLOAT NOT NULL,
  error_rate FLOAT NOT NULL,
  connection_count INTEGER NOT NULL,
  throughput_mbps FLOAT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (instance_id) REFERENCES proxy_instances(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_proxy_instances_proxy_id ON proxy_instances(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_instances_user_id ON proxy_instances(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_instances_status ON proxy_instances(status);
CREATE INDEX IF NOT EXISTS idx_proxy_instances_health_status ON proxy_instances(health_status);
CREATE INDEX IF NOT EXISTS idx_proxy_instances_is_active ON proxy_instances(is_active);

CREATE INDEX IF NOT EXISTS idx_proxy_failover_configurations_proxy_id ON proxy_failover_configurations(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_failover_configurations_user_id ON proxy_failover_configurations(user_id);

CREATE INDEX IF NOT EXISTS idx_proxy_failover_events_proxy_id ON proxy_failover_events(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_failover_events_user_id ON proxy_failover_events(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_failover_events_created_at ON proxy_failover_events(created_at);
CREATE INDEX IF NOT EXISTS idx_proxy_failover_events_status ON proxy_failover_events(status);

CREATE INDEX IF NOT EXISTS idx_proxy_redundancy_status_proxy_id ON proxy_redundancy_status(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_redundancy_status_user_id ON proxy_redundancy_status(user_id);

CREATE INDEX IF NOT EXISTS idx_proxy_instance_metrics_instance_id ON proxy_instance_metrics(instance_id);
CREATE INDEX IF NOT EXISTS idx_proxy_instance_metrics_proxy_id ON proxy_instance_metrics(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_instance_metrics_created_at ON proxy_instance_metrics(created_at);

-- Add comments for documentation
COMMENT ON TABLE proxy_instances IS 'Tracks individual proxy instances and their health status';
COMMENT ON TABLE proxy_failover_configurations IS 'Defines failover and redundancy configuration for proxies';
COMMENT ON TABLE proxy_failover_events IS 'Records failover events and their outcomes';
COMMENT ON TABLE proxy_redundancy_status IS 'Current redundancy status and active instance information';
COMMENT ON TABLE proxy_instance_metrics IS 'Performance metrics for individual proxy instances';

COMMENT ON COLUMN proxy_instances.priority IS 'Priority for failover (lower number = higher priority)';
COMMENT ON COLUMN proxy_instances.weight IS 'Weight for load balancing (higher weight = more traffic)';
COMMENT ON COLUMN proxy_instances.health_status IS 'Current health status: healthy, unhealthy, unknown';
COMMENT ON COLUMN proxy_instances.consecutive_failures IS 'Number of consecutive health check failures';

COMMENT ON COLUMN proxy_failover_configurations.failover_strategy IS 'Strategy for failover: priority, round_robin, least_connections';
COMMENT ON COLUMN proxy_failover_configurations.load_balancing_algorithm IS 'Algorithm for load balancing: round_robin, least_connections, weighted';
COMMENT ON COLUMN proxy_failover_configurations.enable_auto_failover IS 'Enable automatic failover on instance failure';
COMMENT ON COLUMN proxy_failover_configurations.enable_auto_recovery IS 'Enable automatic recovery of failed instances';

COMMENT ON COLUMN proxy_redundancy_status.redundancy_level IS 'Redundancy level: single, dual, multi';
COMMENT ON COLUMN proxy_redundancy_status.is_degraded IS 'Whether the proxy is operating in degraded mode';
