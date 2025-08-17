# Use a Node.js base image for the API backend
FROM node:18-alpine

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json to leverage Docker cache
COPY services/api-backend/package*.json ./

# Install Node.js dependencies
RUN npm ci

# Copy the rest of the application code
COPY services/api-backend/ .

# Expose the port the API backend listens on
EXPOSE 3000

# Start the API backend
CMD ["npm", "start"]
