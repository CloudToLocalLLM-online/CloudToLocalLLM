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
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL database..."
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
            *.sql)    echo "$0: running $f"; psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
    done

    # Stop PostgreSQL
    pg_ctl -D "$PGDATA" -m fast -w stop
fi

echo "Starting PostgreSQL..."
exec postgres -D "$PGDATA" -c logging_collector=off
