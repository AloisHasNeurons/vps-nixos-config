#!/usr/bin/env bash
# Wait for the VPS to come back after a reboot, then fail if any unit failed during boot.
# Usage: wait-for-reboot.sh <server-ip> [timeout-seconds]
set -euo pipefail

SERVER_IP="${1:?usage: wait-for-reboot.sh <server-ip> [timeout-seconds]}"
TIMEOUT="${2:-600}"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=5 "deploy@$SERVER_IP")

# Give the server time to actually go down, so we don't reconnect to the old boot
sleep 30

deadline=$((SECONDS + TIMEOUT))
until "${SSH[@]}" true 2>/dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "❌ Server did not come back within ${TIMEOUT}s after reboot"
    exit 1
  fi
  echo "Waiting for SSH..."
  sleep 10
done
echo "✅ SSH is back (boot: $("${SSH[@]}" uptime -s))"

# Blocks until boot finishes; exits non-zero for "degraded" (a unit failed)
STATE=$("${SSH[@]}" "timeout 300 systemctl is-system-running --wait" || true)
if [ "$STATE" != "running" ]; then
  echo "❌ System state after reboot: '${STATE}'"
  "${SSH[@]}" "systemctl --failed --no-pager" || true
  exit 1
fi
echo "✅ System is running with no failed units"
