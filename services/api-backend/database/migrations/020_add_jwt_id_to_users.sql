-- Add jwt_id column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS jwt_id TEXT UNIQUE;
CREATE INDEX IF NOT EXISTS idx_users_jwt_id ON users(jwt_id);
