# ============================================================================
# Runtime Dockerfile for CloudToLocalLLM Web Application
# Uses artifacts from the Universal Builder
# ============================================================================
FROM cloudtolocalllm/base:latest

# Switch to root to install Nginx
USER root
RUN dnf -y install nginx && \
    dnf clean all

# Configure Nginx
COPY web/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Flutter web app from local artifacts
# Ensure ownership by cloudtolocalllm
COPY --chown=cloudtolocalllm:cloudtolocalllm build/web /usr/share/nginx/html

# Fix permissions
RUN chown -R cloudtolocalllm:cloudtolocalllm /usr/share/nginx/html /var/log/nginx /run && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod -R 770 /var/log/nginx /run

# Switch to non-root user
USER cloudtolocalllm

EXPOSE 8080
CMD ["nginx", "-g", "pid /tmp/nginx.pid; daemon off;"]