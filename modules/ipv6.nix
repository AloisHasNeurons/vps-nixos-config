{
  config,
  pkgs,
  ...
}: {
  # Static IPv6 for Hetzner Cloud
  # Required because IPv6 forwarding (for WireGuard NAT66) disables SLAAC (accept_ra)
  # This module is NOT imported by the test VM (which doesn't have enp1s0)
  networking.interfaces.enp1s0.ipv6.addresses = [
    {
      address = "2a01:4f8:c17:22de::1";
      prefixLength = 64;
    }
  ];
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "enp1s0";
  };
}
