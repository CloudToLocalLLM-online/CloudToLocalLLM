#!/bin/bash
set -e

echo "Starting database initialization..."

# Create database if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
  SELECT 'CREATE DATABASE $POSTGRES_DB'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$POSTGRES_DB')\\gexec
EOSQL

# Create appuser if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'appuser') THEN
      CREATE USER appuser WITH PASSWORD '$APP_USER_PASSWORD';
    END IF;
  END
  \$\$;
  
  GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO appuser;
  
  -- Grant schema permissions
  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO appuser;
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO appuser;
  GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO appuser;
  
  -- Set default privileges
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO appuser;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO appuser;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO appuser;
EOSQL

echo "Database initialization completed."
