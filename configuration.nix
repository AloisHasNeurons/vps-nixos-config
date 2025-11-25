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

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
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
    22 80 443 8080 8443 3000 3001 3002 53 8000
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
    ];
  };

  # Console keyboard
  console.keyMap = "fr";

  system.stateVersion = "25.05";
}