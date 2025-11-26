#!/bin/bash
set -e

# Wait for PostgreSQL to start
until pg_isready -U "$POSTGRES_USER" -d postgres -h 127.0.0.1; do
  echo "Waiting for PostgreSQL to start..."
  sleep 1
done

# Create application user if it doesn't exist
# Create database if specified and doesn't exist
if [ -n "$POSTGRES_DB" ] && [ "$POSTGRES_DB" != "postgres" ]; then
    echo "Creating database $POSTGRES_DB..."
    # Check if database exists first to avoid error
    if ! psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB'" | grep -q 1; then
        psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$POSTGRES_DB\";"
    else
        echo "Database $POSTGRES_DB already exists."
    fi
fi

# Create application user and grant permissions
# We connect to 'postgres' to create the user, but we need to grant on the target DB.
# Grants on DATABASE can be done from anywhere, but grants on SCHEMA public need connection to target DB?
# Actually, we can just run the user creation against postgres.

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- Create application user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'appuser') THEN
            CREATE USER appuser WITH PASSWORD '${APP_USER_PASSWORD}';
        END IF;
    END
    \$\$;
    
    -- Grant connect on database
    GRANT CONNECT ON DATABASE "${POSTGRES_DB:-postgres}" TO appuser;
EOSQL

# If we have a specific DB, we might want to grant schema privileges there.
# But we can't switch DB in a single psql session easily if using heredoc? 
# Actually we can use \c but that might fail if not interactive? It works in scripts.
if [ -n "$POSTGRES_DB" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        GRANT ALL ON SCHEMA public TO appuser;
        -- Grant usage on future tables?
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO appuser;
EOSQL
fi

echo "PostgreSQL initialization complete"
