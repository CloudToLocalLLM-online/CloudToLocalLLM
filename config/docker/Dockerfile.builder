# Universal Builder for CloudToLocalLLM
# Builds artifacts for Web (Flutter), API (Node), and Streaming Proxy (Node)

FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Install Node.js 20 (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node --version && \
    npm --version

# Set working directory
WORKDIR /app

# Fix permissions for Flutter SDK (if needed) and /app
# The cirruslabs image runs as root by default, but let's be safe
RUN chown -R root:root /app

# Copy ALL source code
COPY . .

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
