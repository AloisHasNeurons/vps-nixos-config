{
  config,
  pkgs,
  ...
}: {
  # Gotify - Self-hosted Push Notification Server
  services.gotify = {
    enable = true;
    port = 8080;

    # We use a static environment file configuration here.
    # Gotify will create its SQLite database internally.
    environment = {
      GOTIFY_DEFAULTUSER_PASS = "admin"; # CHANGE THIS AFTER FIRST LOGIN
      GOTIFY_SERVER_KEEPALIVEPERIODSECONDS = "0";
      GOTIFY_SERVER_SSL_ENABLED = "false"; # Nginx handles SSL
    };
  };
}
