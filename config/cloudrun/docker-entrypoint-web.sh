#!/bin/sh
set -e

# Inject GCIP API key into index.html if placeholder exists
INDEX=/usr/share/nginx/html/index.html
if [ -n "$GCIP_API_KEY" ] && [ -f "$INDEX" ]; then
  if grep -q "\${GCIP_API_KEY}" "$INDEX"; then
    echo "[entrypoint] Injecting GCIP_API_KEY into index.html"
    sed -i "s|\${GCIP_API_KEY}|$GCIP_API_KEY|g" "$INDEX"
  fi
fi

# Render nginx config with PORT
envsubst '$PORT' < /etc/nginx/nginx.conf > /tmp/nginx.conf

# Start nginx (as nginx user)
exec nginx -c /tmp/nginx.conf -g 'daemon off;'

