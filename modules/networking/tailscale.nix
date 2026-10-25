{config, ...}: {
  age.secrets.tailscale-authkey.file = ../../secrets/tailscale-authkey.age;

  services.tailscale = {
    enable = true;
    # Only used when the node isn't logged in yet (e.g. after a rebuild from scratch):
    # tailscaled-autoconnect skips `tailscale up` if the node is already Running.
    # The secret is an OAuth client secret (tskey-client-...), which never expires.
    # Nodes joining with it must be tagged, and are ephemeral unless told otherwise.
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    authKeyParameters = {
      ephemeral = false;
      preauthorized = true;
    };
    extraUpFlags = ["--advertise-tags=tag:server"];
  };

  networking.firewall.trustedInterfaces = ["tailscale0"];

  # Allow Tailscale's default port 41641 for peer-to-peer UDP connections
  networking.firewall.allowedUDPPorts = [config.services.tailscale.port];
}
