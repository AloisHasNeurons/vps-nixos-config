{config, ...}: {
  # Immich Public Proxy - serves shared links (/share/...) to the public
  # without exposing Immich itself. Nginx routes non-VPN traffic here.
  services.immich-public-proxy = {
    enable = true;
    immichUrl = "http://127.0.0.1:${toString config.services.immich.port}";
    port = 3004;

    # Same headers as the upstream config.json, which the Docker image used
    settings.ipp.responseHeaders = {
      "Cache-Control" = "public, max-age=2592000";
      "Access-Control-Allow-Origin" = "*";
    };
  };

  systemd.services.immich-public-proxy = {
    # Not exposed by the module: the public URL used in link previews
    environment.PUBLIC_BASE_URL = "https://photos.crapadouille.fr";

    # IPP binds 0.0.0.0 and has no listen address option. It only talks to
    # nginx and Immich over loopback, so keep it off every other interface.
    serviceConfig.RestrictNetworkInterfaces = "lo";

    unitConfig.OnFailure = "notify-failure@%n.service";
  };
}
