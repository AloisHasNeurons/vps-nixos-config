{pkgs, ...}: {
  # WireGuard Connectivity Anomaly Monitor
  # This service checks for spikes in kernel conntrack drop counters,
  # which usually indicate misclassified traffic (like our intermittent VPN drops issue).

  systemd.services.wireguard-monitor = {
    description = "WireGuard Conntrack Anomaly Monitor";
    after = ["network.target" "wireguard-wg0.service"];
    wants = ["wireguard-wg0.service"];

    path = with pkgs; [coreutils gawk];

    script = ''
      # State file to track previous drop counts
      STATE_FILE="/var/lib/wireguard-monitor/last_drops"

      # Ensure state directory exists
      mkdir -p /var/lib/wireguard-monitor

      # Read current conntrack drop counters (column 10 from /proc/net/stat/nf_conntrack)
      # We sum them across all CPUs
      CURRENT_DROPS=$(awk '{s+=$10} END {print s}' /proc/net/stat/nf_conntrack || echo 0)

      # Convert hex to decimal
      CURRENT_DROPS_DEC=$((16#$CURRENT_DROPS))

      # Read previous state
      if [ -f "$STATE_FILE" ]; then
        LAST_DROPS_DEC=$(cat "$STATE_FILE")

        # Calculate diff
        DIFF=$((CURRENT_DROPS_DEC - LAST_DROPS_DEC))

        # Threshold: if more than 50 drops happened since the last check (usually 5 mins), alert
        if [ "$DIFF" -gt 50 ]; then
          echo "🚨 CRITICAL: WireGuard Anomaly Detected! $DIFF dropped connection tracking entries in the last interval."
          echo "This could indicate kernel/firewall misclassification of UDP traffic."

          # We write to journalctl which can be picked up by alerting stacks if added later
          # (or you can manually check: journalctl -u wireguard-monitor -p warning)
        else
          echo "✅ WireGuard tracking healthy (drops delta: $DIFF)"
        fi
      else
        echo "ℹ️ Baseline established: $CURRENT_DROPS_DEC drops so far at boot/start."
      fi

      # Save state for next run
      echo "$CURRENT_DROPS_DEC" > "$STATE_FILE"
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "root"; # Needs root to read /proc/net/stat/nf_conntrack potentially
    };
  };

  # Run the monitor every 5 minutes
  systemd.timers.wireguard-monitor = {
    description = "Timer for WireGuard Conntrack Anomaly Monitor";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
    };
  };
}
