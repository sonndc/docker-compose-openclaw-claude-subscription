#!/bin/bash
set -e

CONFIG="/home/node/.openclaw/openclaw.json"

# Wait for config file to exist (created by onboard on first run)
for i in $(seq 1 30); do
  [ -f "$CONFIG" ] && break
  sleep 1
done

# Sync DASHBOARD_TOKEN from env into gateway.auth.token
if [ -n "$DASHBOARD_TOKEN" ] && [ -f "$CONFIG" ]; then
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$CONFIG','utf8'));
    if (!cfg.gateway) cfg.gateway = {};
    if (!cfg.gateway.auth) cfg.gateway.auth = {};
    cfg.gateway.auth.mode = 'token';
    cfg.gateway.auth.token = process.env.DASHBOARD_TOKEN;
    // Use 'local' mode with host network for proper dashboard access
    cfg.gateway.mode = 'local';
    fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2));
    console.log('[entrypoint] Dashboard token synced, gateway mode set to remote');
  "
fi

# Run original command
exec "$@"
