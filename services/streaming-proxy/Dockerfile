# Node.js streaming proxy
# Node.js streaming proxy
FROM cloudtolocalllm/base:latest
WORKDIR /app

# Install deps using files in the build context (services/streaming-proxy as context)
COPY package*.json ./
# Switch to root to install dependencies if needed (though base has node/npm)
USER root
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership for cloudtolocalllm user
RUN chown -R cloudtolocalllm:cloudtolocalllm /app

EXPOSE 3001
USER cloudtolocalllm

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
