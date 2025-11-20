-- Create the cloud_admin user and appuser with appropriate permissions
-- This script will be executed inside the PostgreSQL pod

-- Create cloud_admin user (main admin user per GitHub secrets)
CREATE USER cloud_admin WITH PASSWORD 'CloudToLocalSecurePass2024!' CREATEDB CREATEROLE;

-- Create appuser (for API backend compatibility)
CREATE USER appuser WITH PASSWORD 'CloudToLocalSecurePass2024!';

-- Grant database ownership to cloud_admin
ALTER DATABASE cloudtolocalllm OWNER TO cloud_admin;

-- Grant all privileges on database to both users
GRANT ALL PRIVILEGES ON DATABASE cloudtolocalllm TO cloud_admin;
GRANT ALL PRIVILEGES ON DATABASE cloudtolocalllm TO appuser;

-- Connect to the database and grant schema permissions
\c cloudtolocalllm

-- Grant all privileges on all current and future tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cloud_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cloud_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO cloud_admin;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO appuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO appuser;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO appuser;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO cloud_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO cloud_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO cloud_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO appuser;

-- Verify users were created
\du
