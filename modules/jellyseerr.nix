{...}: {
  # ─────────────────────────────────────────────────────────────
  # Jellyseerr - Media Request Frontend
  # Port: 5055
  # ─────────────────────────────────────────────────────────────
  # The user-facing "Netflix-like" UI where you search for
  # movies/shows and request them. Connects to Sonarr & Radarr.
  services.seerr = {
    enable = true;
    openFirewall = false; # Nginx handles external access
  };
  systemd.services.seerr.unitConfig.OnFailure = "notify-failure@%n.service";
}
