# ============================================================================
# Runtime Dockerfile for CloudToLocalLLM Web Application
# Uses artifacts from the Universal Builder
# ============================================================================
FROM cloudtolocalllm/base:latest

# Switch to root to install Nginx
# Fix permissions for non-root Nginx
RUN chown -R cloudtolocalllm:cloudtolocalllm /usr/share/nginx/html /var/log/nginx /var/lib/nginx /run && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod -R 770 /var/log/nginx /var/lib/nginx /run && \
    touch /var/log/nginx/error.log && \
    chown cloudtolocalllm:cloudtolocalllm /var/log/nginx/error.log

# Switch to non-root user
USER cloudtolocalllm

EXPOSE 8080
CMD ["nginx", "-g", "daemon off; pid /tmp/nginx.pid; error_log /var/log/nginx/error.log;"]