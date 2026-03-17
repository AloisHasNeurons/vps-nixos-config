{
  pkgs,
  ...
}: {
  # Universal Systemd Failure Notification Service
  #
  # This service is triggered via `OnFailure=notify-failure@%n.service`
  # on any other systemd service. It uses `curl` to send a push notification
  # to the local Gotify instance when a service crashes.

  systemd.services."notify-failure@" = {
    description = "Failure notification for %i";

    # We don't want this notification to silently fail or retry forever
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    # Needs curl and systemctl (to get service logs/status)
    path = with pkgs; [curl systemd];

    # The %i gets replaced with the name of the service that failed.
    # We fetch the last 5 log lines of the crashed service to include in the push payload.
    script = ''
            # Note: For production use, the token should ideally be loaded from Agenix,
            # but since it's an internal-only call and the Nix store is readable by root,
            # we can securely read it from a file or environment variable configured later.
            # For now, we will use a placeholder or read from a local state file if it exists.

            TOKEN_FILE="/var/lib/gotify/app_token"

            if [ ! -f "$TOKEN_FILE" ]; then
              echo "Gotify App Token not found at $TOKEN_FILE. Skipping notification."
              exit 0
            fi

            TOKEN=$(cat "$TOKEN_FILE")
            FAILED_SERVICE="%i"

            # Grab the last few log lines of the failed service
            LOGS=$(journalctl -u "$FAILED_SERVICE" -n 5 --no-pager || true)

            # Prepare JSON payload
            # Using jq to properly escape the logs for JSON
            JSON_PAYLOAD=$(${pkgs.jq}/bin/jq -n \
              --arg title "🚨 NixOS Service Failed: $FAILED_SERVICE" \
              --arg message "The service $FAILED_SERVICE has failed or crashed.

      Last Logs:
      $LOGS" \
              --arg priority 8 \
              '{title: $title, message: $message, priority: ($priority | tonumber)}'
            )

            # Send the request
            curl -X POST "http://127.0.0.1:8080/message?token=$TOKEN" \
              -H "Content-Type: application/json" \
              -d "$JSON_PAYLOAD"
    '';
  };
}
