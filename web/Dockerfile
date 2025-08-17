# Use a Node.js base image for building the Flutter web app
FROM node:18-alpine AS build

# Set the working directory
WORKDIR /app

# Copy the web application source code
COPY . /app

# Install Node.js dependencies and build the Flutter web app
RUN npm install
RUN npm run build

# Use a lightweight Nginx image for serving the built application
FROM nginx:alpine

# Copy the built Flutter web app from the build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80 for the web server
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]