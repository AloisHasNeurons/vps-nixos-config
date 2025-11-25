# /Documents/nix-config/vps/configuration.nix

{ config, pkgs, inputs, ... }:

{
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  networking.hostName = "nixOS-25_05-4GB-nbg1-1";
  time.timeZone = "Europe/Paris";

  # Secrets
  age.secrets.wireguard-private-key.file = ./secrets/wireguard-private-key.age;


  # AdGuard Home
  services.adguardhome = {
    enable = true;
    port = 3000;
    settings = {
      http = {
        address = "0.0.0.0:3000";
      };
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [ "1.1.1.1" "8.8.8.8" ];
      };
    };
  };

  # Nginx Reverse Proxy
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Default catch-all
    virtualHosts."localhost" = {
      default = true;
      extraConfig = ''
        return 200 "Hello from Nginx!";
      '';
    };
  };

  # Homepage
  services.homepage-dashboard = {
    enable = true;
    listenPort = 3001;
    settings = {
      title = "My Dashboard";
      services = [];
    };
  };

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

  # Vaultwarden
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_PORT = 8000;
      ROCKET_ADDRESS = "0.0.0.0";
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

  # Enable NAT for VPN traffic
  networking.nat.enable = true;
  networking.nat.externalInterface = "eth0"; # Use your VPS's main interface
  networking.nat.internalInterfaces = [ "wg0" ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ]; # Server's IP in the VPN
    listenPort = 51820;
    privateKeyFile = config.age.secrets.wireguard-private-key.path;

    postSetup = ''
      ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
    '';
    postShutdown = ''
      ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
    '';

    # peers = [
    #   # Pixel 9
    #   {
    #     publicKey = "{CLIENT_PUBLIC_KEY}"; # Replace with your phone's public key
    #     allowedIPs = [ "10.100.0.2/32" ]; # IP assigned to your phone
    #   }
    # ];
  };



  # Console keyboard
  console.keyMap = "fr";

  system.stateVersion = "25.05";
}