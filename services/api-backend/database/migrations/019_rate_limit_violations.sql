-- Rate Limit Violations Tracking Table
-- Tracks all rate limit violations for analysis and monitoring

CREATE TABLE IF NOT EXISTS rate_limit_violations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  violation_type VARCHAR(50) NOT NULL,
  endpoint VARCHAR(255),
  method VARCHAR(10),
  ip_address VARCHAR(45),
  user_agent TEXT,
  violation_context JSONB,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for efficient querying
CREATE INDEX IF NOT EXISTS idx_rate_limit_violations_user_id 
  ON rate_limit_violations(user_id);

CREATE INDEX IF NOT EXISTS idx_rate_limit_violations_timestamp 
  ON rate_limit_violations(timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_rate_limit_violations_ip_address 
  ON rate_limit_violations(ip_address);

CREATE INDEX IF NOT EXISTS idx_rate_limit_violations_violation_type 
  ON rate_limit_violations(violation_type);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_rate_limit_violations_user_timestamp 
  ON rate_limit_violations(user_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_rate_limit_violations_ip_timestamp 
  ON rate_limit_violations(ip_address, timestamp DESC);

-- Table for rate limit violation statistics
CREATE TABLE IF NOT EXISTS rate_limit_violation_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ip_address VARCHAR(45),
  violation_count INTEGER DEFAULT 0,
  last_violation_time TIMESTAMP,
  first_violation_time TIMESTAMP,
  violation_types JSONB,
  period_start TIMESTAMP,
  period_end TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for stats queries
CREATE INDEX IF NOT EXISTS idx_rate_limit_violation_stats_user_id 
  ON rate_limit_violation_stats(user_id);

CREATE INDEX IF NOT EXISTS idx_rate_limit_violation_stats_ip_address 
  ON rate_limit_violation_stats(ip_address);

CREATE INDEX IF NOT EXISTS idx_rate_limit_violation_stats_period 
  ON rate_limit_violation_stats(period_start, period_end);
