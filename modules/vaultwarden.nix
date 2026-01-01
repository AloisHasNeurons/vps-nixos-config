{
  config,
  pkgs,
  ...
}: {
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_PORT = 8000;
      ROCKET_ADDRESS = "127.0.0.1"; # Localhost only - nginx proxies it
      WEBSOCKET_ENABLED = true;

      # Security hardening
      SIGNUPS_ALLOWED = false; # Disable public signups (enable temporarily to create your account)
      INVITATIONS_ALLOWED = false; # Only admin can invite
      SHOW_PASSWORD_HINT = false; # Don't leak password hints

      # Admin panel disabled by default (uncomment and set a strong token to enable)
      # ADMIN_TOKEN = "your-very-strong-admin-token-here";
    };
  };
}
