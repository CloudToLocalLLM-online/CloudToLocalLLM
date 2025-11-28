# Node.js API backend
# Node.js API backend
FROM cloudtolocalllm/base:latest
WORKDIR /app

# Install deps using files in the build context (services/api-backend as context)
COPY package*.json ./
# Build tools for native modules (sqlite3) - dnf is used in base image
USER root
RUN dnf install -y python3 make gcc-c++ && dnf clean all

RUN npm ci --omit=dev --ignore-scripts && npm rebuild sqlite3 && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership for cloudtolocalllm user
RUN chown -R cloudtolocalllm:cloudtolocalllm /app

# Health port
EXPOSE 3000

# Run as non-root
USER cloudtolocalllm

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
