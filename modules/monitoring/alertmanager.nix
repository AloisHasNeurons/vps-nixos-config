{
  pkgs,
  config,
  ...
}: let
  # Alertmanager wants the bare token and chat ID in files, while the agenix
  # secret is an env file (TELEGRAM_TOKEN=..., TELEGRAM_CHAT_ID=...) shared with
  # notify-failure@. Write them into the unit's private /tmp before it starts.
  telegramFiles = pkgs.writeShellScript "alertmanager-telegram-files" ''
    umask 077
    printf '%s' "$TELEGRAM_TOKEN" > /tmp/telegram-token
    printf '%s' "$TELEGRAM_CHAT_ID" > /tmp/telegram-chat-id
  '';
in {
  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;
    listenAddress = "127.0.0.1";
    environmentFile = config.age.secrets.telegram-alerts.path;
    # Single instance: don't listen on the HA gossip port (9094, all interfaces)
    extraFlags = ["--cluster.listen-address="];

    configuration = {
      route = {
        receiver = "telegram";
        group_by = ["alertname" "site" "backup"];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "12h";
      };
      receivers = [
        {
          name = "telegram";
          telegram_configs = [
            {
              bot_token_file = "/tmp/telegram-token";
              chat_id_file = "/tmp/telegram-chat-id";
              parse_mode = "HTML";
              send_resolved = true;
            }
          ];
        }
      ];
    };
  };

  systemd.services.alertmanager = {
    serviceConfig.ExecStartPre = [telegramFiles];
    # If Alertmanager itself dies, notify-failure@ still reaches Telegram
    unitConfig.OnFailure = "notify-failure@%n.service";
  };
}
