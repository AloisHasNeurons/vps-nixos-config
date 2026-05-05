{...}: {
  # ─────────────────────────────────────────────────────────────
  # Shared "media" group
  # ─────────────────────────────────────────────────────────────
  # All media services run under this group so they can all
  # read and write the same files, both now (Jellyfin) and
  # later (when Sonarr/Radarr move files from the seedbox).
  users.groups.media = {
    gid = 1500;
  };

  # ─────────────────────────────────────────────────────────────
  # Landing Zone: /mnt/media
  # ─────────────────────────────────────────────────────────────
  # Currently empty; later this is where the seedbox SSHFS
  # mount will attach. Creating it now ensures it always has
  # the correct group/permissions from day one.
  systemd.tmpfiles.rules = [
    "d /mnt/media 0775 root media - -"
  ];

  # ─────────────────────────────────────────────────────────────
  # Jellyfin - Media Player
  # Port: 8096
  # ─────────────────────────────────────────────────────────────
  services.jellyfin = {
    enable = true;
    openFirewall = false; # Nginx handles external access
    group = "media";
  };
  systemd.services.jellyfin.unitConfig.OnFailure = "notify-failure@%n.service";

  # ─────────────────────────────────────────────────────────────
  # Sonarr - TV Show Manager
  # Port: 8989
  # ─────────────────────────────────────────────────────────────
  services.sonarr = {
    enable = true;
    openFirewall = false;
    group = "media";
  };
  systemd.services.sonarr.unitConfig.OnFailure = "notify-failure@%n.service";

  # ─────────────────────────────────────────────────────────────
  # Radarr - Movie Manager
  # Port: 7878
  # ─────────────────────────────────────────────────────────────
  services.radarr = {
    enable = true;
    openFirewall = false;
    group = "media";
  };
  systemd.services.radarr.unitConfig.OnFailure = "notify-failure@%n.service";

  # ─────────────────────────────────────────────────────────────
  # Bazarr - Subtitle Downloader
  # Port: 6767
  # ─────────────────────────────────────────────────────────────
  services.bazarr = {
    enable = true;
    openFirewall = false;
  };
  systemd.services.bazarr.unitConfig.OnFailure = "notify-failure@%n.service";
}
