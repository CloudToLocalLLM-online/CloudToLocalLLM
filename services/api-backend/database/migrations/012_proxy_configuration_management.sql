-- Migration: Proxy Configuration Management
-- Description: Create tables for managing proxy configuration settings
-- Validates: Requirements 5.4

-- Create proxy_configurations table
CREATE TABLE IF NOT EXISTS proxy_configurations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  max_connections INTEGER DEFAULT 100,
  timeout_seconds INTEGER DEFAULT 30,
  compression_enabled BOOLEAN DEFAULT true,
  compression_level INTEGER DEFAULT 6,
  buffer_size_kb INTEGER DEFAULT 64,
  keep_alive_enabled BOOLEAN DEFAULT true,
  keep_alive_interval_seconds INTEGER DEFAULT 30,
  ssl_verify BOOLEAN DEFAULT true,
  ssl_cert_path VARCHAR(512),
  ssl_key_path VARCHAR(512),
  rate_limit_enabled BOOLEAN DEFAULT false,
  rate_limit_requests_per_second INTEGER DEFAULT 1000,
  rate_limit_burst_size INTEGER DEFAULT 100,
  retry_enabled BOOLEAN DEFAULT true,
  retry_max_attempts INTEGER DEFAULT 3,
  retry_backoff_ms INTEGER DEFAULT 1000,
  logging_level VARCHAR(50) DEFAULT 'info',
  metrics_collection_enabled BOOLEAN DEFAULT true,
  metrics_collection_interval_seconds INTEGER DEFAULT 60,
  health_check_enabled BOOLEAN DEFAULT true,
  health_check_interval_seconds INTEGER DEFAULT 30,
  health_check_timeout_seconds INTEGER DEFAULT 5,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create proxy_config_history table for audit trail
CREATE TABLE IF NOT EXISTS proxy_config_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  config_id UUID NOT NULL,
  previous_config JSONB,
  new_config JSONB,
  changed_fields TEXT[],
  change_reason VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (config_id) REFERENCES proxy_configurations(id) ON DELETE CASCADE
);

-- Create proxy_config_templates table for predefined configurations
CREATE TABLE IF NOT EXISTS proxy_config_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  template_config JSONB NOT NULL,
  is_default BOOLEAN DEFAULT false,
  created_by UUID NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_proxy_configurations_proxy_id ON proxy_configurations(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_configurations_user_id ON proxy_configurations(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_config_history_proxy_id ON proxy_config_history(proxy_id);
CREATE INDEX IF NOT EXISTS idx_proxy_config_history_user_id ON proxy_config_history(user_id);
CREATE INDEX IF NOT EXISTS idx_proxy_config_history_created_at ON proxy_config_history(created_at);
CREATE INDEX IF NOT EXISTS idx_proxy_config_templates_name ON proxy_config_templates(name);
CREATE INDEX IF NOT EXISTS idx_proxy_config_templates_is_default ON proxy_config_templates(is_default);

-- Add comments for documentation
COMMENT ON TABLE proxy_configurations IS 'Stores configuration settings for streaming proxy instances';
COMMENT ON TABLE proxy_config_history IS 'Audit trail of configuration changes for proxy instances';
COMMENT ON TABLE proxy_config_templates IS 'Predefined configuration templates for proxy instances';

COMMENT ON COLUMN proxy_configurations.max_connections IS 'Maximum number of concurrent connections allowed';
COMMENT ON COLUMN proxy_configurations.timeout_seconds IS 'Request timeout in seconds';
COMMENT ON COLUMN proxy_configurations.compression_enabled IS 'Enable/disable response compression';
COMMENT ON COLUMN proxy_configurations.compression_level IS 'Compression level (1-9, higher = more compression)';
COMMENT ON COLUMN proxy_configurations.buffer_size_kb IS 'Buffer size in kilobytes for streaming';
COMMENT ON COLUMN proxy_configurations.keep_alive_enabled IS 'Enable/disable HTTP keep-alive';
COMMENT ON COLUMN proxy_configurations.ssl_verify IS 'Enable/disable SSL certificate verification';
COMMENT ON COLUMN proxy_configurations.rate_limit_enabled IS 'Enable/disable rate limiting';
COMMENT ON COLUMN proxy_configurations.retry_enabled IS 'Enable/disable automatic retries';
COMMENT ON COLUMN proxy_configurations.logging_level IS 'Logging level: debug, info, warn, error';
COMMENT ON COLUMN proxy_configurations.metrics_collection_enabled IS 'Enable/disable metrics collection';
COMMENT ON COLUMN proxy_configurations.health_check_enabled IS 'Enable/disable health checks';

COMMENT ON COLUMN proxy_config_history.changed_fields IS 'Array of field names that were changed';
COMMENT ON COLUMN proxy_config_history.change_reason IS 'Reason for the configuration change';

COMMENT ON COLUMN proxy_config_templates.is_default IS 'Whether this is the default template for new proxies';
