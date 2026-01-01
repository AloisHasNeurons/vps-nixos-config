# /Documents/nix-config/vps/configuration.nix

{ config, pkgs, inputs, ... }:

{
  imports = [
    ./modules/adguard.nix
    ./modules/homepage.nix
    ./modules/nginx.nix
    ./modules/vaultwarden.nix
    ./modules/wireguard.nix
  ];

  # Use GRUB for Hybrid Boot (BIOS + UEFI)
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true; # Needed if not using EFI variables
  # boot.loader.grub.device = "/dev/sda"; # Not needed with disko? Let's check disko docs or try "nodev"
  # Disko usually handles grub installation if we let it, but often we just point it to the disk.
  # For safety in hybrid, we often just point to the disk for MBR.
  # However, with disko, we can often skip the device setting if it installs to the boot partition.
  # Let's set it to "nodev" first or keep it explicit if we want MBR installation.
  # Given type EF02 exists, we likely want GRUB to install to MBR of /dev/sda.
  # Let's use simple GRUB setup compatible with disko.
  # Actually, disko documentation suggests:
  # boot.loader.grub.devices = [ "/dev/sda" ];
  boot.loader.grub.devices = [ "/dev/sda" ];
  
  # Filesystems are handled by disko (disk-config.nix)
  
  networking.hostName = "nixOS-25_05-4GB-nbg1-1";
  time.timeZone = "Europe/Paris";

  # Secrets
  age.secrets.wireguard-private-key.file = ./secrets/wireguard-private-key.age;

  # Glance placeholder
  systemd.services.glance = let
    glancePort = 3002;
  in {
    description = "Glance Dashboard";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString glancePort} --directory /tmp";
      WorkingDirectory = "/tmp";
      Restart = "always";
    };
  };

  # Firewall
  networking.firewall.allowedTCPPorts = [
    22 80 443 53
  ];
  networking.firewall.allowedUDPPorts = [ 51820 53 ];

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };

  # Users
  users.users.root.hashedPassword = "$6$zMgGjQVPB.Mog2Km$XkLZ2L8iHg7D6m71uuW0pfFtR8VKocdgXStYTIe/xUuDnvnM85T83K44CXoibIVwHzxbjmgLOaIEhCsWtSV5z0";
  users.users.alois = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$Hnbk1NWUoP05TJ7K$QRaDPGY9KPZlZSHlR80JxC7NlLAKe.0RMWAZybobZHoPhVzrrdlqu9qFAwG6iRWBs2mgnBi6eIqvgHnmMxSH40";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2uzDX8j0gCkpfmB+G9HU3PEEOGp02Nfh4FcIlQ+EWb alois.vincent@imt-atlantique.net"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa1VOKGJI/j5mfvo5QsKk/tX+vNr3CdjdYYNfbPxdDK alois@fedora"
    ];
  };

  # Console keyboard
  console.keyMap = "fr";

  system.stateVersion = "25.05";
}