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

    # peers = [
    #   # Pixel 9
    #   {
    #     publicKey = "{CLIENT_PUBLIC_KEY}"; # Replace with your phone's public key
    #     allowedIPs = [ "10.100.0.2/32" ]; # IP assigned to your phone
    #   }
    # ];
  };
}
