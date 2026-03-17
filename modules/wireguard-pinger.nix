{pkgs, ...}: {
  # WireGuard Continuous Pinger
  #
  # This service continuously pings the phone's VPN IP every 1 second.
  # When a drop occurs, it immediately logs the exact timestamp to a file
  # so we can cross-reference it with the kernel WireGuard debug logs.

  systemd.services.wireguard-pinger = {
    description = "WireGuard Continuous Pinger (Phone Drops)";
    after = ["network.target" "wireguard-wg0.service"];
    wants = ["wireguard-wg0.service"];

    # We want this to run forever
    wantedBy = ["multi-user.target"];

    path = with pkgs; [iputils gawk coreutils];

    script = ''
      # The IP of the phone on the VPN
      TARGET="10.100.0.3"
      LOG_FILE="/var/log/wireguard-drops.log"

      echo "=== Started WireGuard Pinger for $TARGET at $(date) ===" >> "$LOG_FILE"

      # We ping endlessly. If ping fails (exit code > 0), we log the exact time
      # Ping prints requested packets normally. We just check if it succeeded.

      while true; do
        if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
          TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S.%3N")
          echo "[$TIMESTAMP] 🚨 DROP DETECTED: Could not reach $TARGET" >> "$LOG_FILE"

          # We could also hook this into notify-failure later if we want!
        fi
        sleep 1
      done
    '';

    serviceConfig = {
      Type = "simple";
      User = "root";
      Restart = "always";
      RestartSec = "5";
    };
  };
}
