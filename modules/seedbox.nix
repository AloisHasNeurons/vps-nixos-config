{pkgs, ...}: {
  # Install SSHFS so NixOS knows how to mount external servers via SSH
  environment.systemPackages = [pkgs.sshfs];

  # Add the ultra.cc seedbox to the known hosts
  programs.ssh.knownHosts."aiko.usbx.me".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/3imBwJx2ihSHgTPomnXyQlgmoeTvmQEXxvp5NZBlg";

  # ─────────────────────────────────────────────────────────────
  # Ultra.cc Seedbox Mount
  # ─────────────────────────────────────────────────────────────
  fileSystems."/mnt/media" = {
    device = "carton@aiko.usbx.me:";
    fsType = "sshfs";

    # We use systemd automount so the boot process doesn't hang if the seedbox is down.
    # It will mount "on-demand" the first time Sonarr/Jellyfin tries to look at the folder.
    options = [
      "x-systemd.automount"
      "noauto"
      "_netdev"

      # SSH Connection Settings
      "IdentityFile=/run/agenix/seedbox-ssh" # Path to the SSH key provided by agenix
      "StrictHostKeyChecking=yes" # Verify host key against system knownHosts
      "ServerAliveInterval=15" # Ping every 15s to keep connection alive
      "ServerAliveCountMax=3"
      "reconnect"
      "Port=22" # Ultra.cc uses default port 22

      # Permission Mapping:
      # We force all files to appear as owned by the "media" group (GID 1500).
      # Without this, Sonarr on the VPS won't have permission to write to the seedbox.
      "allow_other"
      "default_permissions"
      "uid=1000" # Maps local owner to 'alois'
      "gid=1500" # Maps local group to 'media' (which Jellyfin, Sonarr, etc. belong to)
    ];
  };
}
