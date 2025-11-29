#!/bin/bash
set -e

# Data directory
PGDATA="/var/lib/postgresql/data/pgdata"
export PGDATA
export PGPASSWORD="$POSTGRES_PASSWORD"
export PGUSER="$POSTGRES_USER"

# Ensure data directory exists and has correct permissions
if [ ! -d "$PGDATA" ]; then
    mkdir -p "$PGDATA"
    chmod 700 "$PGDATA"
fi

# Function to initialize database
initialize_db() {
    echo "Initializing PostgreSQL database..."
    # Ensure directory is empty/clean before initdb
    rm -rf "$PGDATA"/*
    
    initdb --username="$POSTGRES_USER" --pwfile=<(echo "$POSTGRES_PASSWORD") --auth=scram-sha-256 --encoding=UTF8 -D "$PGDATA"

    # Configure PostgreSQL to listen on all interfaces
    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "host all all 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"
    echo "host all all ::/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"

    # Start PostgreSQL temporarily for initialization scripts
    pg_ctl -D "$PGDATA" -w start

    echo "Running initialization scripts..."
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" ;;
            *.sql)    echo "$0: running $f"; psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" -f "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
    done

    # Stop PostgreSQL
    pg_ctl -D "$PGDATA" -m fast -w stop
}

# Initialize database if it doesn't exist
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    initialize_db
fi

# Robustness check: Ensure database exists even if PG_VERSION is present
echo "Checking if database $POSTGRES_DB exists..."

# Try to start PostgreSQL
if ! pg_ctl -D "$PGDATA" -w start; then
    echo "Failed to start PostgreSQL. Data directory might be corrupted. Re-initializing..."
    initialize_db
    # Start again to proceed with DB check (although init_db stops it, so we start it again)
    pg_ctl -D "$PGDATA" -w start
fi

if ! psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB'" | grep -q 1; then
    echo "Database $POSTGRES_DB not found. Running initialization scripts..."
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" ;;
            *.sql)    echo "$0: running $f"; psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" -f "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
    done
else
    echo "Database $POSTGRES_DB exists."
fi

pg_ctl -D "$PGDATA" -m fast -w stop

echo "Starting PostgreSQL..."
exec postgres -D "$PGDATA" -c logging_collector=off
