#!/bin/bash
set -e

# Data directory
PGDATA="/var/lib/postgresql/data/pgdata"
export PGDATA

# Ensure data directory exists and has correct permissions
if [ ! -d "$PGDATA" ]; then
    mkdir -p "$PGDATA"
    chmod 700 "$PGDATA"
fi

# Initialize database if it doesn't exist
    # Stop PostgreSQL
    pg_ctl -D "$PGDATA" -m fast -w stop
fi

# Robustness check: Ensure database exists even if PG_VERSION is present
# This handles cases where initialization failed or was interrupted
echo "Checking if database $POSTGRES_DB exists..."
pg_ctl -D "$PGDATA" -w start

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
