{
  pkgs,
  inputs,
  ...
}:
pkgs.testers.nixosTest {
  name = "security-port-scan";

  # Python type checking doesn't know about dynamic machine names
  skipTypeCheck = true;

  nodes = {
    # The server node running our configuration
    server = {
      config,
      pkgs,
      ...
    }: {
      # Pass flake inputs to the module system
      _module.args.inputs = inputs;

      imports = [
        ../configuration.nix
        ../disk-config.nix
        inputs.agenix.nixosModules.default
        inputs.disko.nixosModules.disko
      ];

      # --- VM Specific Overrides (to make it bootable in test) ---

      # Dummy WireGuard key (since we can't decrypt real secrets)
      age.secrets.wireguard-private-key.file = pkgs.lib.mkForce (pkgs.writeText "dummy-wg" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4=");

      # Dummy Grafana secret key (since we can't decrypt real secrets)
      age.secrets.grafana-secret-key.file = pkgs.lib.mkForce (pkgs.writeText "dummy-grafana-key" "0123456789abcdef0123456789abcdef");

      # Mock interface for WireGuard to prevent startup failure
      networking.wireguard.interfaces.wg0.privateKeyFile = pkgs.lib.mkForce (toString (pkgs.writeText "dummy-wg" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4="));

      # Force hostname to be 'server' so the python script variable matches
      networking.hostName = pkgs.lib.mkForce "server";

      # Force standard VM settings
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;

      # Ensure network interfaces get IPs
      networking.useDHCP = true;

      # Avoid evaluation warning for root password
      users.users.root.hashedPasswordFile = pkgs.lib.mkForce null;
    };

    # The attacker/scanner node
    scanner = {pkgs, ...}: {
      environment.systemPackages = [pkgs.nmap pkgs.curl];
    };
  };

  testScript = {nodes, ...}: ''
    import re

    start_all()

    # Wait for server to be ready
    server.wait_for_unit("multi-user.target")
    server.wait_for_unit("sshd.service")

    # Wait for webserver to start listening
    server.wait_for_open_port(80)

    # Get the server's IP address dynamically (wait for DHCP)
    target_ip = server.wait_until_succeeds(
        "ip -4 addr show eth1 | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1"
    ).strip()

    # 1. Run a generic scan (Top 1000 ports) to check for ANY open ports
    # This ensures forward compatibility: if you add a new service and
    # accidentally expose it, this test will fail.
    scan_output = scanner.succeed(f"nmap {target_ip} --open")
    print(f"Scan Output:\n{scan_output}")

    # 2. Parse open TCP ports (matches lines like "80/tcp open http")
    open_ports = re.findall(r"(\d+)/tcp\s+open", scan_output)

    # 3. Define the Whitelist (Publicly Allowed Ports)
    # 22: SSH, 80: HTTP (ACME/Redirect), 443: HTTPS
    allowed_ports = ["22", "80", "443"]

    # 4. Verify no unexpected ports are open
    unexpected_ports = [p for p in open_ports if p not in allowed_ports]
    if unexpected_ports:
        raise Exception(
            f"SECURITY ALERT: Unexpected open TCP ports: {unexpected_ports}"
        )

    # Verify minimal expected ports are actually open (sanity check)
    if "22" not in open_ports:
        raise Exception("Sanity check failed: SSH (22) is not open")
    if "80" not in open_ports:
        print("Warning: Port 80 is not open (Nginx not ready or config changed?)")

    print("Success: Public firewall is clean. No unexpected ports exposed.")

    # 5. Verify ALL VPN-restricted admin panels return 403 from outside
    vpn_restricted_vhosts = ["adguard", "mealie", "home", "grafana"]

    for vhost in vpn_restricted_vhosts:
        http_code = scanner.succeed(
            f"curl -k -o /dev/null -s -w '%{{http_code}}' "
            f"-H 'Host: {vhost}.crapadouille.fr' https://{target_ip}/"
        ).strip()

        if http_code == "403":
            print(f"Success: {vhost}.crapadouille.fr is correctly restricted (403).")
        elif http_code == "200":
            raise Exception(
                f"SECURITY FAILURE: {vhost}.crapadouille.fr is publicly accessible!"
            )
        else:
            print(
                f"WARNING: {vhost}.crapadouille.fr returned {http_code} instead of 403."
            )
  '';
}
