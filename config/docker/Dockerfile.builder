# Universal Builder for CloudToLocalLLM
# Builds artifacts for Web (Flutter), API (Node), and Streaming Proxy (Node)

FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Install Node.js 20 (LTS) - Run as root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node --version && \
    npm --version

# Fix Flutter SDK ownership/permissions so non-root user can use it
# The SDK is at /sdks/flutter in this image
RUN chown -R 1000:1000 /sdks/flutter && \
    chmod -R u+w /sdks/flutter && \
    git config --global --add safe.directory /sdks/flutter

# Create app directory and fix ownership
WORKDIR /app
RUN chown -R 1000:1000 /app

# Switch to non-root user (UID 1000 is standard in this image)
USER 1000

# Copy ALL source code as non-root user
COPY --chown=1000:1000 . .

# --- Build Web (Flutter) ---
RUN echo "Building Flutter Web..."
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release

# --- Build API Backend (Node) ---
RUN echo "Building API Backend..."
WORKDIR /app/services/api-backend
# Install production dependencies only
RUN npm ci --omit=dev

# --- Build Streaming Proxy (Node) ---
RUN echo "Building Streaming Proxy..."
WORKDIR /app/services/streaming-proxy
# Install production dependencies only
RUN npm ci --omit=dev

# Final stage: Minimal image to hold artifacts (optional, but good for inspection)
# We will push this image to Docker Hub
FROM debian:bookworm-slim
WORKDIR /artifacts

# Copy Web artifacts
COPY --from=builder /app/build/web ./web

# Copy API artifacts (node_modules + code)
# We copy the whole directory because the runtime needs code + modules
COPY --from=builder /app/services/api-backend ./api-backend

# Copy Streaming artifacts
COPY --from=builder /app/services/streaming-proxy ./streaming-proxy

# List artifacts for verification
RUN ls -R /artifacts
