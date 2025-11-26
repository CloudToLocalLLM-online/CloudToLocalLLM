#!/bin/bash
set -e

# Ensure PGDATA directory exists
if [ ! -d "$PGDATA" ]; then
    mkdir -p "$PGDATA"
    chmod 700 "$PGDATA"
fi

# Initialize database if version file doesn't exist
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL database in $PGDATA..."
    echo "$POSTGRES_PASSWORD" > /tmp/pwfile
    initdb -D "$PGDATA" -U "$POSTGRES_USER" --pwfile=/tmp/pwfile
    rm /tmp/pwfile
    
    # Configure access
    echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
    echo "listen_addresses='*'" >> "$PGDATA/postgresql.conf"
fi

# Start PostgreSQL in background
echo "Starting PostgreSQL..."
postgres -D "$PGDATA" &
PID=$!

# Wait for PostgreSQL to start
echo "Waiting for PostgreSQL to be ready..."
export PGPASSWORD="$POSTGRES_PASSWORD"
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
    echo "Waiting for PostgreSQL to start..."
    sleep 1
done

# Run initialization script if it exists
if [ -f /docker-entrypoint-initdb.d/init.sh ]; then
    echo "Running initialization script..."
    # Source the script so it runs in current shell environment if needed, 
    # but init.sh uses psql so running it as executable is fine.
    /docker-entrypoint-initdb.d/init.sh
fi

# Wait for the background process
echo "PostgreSQL started and initialized. Waiting for process $PID..."
wait $PID
