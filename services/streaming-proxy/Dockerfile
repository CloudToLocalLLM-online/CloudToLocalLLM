# Node.js streaming proxy
FROM node:18-alpine
WORKDIR /app

# Install deps using files in the build context (services/streaming-proxy as context)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY . .

EXPOSE 3001
USER node
# Use --import for ES modules tracing instead of --require
CMD ["node", "--import", "./tracing.js", "proxy-server.js"]
