#!/bin/sh
# POSIX-compliant entrypoint for Cloud Run web container
# - Injects GCIP API key into built index.html at runtime
# - Renders nginx config with PORT env via envsubst
# - Starts nginx in foreground

# Exit on error and undefined vars; avoid masking failures
set -eu
# Enable pipefail where supported (busybox sh may not support it)
(set -o pipefail) 2>/dev/null || true

# Default PORT to 8080 for Cloud Run
PORT="${PORT:-8080}"

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

# Generate cloudrun-config.js for runtime config (preferred injection path)
if [ -z "${GCIP_API_KEY:-}" ]; then
  warn "GCIP_API_KEY is empty; continuing without runtime injection (web auth will fail)"
else
  CFG="/usr/share/nginx/html/cloudrun-config.js"
  umask 022
  printf 'window.cloudRunConfig=window.cloudRunConfig||{};window.cloudRunConfig.gcipApiKey=%s;console.log("cloudRunConfig loaded (gcipApiKey prefix)",%s);\n' \
    "'${GCIP_API_KEY}'" "'${GCIP_API_KEY%%??????????????????????????????}'" > "$CFG" || warn "Failed to write $CFG"
fi

# Optional: replace meta placeholder in index.html; do not fail container if it remains
INDEX_HTML="/usr/share/nginx/html/index.html"
if [ -f "$INDEX_HTML" ] && [ -n "${GCIP_API_KEY:-}" ]; then
  KEY_ESC="$(printf '%s' "${GCIP_API_KEY}" | sed 's/[&/]/\\&/g')"
  if sed -i "s|\${GCIP_API_KEY}|${KEY_ESC}|g" "$INDEX_HTML"; then
    if grep -q "\\${GCIP_API_KEY}" "$INDEX_HTML"; then
      warn "GCIP_API_KEY placeholder still present in index.html after injection; relying on cloudrun-config.js"
    else
      PREFIX=$(printf '%.4s' "${GCIP_API_KEY}")
      log "Injected GCIP_API_KEY into index.html (prefix ${PREFIX}****)"
    fi
  else
    warn "Failed to run sed for GCIP_API_KEY injection; relying on cloudrun-config.js"
  fi
fi

# Using static nginx config which already listens on port 8080 for Cloud Run
log "Using nginx config at /etc/nginx/nginx.conf (expected to listen on $PORT)"

# Start nginx in foreground; exec to hand off PID 1
exec nginx -g 'daemon off;'
