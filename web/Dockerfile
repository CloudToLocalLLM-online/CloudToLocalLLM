# Use a Flutter base image for building the Flutter web app
FROM cirrusci/flutter:stable AS build

# Set the working directory
WORKDIR /app

# Copy the Flutter application source code
COPY . /app

# Get Flutter dependencies
RUN flutter pub get

# Build the Flutter web app
RUN flutter build web --release

# Use a lightweight Nginx image for serving the built application
FROM nginx:alpine

# Copy the built Flutter web app from the build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80 for the web server
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]