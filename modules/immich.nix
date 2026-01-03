{
  config,
  pkgs,
  lib,
  ...
}: {
  # Immich - Self-hosted photo and video management
  services.immich = {
    enable = true;
    port = 2283;
    host = "127.0.0.1"; # Only listen locally, nginx handles external
    mediaLocation = "/var/lib/immich";

    # Load secrets from agenix
    secretsFile = config.age.secrets.immich-env.path;

    # Enable machine learning for face recognition and smart search
    machine-learning = {
      enable = true;
    };
  };

  # Ensure the media directory exists with proper permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/immich 0750 immich immich -"
  ];

  # Open port for Prometheus scraping (optional, for Grafana)
  # Immich exposes metrics at /api/server-info/statistics (requires auth)
}
