#!/bin/bash
set -e

# Wait for PostgreSQL to start
until pg_isready -U postgres; do
  echo "Waiting for PostgreSQL to start..."
  sleep 1
done

# Create application user if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create application user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'appuser') THEN
            CREATE USER appuser WITH PASSWORD '${APP_USER_PASSWORD}';
        END IF;
    END
    \$\$;

    -- Grant necessary permissions
    GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO appuser;
    GRANT ALL ON SCHEMA public TO appuser;
EOSQL

echo "PostgreSQL initialization complete"
