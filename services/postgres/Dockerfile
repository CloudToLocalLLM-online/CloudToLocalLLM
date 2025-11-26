# ============================================================================
# PostgreSQL Dockerfile for CloudToLocalLLM
# Uses Fedora base with cloudtolocalllm user (UID 1000)
# ============================================================================
FROM cloudtolocalllm/base:latest

# Switch to root to install PostgreSQL
USER root

# Install PostgreSQL
RUN dnf -y install postgresql-server postgresql-contrib && \
    dnf clean all

# Create necessary directories with correct ownership
RUN mkdir -p /var/lib/postgresql/data && \
    chown -R cloudtolocalllm:cloudtolocalllm /var/lib/postgresql && \
    chmod 700 /var/lib/postgresql/data

# Copy entrypoint script
COPY services/postgres/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Initialize the database as cloudtolocalllm user
USER cloudtolocalllm
WORKDIR /var/lib/postgresql

# Set environment variables
ENV PGDATA=/var/lib/postgresql/data/pgdata
ENV PATH="/usr/bin:$PATH"

# Copy initialization script
COPY --chown=cloudtolocalllm:cloudtolocalllm config/postgres/init.sh /docker-entrypoint-initdb.d/init.sh
RUN chmod +x /docker-entrypoint-initdb.d/init.sh

EXPOSE 5432

ENTRYPOINT ["docker-entrypoint.sh"]
CMD []
