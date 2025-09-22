# Node.js API backend
FROM node:24-alpine
WORKDIR /app

# Install deps using files in the build context (services/api-backend as context)
COPY package*.json ./
# Build tools for native modules (sqlite3)
RUN apk add --no-cache python3 make g++

RUN npm ci --omit=dev && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership for node user
RUN chown -R node:node /app

# Health port
EXPOSE 3000

# Run as non-root
USER node

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
