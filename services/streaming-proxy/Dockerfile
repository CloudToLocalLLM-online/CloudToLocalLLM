# Node.js streaming proxy
FROM node:18-alpine
WORKDIR /app

# Install deps using files in the build context (services/streaming-proxy as context)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership for node user
RUN chown -R node:node /app

EXPOSE 3001
USER node

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
