# Node.js API backend
FROM node:18-alpine
WORKDIR /app

# Install deps using files in the build context (services/api-backend as context)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY . .

# Health port
EXPOSE 3000

# Run as non-root where possible
USER node

# Use --import for ES modules tracing instead of --require
CMD ["node", "--import", "./tracing.js", "server.js"]
