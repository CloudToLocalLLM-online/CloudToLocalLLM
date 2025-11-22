-- Migration: Add user activity tracking tables
-- Purpose: Track user operations and usage metrics for analytics and audit purposes
-- Validates: Requirements 3.4, 3.10

-- User activity logs table for tracking user operations
CREATE TABLE IF NOT EXISTS user_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  resource_type TEXT,
  resource_id TEXT,
  details JSONB DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  severity TEXT DEFAULT 'info' CHECK (severity IN ('debug', 'info', 'warn', 'error', 'critical'))
);

-- User usage metrics table for tracking usage per user
CREATE TABLE IF NOT EXISTS user_usage_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL UNIQUE,
  total_requests INTEGER DEFAULT 0,
  total_api_calls INTEGER DEFAULT 0,
  total_tunnels_created INTEGER DEFAULT 0,
  total_tunnels_active INTEGER DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- User activity summary table for daily/weekly/monthly aggregation
CREATE TABLE IF NOT EXISTS user_activity_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly')),
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  total_actions INTEGER DEFAULT 0,
  total_api_calls INTEGER DEFAULT 0,
  total_tunnels_created INTEGER DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, period, period_start)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_activity_logs_user_id ON user_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_logs_action ON user_activity_logs(action);
CREATE INDEX IF NOT EXISTS idx_user_activity_logs_created_at ON user_activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_activity_logs_resource_type ON user_activity_logs(resource_type);

CREATE INDEX IF NOT EXISTS idx_user_usage_metrics_user_id ON user_usage_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_user_usage_metrics_last_activity ON user_usage_metrics(last_activity DESC);

CREATE INDEX IF NOT EXISTS idx_user_activity_summary_user_id ON user_activity_summary(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_summary_period ON user_activity_summary(period);
CREATE INDEX IF NOT EXISTS idx_user_activity_summary_period_start ON user_activity_summary(period_start DESC);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_user_usage_metrics_updated_at 
  BEFORE UPDATE ON user_usage_metrics
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_activity_summary_updated_at 
  BEFORE UPDATE ON user_activity_summary
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
