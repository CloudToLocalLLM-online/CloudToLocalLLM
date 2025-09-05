# Static web served by Nginx
FROM nginx:alpine

# Provide a default server config listening on 8080 with /health endpoint
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static assets (index.html, js, images, etc.)
COPY . /usr/share/nginx/html

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]