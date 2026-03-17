# /Documents/nix-config/vps/configuration.nix
{pkgs, ...}: {
  imports = [
    ./modules/adguard.nix
    ./modules/grafana.nix
    ./modules/homepage.nix
    ./modules/immich.nix
    ./modules/immich-public-proxy.nix
    ./modules/mealie.nix
    ./modules/nginx.nix
    ./modules/security-hardening.nix

    ./modules/wireguard.nix
    ./modules/wireguard-monitor.nix
    ./modules/wireguard-pinger.nix

    ./modules/gotify.nix
    ./modules/alerts.nix
  ];

  # Nix Configuration
  nix.settings.trusted-users = ["root" "@wheel"];
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Automatic Garbage Collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Utility to check if reboot is needed
  environment.systemPackages = [
    pkgs.dnsutils # for dig (used by post-deploy DNS smoke tests)
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
  age.secrets.wireguard-private-key.file = ./secrets/wireguard-private-key.age;
  age.secrets.homepage-env.file = ./secrets/homepage-env.age;
  age.secrets.immich-env.file = ./secrets/immich-env.age;
  age.secrets.grafana-secret-key = {
    file = ./secrets/grafana-secret-key.age;
    owner = "grafana";
    group = "grafana";
  };

  networking = {
    hostName = "NixOS_VPS-25_05-CX33-fsn1";

    # Firewall
    firewall = {
      allowedTCPPorts = [22 80 443];
      allowedUDPPorts = [41820];

      # Allow DNS only on the WireGuard interface
      interfaces.wg0 = {
        allowedTCPPorts = [53];
        allowedUDPPorts = [53];
      };
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
    hashedPassword = "$6$XqSAhd1.NSqQ1ar3$NFolR41M2jbwCKvbXmOsFjNy7/ipbX4L3ZXBnP48rj4o4TylhECGZHbWVsMBrYfMrehjt1M28QbPlcFe28TfM0";
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
