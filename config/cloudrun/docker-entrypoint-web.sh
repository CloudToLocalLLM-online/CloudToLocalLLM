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

# Render cloudrun-config.js from template with GCIP_API_KEY (preferred over mutating index.html)
TEMPLATE="/usr/share/nginx/html/cloudrun-config.template.js"
OUTPUT="/usr/share/nginx/html/cloudrun-config.js"

if [ ! -f "$TEMPLATE" ]; then
  warn "Template not found at $TEMPLATE; skipping GCIP config rendering"
else
  if [ "${GCIP_API_KEY:-}" = "" ]; then
    warn "GCIP_API_KEY is not set; rendering template with empty value"
  fi
  if command -v envsubst >/dev/null 2>&1; then
    # Only substitute GCIP_API_KEY to avoid unintended replacements
    if ! GCIP_API_KEY="${GCIP_API_KEY:-}" envsubst '$GCIP_API_KEY' < "$TEMPLATE" > "$OUTPUT"; then
      error "envsubst failed to render $OUTPUT"
      exit 1
    fi
    log "Rendered $OUTPUT from template"
  else
    warn "envsubst not found; copying template without substitution"
    cp "$TEMPLATE" "$OUTPUT"
  fi
fi

# Render nginx config using PORT env var
NGINX_CONF_SRC="/etc/nginx/nginx.conf"
NGINX_CONF_OUT="/tmp/nginx.conf"

if [ ! -f "$NGINX_CONF_SRC" ]; then
  error "Nginx config template not found at $NGINX_CONF_SRC"
  exit 1
fi

# envsubst may not be present in minimal images; the Dockerfile should install gettext
if command -v envsubst >/dev/null 2>&1; then
  if ! envsubst '$PORT' < "$NGINX_CONF_SRC" > "$NGINX_CONF_OUT"; then
    error "envsubst failed to render nginx config"
    exit 1
  fi
else
  warn "envsubst not found; copying nginx config without substitution"
  cp "$NGINX_CONF_SRC" "$NGINX_CONF_OUT"
fi

# Start nginx in foreground; exec to hand off PID 1
exec nginx -c "$NGINX_CONF_OUT" -g 'daemon off;'
