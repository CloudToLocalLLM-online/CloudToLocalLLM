-- CloudToLocalLLM Tunnel System Database Schema
-- Version: 1.0.0
-- Description: Database schema for secure tunnel system with user sessions, connections, and audit logging

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User sessions table
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    jwt_token_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    
    -- Indexes
    CONSTRAINT user_sessions_user_id_idx UNIQUE (user_id, jwt_token_hash)
);

-- Create indexes for user_sessions
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_last_activity ON user_sessions(last_activity);
CREATE INDEX IF NOT EXISTS idx_user_sessions_is_active ON user_sessions(is_active);

-- Tunnel connections table
CREATE TABLE IF NOT EXISTS tunnel_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    connection_id VARCHAR(255) UNIQUE NOT NULL,
    session_id UUID REFERENCES user_sessions(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'connecting',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    connected_at TIMESTAMP WITH TIME ZONE,
    disconnected_at TIMESTAMP WITH TIME ZONE,
    last_ping TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT,
    
    -- Connection metadata
    client_version VARCHAR(100),
    platform VARCHAR(50),
    
    -- Performance metrics
    request_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    bytes_sent BIGINT DEFAULT 0,
    bytes_received BIGINT DEFAULT 0,
    
    -- Connection quality
    avg_latency_ms INTEGER,
    max_latency_ms INTEGER,
    packet_loss_rate DECIMAL(5,4) DEFAULT 0.0000,
    
    CONSTRAINT valid_status CHECK (status IN ('connecting', 'connected', 'disconnected', 'error', 'timeout'))
);

-- Create indexes for tunnel_connections
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_user_id ON tunnel_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_status ON tunnel_connections(status);
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_created_at ON tunnel_connections(created_at);
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_session_id ON tunnel_connections(session_id);

-- HTTP requests table for tracking tunnel requests
CREATE TABLE IF NOT EXISTS tunnel_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    connection_id UUID REFERENCES tunnel_connections(id) ON DELETE CASCADE,
    correlation_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    
    -- Request details
    method VARCHAR(10) NOT NULL,
    path TEXT NOT NULL,
    headers JSONB,
    body_size INTEGER DEFAULT 0,
    
    -- Response details
    status_code INTEGER,
    response_headers JSONB,
    response_size INTEGER DEFAULT 0,
    
    -- Timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,
    
    -- Status
    request_status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,
    
    CONSTRAINT valid_request_status CHECK (request_status IN ('pending', 'processing', 'completed', 'failed', 'timeout'))
);

-- Create indexes for tunnel_requests
CREATE INDEX IF NOT EXISTS idx_tunnel_requests_connection_id ON tunnel_requests(connection_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_requests_correlation_id ON tunnel_requests(correlation_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_requests_user_id ON tunnel_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_requests_created_at ON tunnel_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_tunnel_requests_status ON tunnel_requests(request_status);

-- Audit logs table for security and compliance
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255),
    session_id UUID REFERENCES user_sessions(id) ON DELETE SET NULL,
    
    -- Event details
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(255),
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Additional data
    metadata JSONB,
    severity VARCHAR(20) DEFAULT 'info',
    
    -- Correlation
    correlation_id VARCHAR(255),
    request_id UUID,
    
    CONSTRAINT valid_severity CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT valid_event_category CHECK (event_category IN ('authentication', 'authorization', 'connection', 'request', 'security', 'system', 'error'))
);

-- Create indexes for audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_category ON audit_logs(event_category);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON audit_logs(severity);
CREATE INDEX IF NOT EXISTS idx_audit_logs_ip_address ON audit_logs(ip_address);

-- Security events table for detailed security monitoring
CREATE TABLE IF NOT EXISTS security_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255),
    
    -- Event classification
    event_type VARCHAR(100) NOT NULL,
    threat_level VARCHAR(20) NOT NULL DEFAULT 'low',
    confidence_score DECIMAL(3,2) DEFAULT 0.50,
    
    -- Event details
    source_ip INET NOT NULL,
    target_resource VARCHAR(255),
    attack_vector VARCHAR(100),
    
    -- Detection
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    detection_method VARCHAR(100),
    rule_id VARCHAR(100),
    
    -- Response
    blocked BOOLEAN DEFAULT false,
    response_action VARCHAR(100),
    
    -- Additional context
    user_agent TEXT,
    request_headers JSONB,
    payload_sample TEXT,
    metadata JSONB,
    
    CONSTRAINT valid_threat_level CHECK (threat_level IN ('low', 'medium', 'high', 'critical'))
);

-- Create indexes for security_events
CREATE INDEX IF NOT EXISTS idx_security_events_user_id ON security_events(user_id);
CREATE INDEX IF NOT EXISTS idx_security_events_event_type ON security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_security_events_threat_level ON security_events(threat_level);
CREATE INDEX IF NOT EXISTS idx_security_events_detected_at ON security_events(detected_at);
CREATE INDEX IF NOT EXISTS idx_security_events_source_ip ON security_events(source_ip);
CREATE INDEX IF NOT EXISTS idx_security_events_blocked ON security_events(blocked);

-- Performance metrics table for system monitoring
CREATE TABLE IF NOT EXISTS performance_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Metric identification
    metric_name VARCHAR(100) NOT NULL,
    metric_type VARCHAR(20) NOT NULL, -- counter, gauge, histogram
    
    -- Metric value
    value DECIMAL(15,6) NOT NULL,
    labels JSONB,
    
    -- Timing
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Context
    instance_id VARCHAR(100),
    service_name VARCHAR(100) DEFAULT 'tunnel-system',
    
    CONSTRAINT valid_metric_type CHECK (metric_type IN ('counter', 'gauge', 'histogram'))
);

-- Create indexes for performance_metrics
CREATE INDEX IF NOT EXISTS idx_performance_metrics_name ON performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_type ON performance_metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_timestamp ON performance_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_service ON performance_metrics(service_name);

-- Create a view for active connections
CREATE OR REPLACE VIEW active_connections AS
SELECT 
    tc.id,
    tc.user_id,
    tc.connection_id,
    tc.status,
    tc.created_at,
    tc.connected_at,
    tc.last_ping,
    tc.request_count,
    tc.error_count,
    tc.avg_latency_ms,
    us.jwt_token_hash,
    us.ip_address,
    us.user_agent,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - tc.connected_at)) AS connection_duration_seconds,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - tc.last_ping)) AS seconds_since_last_ping
FROM tunnel_connections tc
JOIN user_sessions us ON tc.session_id = us.id
WHERE tc.status = 'connected' 
  AND us.is_active = true 
  AND us.expires_at > CURRENT_TIMESTAMP;

-- Create a view for connection statistics
CREATE OR REPLACE VIEW connection_statistics AS
SELECT 
    DATE_TRUNC('hour', created_at) AS hour,
    COUNT(*) AS total_connections,
    COUNT(CASE WHEN status = 'connected' THEN 1 END) AS successful_connections,
    COUNT(CASE WHEN status = 'error' THEN 1 END) AS failed_connections,
    AVG(EXTRACT(EPOCH FROM (COALESCE(disconnected_at, CURRENT_TIMESTAMP) - connected_at))) AS avg_duration_seconds,
    AVG(request_count) AS avg_requests_per_connection,
    AVG(error_count) AS avg_errors_per_connection
FROM tunnel_connections
WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;

-- Function to clean up expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete expired sessions
    DELETE FROM user_sessions 
    WHERE expires_at < CURRENT_TIMESTAMP 
       OR last_activity < CURRENT_TIMESTAMP - INTERVAL '7 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log cleanup action
    INSERT INTO audit_logs (event_type, event_category, action, metadata)
    VALUES ('session_cleanup', 'system', 'cleanup_expired_sessions', 
            jsonb_build_object('deleted_sessions', deleted_count));
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old audit logs
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Keep audit logs for 90 days
    DELETE FROM audit_logs 
    WHERE timestamp < CURRENT_TIMESTAMP - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old performance metrics
CREATE OR REPLACE FUNCTION cleanup_old_metrics()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Keep metrics for 30 days
    DELETE FROM performance_metrics 
    WHERE timestamp < CURRENT_TIMESTAMP - INTERVAL '30 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
