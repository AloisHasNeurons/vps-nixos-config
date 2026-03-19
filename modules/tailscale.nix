{ config, pkgs, ... }:

{
  services.tailscale.enable = true;

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  
  # Allow Tailscale's default port 41641 for peer-to-peer UDP connections
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];
}
