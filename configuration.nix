# /Documents/nix-config/vps/configuration.nix
{pkgs, ...}: {
  imports = [
    ./modules/services/adguard.nix
    ./modules/monitoring/grafana.nix
    ./modules/services/homepage.nix
    ./modules/services/immich.nix
    ./modules/services/immich-public-proxy.nix
    ./modules/services/tandoor.nix
    ./modules/services/nginx.nix
    ./modules/services/backup.nix
    ./modules/services/smartscaleconnect.nix
    ./modules/system/security-hardening.nix

    ./modules/networking/tailscale.nix

    ./modules/services/gotify.nix
    ./modules/monitoring/alerts.nix

    # Media Suite
    # ./modules/media/media.nix
    # ./modules/media/jellyseerr.nix
    # ./modules/media/prowlarr.nix
    # ./modules/media/seedbox.nix
  ];

  # Nix Configuration
  nix.settings = {
    trusted-users = [
      "root"
      "@wheel"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true; # Hardlinks duplicate files to save space
  };

  # Aggressive Garbage Collection
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 3d";
  };

  # Utility to check if reboot is needed
  environment.systemPackages = [
    pkgs.dnsutils # for dig (used by post-deploy DNS smoke tests)
    pkgs.git # for local repo clone and checkout during CD
    (pkgs.writeScriptBin "check-reboot" ''
      #!${pkgs.runtimeShell}
      current_kernel=$(readlink -f /run/current-system/kernel)
      booted_kernel=$(readlink -f /run/booted-system/kernel)

      if [ "$current_kernel" != "$booted_kernel" ]; then
        echo "🚨 Reboot required!"
        echo "Current: $current_kernel"
        echo "Booted:  $booted_kernel"
        exit 1
      else
        echo "✅ No reboot needed (Kernel is up to date)"
        exit 0
      fi
    '')
  ];

  # Use GRUB for Hybrid Boot (BIOS + UEFI)
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = ["/dev/sda"];
  };

  # Kernel modules for Hetzner cloud VMs (virtio drivers)
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "sd_mod"
    "ahci"
  ];

  # Filesystems are handled by disko (disk-config.nix)

  time.timeZone = "Europe/Paris";

  # Secrets
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  age.secrets.homepage-env.file = ./secrets/homepage-env.age;
  age.secrets.immich-env.file = ./secrets/immich-env.age;
  age.secrets.grafana-secret-key = {
    file = ./secrets/grafana-secret-key.age;
    owner = "grafana";
    group = "grafana";
  };
  age.secrets.tandoor-secret-key = {
    file = ./secrets/tandoor-secret-key.age;
    owner = "tandoor-recipes";
    group = "tandoor-recipes";
  };
  # age.secrets.seedbox-ssh.file = ./secrets/seedbox-ssh.age;

  networking = {
    hostName = "NixOS_VPS-25_05-CX33-fsn1";

    # Firewall
    firewall = {
      allowedTCPPorts = [
        22
        80
        443
      ];
      trustedInterfaces = ["tailscale0"];
    };
  };

  # SSH - HARDENED
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Keys only!
      PermitRootLogin = "no"; # All root SSH access blocked
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      PermitEmptyPasswords = false;
    };
    # Extra hardening
    extraConfig = ''
      AllowUsers alois deploy

      MaxAuthTries 3
      LoginGraceTime 20
      MaxSessions 3
      ClientAliveInterval 300
      ClientAliveCountMax 2
      AllowAgentForwarding no
      AllowTcpForwarding no
    '';
  };

  # Fail2ban - Block brute force attacks
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h"; # Max 1 week ban
      factor = "4";
    };
  };

  # Users - SSH keys only, no password login
  users.users.root = {
    hashedPassword = "!"; # Disabled password
  };

  users.users.alois = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    hashedPassword = "$y$j9T$njIq5wNQMvXeHHAgkkqRs.$BPmNgJG96aMqIU48AjXuElMy1xbU6tGmOCw4UTRhlt9";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa1VOKGJI/j5mfvo5QsKk/tX+vNr3CdjdYYNfbPxdDK alois@fedora"
    ];
  };

  users.users.deploy = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    hashedPassword = "!"; # Keys only
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/J/t0j3ylcxgXjMOfol8JL0RuuoKAjVvP3X+34o/DF github-actions-deploy"
    ];
  };

  users.mutableUsers = false;

  # Allow deploy user to run sudo without password (for CI/CD)
  security.sudo.extraRules = [
    {
      users = ["deploy"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  # Security: Require password for sudo
  security.sudo.wheelNeedsPassword = true;

  # Console keyboard
  console.keyMap = "fr";

  system.stateVersion = "25.05";
}
