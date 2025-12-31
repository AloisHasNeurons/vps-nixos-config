{ config, pkgs, ... }:

{
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

    peers = [
      # Laptop (Fedora)
      {
        publicKey = "geab3hfyFvpm+rSPAr5W37AGVXkDFRbwufmb+5O1QQ4=";
        allowedIPs = [ "10.100.0.2/32" ];
      }
      # Phone (Pixel 9)
      {
        publicKey = "X8MbaQlE7j5P0H8JM2FvMstK6Z/vOctKYBOb7A66Rjw=";
        allowedIPs = [ "10.100.0.3/32" ];
      }
    ];
  };
}
