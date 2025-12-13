# ============================================================================
# Runtime Dockerfile for CloudToLocalLLM Web Application
# Uses Ubuntu base with nginx
# ============================================================================
FROM ubuntu:22.04

# Install nginx and create user
RUN apt-get update && \
    apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* && \
    useradd -r -s /bin/false cloudtolocalllm

# Configure Nginx
COPY web/nginx-main.conf /etc/nginx/nginx.conf
COPY web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=cloudtolocalllm:cloudtolocalllm build/web /usr/share/nginx/html

# Fix permissions for non-root Nginx
RUN chown -R cloudtolocalllm:cloudtolocalllm /usr/share/nginx/html /var/log/nginx /var/lib/nginx /run && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod -R 770 /var/log/nginx /var/lib/nginx /run && \
    touch /var/log/nginx/error.log && \
    chown cloudtolocalllm:cloudtolocalllm /var/log/nginx/error.log

# Switch to non-root user
USER cloudtolocalllm

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]