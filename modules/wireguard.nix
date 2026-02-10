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

  # Fix for WireGuard: Allow asymmetric routing
  networking.firewall.checkReversePath = "loose";

  # Don't specify externalInterface - let it auto-detect via masquerade

  # Force enable IP forwarding
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.wireguard.interfaces.wg0 = {
    ips = ["10.100.0.1/24"]; # Server's IP in the VPN
    listenPort = 51820;
    mtu = 1280; # Lower MTU to generic failsafe value
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
      # Desktop (Windows 11)
      {
        publicKey = "JfYoIMlEdPnyB9SpKEmkgo978F4xEkGBhLv00NHYCTI=";
        allowedIPs = ["10.100.0.4/32"];
      }
    ];
  };
}
