# Use a Node.js base image for the streaming proxy
FROM node:18-alpine

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json to leverage Docker cache
COPY services/streaming-proxy/package*.json ./

# Install Node.js dependencies
RUN npm ci

# Copy the rest of the application code
COPY services/streaming-proxy/ .

# Expose the port the streaming proxy listens on
EXPOSE 3001

# Start the streaming proxy
CMD ["npm", "start"]
