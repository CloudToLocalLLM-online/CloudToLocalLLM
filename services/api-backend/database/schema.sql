-- CloudToLocalLLM Tunnel System Database Schema (SQLite)
-- Version: 1.0.0
-- Description: Minimal SQLite schema for tunnel system functionality

-- User sessions table
CREATE TABLE IF NOT EXISTS user_sessions (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    user_id TEXT NOT NULL,
    jwt_token_hash TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    last_activity DATETIME DEFAULT CURRENT_TIMESTAMP,
    ip_address TEXT,
    user_agent TEXT,
    is_active INTEGER DEFAULT 1,

    -- Unique constraint
    UNIQUE (user_id, jwt_token_hash)
);

-- Create indexes for user_sessions
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_last_activity ON user_sessions(last_activity);
CREATE INDEX IF NOT EXISTS idx_user_sessions_is_active ON user_sessions(is_active);

-- Tunnel connections table (simplified for SQLite)
CREATE TABLE IF NOT EXISTS tunnel_connections (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    user_id TEXT NOT NULL,
    connection_id TEXT UNIQUE NOT NULL,
    session_id TEXT REFERENCES user_sessions(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'connecting',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    connected_at DATETIME,
    disconnected_at DATETIME,
    last_ping DATETIME DEFAULT CURRENT_TIMESTAMP,
    ip_address TEXT,
    user_agent TEXT,

    -- Connection metadata
    client_version TEXT,
    platform TEXT,

    -- Performance metrics
    request_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    bytes_sent INTEGER DEFAULT 0,
    bytes_received INTEGER DEFAULT 0
);

-- Create indexes for tunnel_connections
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_user_id ON tunnel_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_status ON tunnel_connections(status);
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_created_at ON tunnel_connections(created_at);
CREATE INDEX IF NOT EXISTS idx_tunnel_connections_session_id ON tunnel_connections(session_id);

-- Basic audit logs table (simplified for SQLite)
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    user_id TEXT,
    session_id TEXT REFERENCES user_sessions(id) ON DELETE SET NULL,

    -- Event details
    event_type TEXT NOT NULL,
    event_category TEXT NOT NULL,
    action TEXT NOT NULL,
    resource TEXT,

    -- Context
    ip_address TEXT,
    user_agent TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,

    -- Additional data
    metadata TEXT, -- JSON as text in SQLite
    severity TEXT DEFAULT 'info'
);

-- Create indexes for audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
