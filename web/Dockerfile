# ============================================================================
# Runtime Dockerfile for CloudToLocalLLM Web Application
# Uses artifacts from the Universal Builder
# ============================================================================
FROM nginx:alpine

# Provide a default server config listening on 8080 with /health endpoint
COPY web/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Flutter web app from local artifacts (downloaded by workflow)
COPY build/web /usr/share/nginx/html

# Fix permissions for non-root user (UID 101)
RUN chown -R 101:101 /usr/share/nginx/html /var/cache/nginx /var/log/nginx /var/run && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod -R 770 /var/cache/nginx /var/log/nginx /var/run
USER 101

EXPOSE 8080
CMD ["nginx", "-g", "pid /tmp/nginx.pid; daemon off;"]