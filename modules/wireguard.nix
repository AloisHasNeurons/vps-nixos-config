{
  config,
  pkgs,
  ...
}: {
  # Enable NAT for VPN traffic - using masquerade for automatic interface detection
  networking.nat = {
    enable = true;
    enableIPv6 = true; # Dual-stack: NAT66 for IPv6 tunnel traffic
    internalInterfaces = ["wg0"];
  };

  # Fix for WireGuard: Allow asymmetric routing
  networking.firewall.checkReversePath = "loose";

  # TCP MSS Clamping - crucial for WireGuard performance (IPv4 + IPv6)
  # Uses check-then-add (-C || -A) to avoid duplicate rules on firewall reload
  networking.firewall.extraCommands = ''
    ${pkgs.iptables}/bin/iptables -t mangle -C FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    ${pkgs.iptables}/bin/iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    ${pkgs.iptables}/bin/ip6tables -t mangle -C FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    ${pkgs.iptables}/bin/ip6tables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  '';
  networking.firewall.extraStopCommands = ''
    ${pkgs.iptables}/bin/iptables -t mangle -D FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    ${pkgs.iptables}/bin/ip6tables -t mangle -D FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
  '';

  # Don't specify externalInterface - let it auto-detect via masquerade

  # Force enable IP forwarding (IPv4 + IPv6)
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  # Enable WireGuard dynamic debugging in the kernel to view dropped handshakes/packets
  # These logs will appear in `dmesg` or `journalctl -k`
  boot.kernelParams = ["dyndbg=\"module wireguard +p\""];

  networking.wireguard.interfaces.wg0 = {
    ips = ["10.100.0.1/24" "fd10:100::1/64"]; # Server's IP in the VPN (dual-stack)
    listenPort = 41820; # Non-default port to avoid fingerprinting
    mtu = 1420; # Restored to standard 1420, relying on MSS clamping for fits
    privateKeyFile = config.age.secrets.wireguard-private-key.path;

    # Defensive: Verify IPv4 address was applied (guards against silent failures)
    postSetup = ''
      if ! ip addr show wg0 | grep -q 'inet 10.100.0.1/24'; then
        echo "WARNING: IPv4 not applied to wg0, re-adding..."
        ip addr add 10.100.0.1/24 dev wg0 || true
      fi
    '';

    # Use generic masquerade (handled by networking.nat)
    # networking.nat.internalInterfaces = ["wg0"] takes care of forwarding and NAT

    peers = [
      # Laptop (Fedora)
      {
        publicKey = "geab3hfyFvpm+rSPAr5W37AGVXkDFRbwufmb+5O1QQ4=";
        allowedIPs = ["10.100.0.2/32" "fd10:100::2/128"];
        persistentKeepalive = 25;
      }
      # Phone (Pixel 9)
      {
        publicKey = "X8MbaQlE7j5P0H8JM2FvMstK6Z/vOctKYBOb7A66Rjw=";
        allowedIPs = ["10.100.0.3/32" "fd10:100::3/128"];
        persistentKeepalive = 25;
      }
      # Desktop (Windows 11)
      {
        publicKey = "JfYoIMlEdPnyB9SpKEmkgo978F4xEkGBhLv00NHYCTI=";
        allowedIPs = ["10.100.0.4/32" "fd10:100::4/128"];
        persistentKeepalive = 25;
      }
    ];
  };
}
