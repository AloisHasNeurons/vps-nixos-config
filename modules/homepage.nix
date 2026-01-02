{
  config,
  pkgs,
  lib,
  ...
}: {
  services.homepage-dashboard = {
    enable = true;
    listenPort = 3001;
    settings = {
      title = "My Dashboard";
      services = [];
    };
  };

  # Fix for "Host validation failed" when behind a proxy
  systemd.services.homepage-dashboard.environment = {
    HOSTNAME = "127.0.0.1";

    HOMEPAGE_ALLOWED_HOSTS = lib.mkForce "home.crapadouille.fr,localhost,127.0.0.1";
  };
}
