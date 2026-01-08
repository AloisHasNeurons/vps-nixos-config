{
  config,
  pkgs,
  ...
}: {
  # Enable Podman (Daemonless container engine)
  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Alias docker=podman
    defaultNetwork.settings.dns_enabled = true;
  };

  # Immich Public Proxy Container
  virtualisation.oci-containers.containers.immich-public-proxy = {
    image = "ghcr.io/alangrainger/immich-public-proxy:latest";
    autoStart = true;

    # Use Host Networking so it can reach Immich on 127.0.0.1:2283
    extraOptions = ["--network=host"];

    environment = {
      # The URL of the Immich Server (Localhost because of network=host)
      IMMICH_URL = "http://127.0.0.1:2283";

      # The Public URL users visit
      PUBLIC_URL = "https://photos.crapadouille.fr";

      # The Internal Port the proxy listens on
      PORT = "3003";

      # Optional: Cache control
      # 1440 mins = 24 hours
      CACHE_MAX_AGE = "1440";

      # Debug logging
      LOG_LEVEL = "info";
    };
  };
}
