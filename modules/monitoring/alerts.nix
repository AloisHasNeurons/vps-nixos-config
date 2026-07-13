{pkgs, config, ...}: {
  # Universal Systemd Failure Notification Service
  #
  # This service is triggered via `OnFailure=notify-failure@%n.service`
  # on any other systemd service. It uses `curl` to send a push notification
  # to Telegram when a service crashes.
  #
  # Configuration:
  # The service expects an agenix encrypted secret file `telegram-alerts.age` containing:
  # TELEGRAM_TOKEN="your-bot-token"
  # TELEGRAM_CHAT_ID="your-chat-id"

  systemd.services."notify-failure@" = {
    description = "Failure notification for %i";

    # We don't want this notification to silently fail or retry forever
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = config.age.secrets.telegram-alerts.path;
    };

    # Needs curl and systemctl (to get service logs/status)
    path = with pkgs; [curl systemd];

    # The %i gets replaced with the name of the service that failed.
    # We fetch the last 5 log lines of the crashed service to include in the Telegram message.
    script = ''
      # Verify environment variables
      if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "Telegram credentials not found in agenix secrets. Skipping notification."
        exit 0
      fi

      FAILED_SERVICE="%i"

      # Grab the last few log lines of the failed service
      LOGS=$(journalctl -u "$FAILED_SERVICE" -n 5 --no-pager || true)

      # Build HTML message
      MESSAGE="🚨 <b>[VPS Notification Alert]</b> Service <b>$FAILED_SERVICE</b> has failed or crashed!

<b>Host:</b> $(hostname)
<b>Time:</b> $(date)

<b>Last Logs:</b>
<pre>$LOGS</pre>"

      # Send HTML message via curl
      curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$MESSAGE" \
        -d "parse_mode=HTML" \
        --fail-with-body
    '';
  };
}
