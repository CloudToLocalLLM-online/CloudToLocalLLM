# ============================================================================
# Multi-stage Dockerfile for CloudToLocalLLM Web Application
# Stage 1: Build Flutter web application (using pre-built Flutter image)
# Stage 2: Serve with nginx (non-root)
# ============================================================================

# ---- Stage 1: Build Flutter Web App ----
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Fix Flutter SDK ownership and permissions (must be done as root)
RUN chown -R 1000:1000 /sdks/flutter && \
    chmod -R u+w /sdks/flutter

# Fix Git safe directory
RUN git config --global --add safe.directory /sdks/flutter

# Create app directory and fix ownership
WORKDIR /app
RUN mkdir -p /app && \
    chown -R 1000:1000 /app

# Switch to non-root user
USER 1000

# Copy source code from build context (root of repo expected)
COPY --chown=1000:1000 . .

# Clean and get dependencies
RUN flutter clean
RUN flutter pub get

# Build Flutter web app
RUN flutter build web --release

# ---- Stage 2: Serve with Nginx (non-root) ----
FROM nginx:alpine

# Provide a default server config listening on 8080 with /health endpoint
COPY web/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Flutter web app from builder stage
COPY --from=builder --chown=101:101 /app/build/web /usr/share/nginx/html

# Fix permissions for non-root user (UID 101)
RUN chown -R 101:101 /usr/share/nginx/html /var/cache/nginx /var/log/nginx /var/run && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod -R 770 /var/cache/nginx /var/log/nginx /var/run

# Switch to non-root user
USER 101

EXPOSE 8080
CMD ["nginx", "-g", "pid /tmp/nginx.pid; daemon off;"]