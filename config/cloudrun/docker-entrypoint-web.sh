#!/bin/sh
# POSIX-compliant entrypoint for Cloud Run web container
# - Injects GCIP API key into built index.html at runtime
# - Renders nginx config with PORT env via envsubst
# - Starts nginx in foreground

# Exit on error and undefined vars; avoid masking failures
set -eu
# Enable pipefail where supported (busybox sh may not support it)
(set -o pipefail) 2>/dev/null || true

log() {
  # Timestamped log helper
  printf '%s %s %s\n' "[entrypoint]" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

warn() {
  log "WARN: $*"
}

error() {
  log "ERROR: $*"
}

# Inject GCIP_API_KEY into index.html meta tag (KISS)
INDEX_HTML="/usr/share/nginx/html/index.html"
if [ -f "$INDEX_HTML" ]; then
  if [ -z "${GCIP_API_KEY:-}" ]; then
    error "GCIP_API_KEY env var is empty or not set; cannot inject into index.html"
    exit 1
  fi
  # Escape replacement
  KEY_ESC="$(printf '%s' "${GCIP_API_KEY}" | sed 's/[&/]/\\&/g')"
  # Perform replacement of the literal placeholder ${GCIP_API_KEY}
  if ! sed -i "s|\${GCIP_API_KEY}|${KEY_ESC}|g" "$INDEX_HTML"; then
    error "Failed to run sed for GCIP_API_KEY injection into index.html"
    exit 1
  fi
  # Verify placeholder is gone
  if grep -q "\\${GCIP_API_KEY}" "$INDEX_HTML"; then
    error "GCIP_API_KEY placeholder still present in index.html after injection"
    exit 1
  fi
  PREFIX=$(printf '%.4s' "${GCIP_API_KEY}")
  log "Injected GCIP_API_KEY into index.html (prefix ${PREFIX}****)"
else
  error "index.html not found at $INDEX_HTML; cannot inject GCIP_API_KEY"
  exit 1
fi

# Inject PORT into nginx config (KISS)
NGINX_CONF="/etc/nginx/nginx.conf"
if [ -f "$NGINX_CONF" ]; then
  PORT_VAL="${PORT:-8080}"
  if ! sed -i "s|\${PORT}|${PORT_VAL}|g" "$NGINX_CONF"; then
    error "Failed to inject PORT into nginx config"
    exit 1
  fi
  log "Injected PORT=${PORT_VAL} into nginx config"
else
  error "Nginx config not found at $NGINX_CONF"
  exit 1
fi

# Start nginx in foreground; exec to hand off PID 1
exec nginx -g 'daemon off;'
