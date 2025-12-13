# Node.js streaming proxy
FROM node:20-bullseye-slim
WORKDIR /app

# Create cloudtolocalllm user
RUN useradd -r -s /bin/false cloudtolocalllm

# Install deps using files in the build context (services/streaming-proxy as context)
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership for cloudtolocalllm user
RUN chown -R cloudtolocalllm:cloudtolocalllm /app

EXPOSE 3001
USER cloudtolocalllm

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
