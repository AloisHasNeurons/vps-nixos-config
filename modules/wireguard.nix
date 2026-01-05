{
  config,
  pkgs,
  ...
}: {
  # Enable NAT for VPN traffic - using masquerade for automatic interface detection
  networking.nat = {
    enable = true;
    enableIPv6 = false; # IPv4 only for now
    internalInterfaces = ["wg0"];
  };
  # Don't specify externalInterface - let it auto-detect via masquerade

  networking.wireguard.interfaces.wg0 = {
    ips = ["10.100.0.1/24"]; # Server's IP in the VPN
    listenPort = 51820;
    privateKeyFile = config.age.secrets.wireguard-private-key.path;

    # Use generic masquerade (handled by networking.nat)
    # networking.nat.internalInterfaces = ["wg0"] takes care of forwarding and NAT

    peers = [
      # Laptop (Fedora)
      {
        publicKey = "geab3hfyFvpm+rSPAr5W37AGVXkDFRbwufmb+5O1QQ4=";
        allowedIPs = ["10.100.0.2/32"];
      }
      # Phone (Pixel 9)
      {
        publicKey = "X8MbaQlE7j5P0H8JM2FvMstK6Z/vOctKYBOb7A66Rjw=";
        allowedIPs = ["10.100.0.3/32"];
      }
    ];
  };
}
