{ config, pkgs, ... }:

{
  # Enable NAT for VPN traffic - using masquerade for automatic interface detection
  networking.nat.enable = true;
  networking.nat.enableIPv6 = false;  # IPv4 only for now
  networking.nat.internalInterfaces = [ "wg0" ];
  # Don't specify externalInterface - let it auto-detect via masquerade

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ]; # Server's IP in the VPN
    listenPort = 51820;
    privateKeyFile = config.age.secrets.wireguard-private-key.path;

    # Use nftables masquerade instead of hardcoded iptables rules
    postSetup = ''
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -j MASQUERADE
      ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
      ${pkgs.iptables}/bin/iptables -A FORWARD -o wg0 -j ACCEPT
    '';
    postShutdown = ''
      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -j MASQUERADE
      ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
      ${pkgs.iptables}/bin/iptables -D FORWARD -o wg0 -j ACCEPT
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
