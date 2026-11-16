#!/usr/bin/env bash
# Service health checks run from CI against the VPS (after a deploy and after a reboot).
# Usage: health-check.sh <server-ip>
set -euo pipefail

SERVER_IP="${1:?usage: health-check.sh <server-ip>}"

echo "Running service health checks..."

# Nginx is responding (the catch-all vhost is HTTP-only)
CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://$SERVER_IP/" || true)
[ "$CODE" = "200" ] \
  && echo "✅ Nginx HTTP responding" \
  || { echo "❌ Nginx not responding on HTTP (got $CODE)"; exit 1; }

# Immich public proxy is reachable
CODE=$(curl -sk -o /dev/null -w '%{http_code}' \
  -H 'Host: share.photos.crapadouille.fr' "https://$SERVER_IP/share/healthcheck" || true)
echo "$CODE" | grep -qE '200|302' \
  && echo "✅ Immich public proxy responding" \
  || { echo "❌ Immich public proxy not responding (got $CODE)"; exit 1; }

# VPN-restricted services return 403 from outside
for host in adguard tandoor home grafana photos; do
  CODE=$(curl -sk -o /dev/null -w '%{http_code}' \
    -H "Host: $host.crapadouille.fr" "https://$SERVER_IP/" || true)
  [ "$CODE" = "403" ] \
    && echo "✅ $host.crapadouille.fr correctly restricted (403)" \
    || { echo "❌ $host.crapadouille.fr returned $CODE (expected 403)"; exit 1; }
done

echo "All service health checks passed!"
