{...}: {
  # ─────────────────────────────────────────────────────────────
  # Prowlarr - Indexer Manager
  # Port: 9696
  # ─────────────────────────────────────────────────────────────
  # Manages torrent indexer accounts (tracker logins) and acts
  # as a central search broker for Sonarr and Radarr.
  services.prowlarr = {
    enable = true;
    openFirewall = false; # Nginx handles external access
  };
  systemd.services.prowlarr.unitConfig.OnFailure = "notify-failure@%n.service";
}
