# WireGuard connectivity & configuration test
#
# Verifies that WireGuard clients can:
#   1. Establish a tunnel and ping the server
#   2. Server has correct IPv4 on wg0 (guards against the production regression)
#   3. NAT, forwarding, and DNS are properly configured
#
# Architecture:  client --[wg0]--> server (with full production config)
#
{
  pkgs,
  inputs,
  ...
}:
pkgs.testers.nixosTest {
  name = "wireguard-connectivity";

  skipTypeCheck = true;

  nodes = {
    # ── Server: runs the real config with test overrides ──
    server = {
      config,
      pkgs,
      ...
    }: {
      _module.args.inputs = inputs;

      imports = [
        ../configuration.nix
        ../disk-config.nix
        inputs.agenix.nixosModules.default
        inputs.disko.nixosModules.disko
      ];

      # --- Dummy secrets (can't decrypt real ones in test VM) ---
      age.secrets.wireguard-private-key.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-wg" "QIQqgCr0+MA7icyKivoQNPe571L167DCl9I9RDdvWVA=");
      age.secrets.grafana-secret-key.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-grafana" "0123456789abcdef0123456789abcdef");
      age.secrets.immich-env.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-immich" "DB_PASSWORD=dummy");
      age.secrets.homepage-env.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-homepage" "HOMEPAGE_VAR=dummy");

      networking.wireguard.interfaces.wg0.privateKeyFile =
        pkgs.lib.mkForce (toString (pkgs.writeText "dummy-wg" "QIQqgCr0+MA7icyKivoQNPe571L167DCl9I9RDdvWVA="));

      # Add test client as a peer
      networking.wireguard.interfaces.wg0.peers = pkgs.lib.mkForce [
        {
          publicKey = "8vfxXVlqotd85BDKzZtNBsCKD+6V6H3B6gM+O875tEU=";
          allowedIPs = ["10.100.0.99/32"];
        }
      ];

      # --- VM test overrides ---
      networking.hostName = pkgs.lib.mkForce "server";
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
      users.users.root.hashedPasswordFile = pkgs.lib.mkForce null;
      networking.useDHCP = true;
    };

    # ── Client: connects to server via WireGuard ──
    client = {pkgs, ...}: {
      networking.wireguard.interfaces.wg0 = {
        ips = ["10.100.0.99/24"];
        privateKeyFile = toString (pkgs.writeText "client-wg-key" "oFFhSkQP9U4b9dhnn+67zjIk0os/SEF7/Zr1IOkG9Gg=");
        peers = [
          {
            publicKey = "V6D/xyap545aCdqBQz7pUGDJETLPcrNb7KS6C6Gr0SU=";
            allowedIPs = ["10.100.0.0/24"];
            endpoint = "server:41820";
            persistentKeepalive = 25;
          }
        ];
      };
      environment.systemPackages = with pkgs; [curl dnsutils iproute2];
    };
  };

  testScript = {nodes, ...}: ''
    start_all()

    # Wait for all machines to boot
    server.wait_for_unit("multi-user.target")
    client.wait_for_unit("multi-user.target")

    # Wait for WireGuard interfaces
    server.wait_for_unit("wireguard-wg0.service")
    client.wait_for_unit("wireguard-wg0.service")

    # ── Test 1: Server wg0 has IPv4 address ──
    # This is the exact regression that broke production: wg0 lost its IPv4.
    server.succeed("ip addr show wg0 | grep -q 'inet 10.100.0.1/24'")
    print("✅ Test 1 PASSED: Server wg0 has IPv4 address 10.100.0.1/24")

    # ── Test 2: Client can ping server through WireGuard tunnel ──
    client.wait_until_succeeds("ping -c 3 10.100.0.1", timeout=30)
    print("✅ Test 2 PASSED: Client can ping server via WireGuard (10.100.0.1)")

    # ── Test 3: IP forwarding is enabled ──
    server.succeed("test $(sysctl -n net.ipv4.ip_forward) = 1")
    print("✅ Test 3 PASSED: IPv4 forwarding is enabled")

    # ── Test 4: NAT masquerade rules exist ──
    server.succeed("iptables -t nat -L nixos-nat-post -n | grep -q MASQUERADE")
    print("✅ Test 4 PASSED: NAT masquerade rule is present")

    # ── Test 5: AdGuard Home is running and listening for DNS ──
    server.wait_for_unit("adguardhome.service")
    server.wait_until_succeeds("ss -ulnp | grep -q ':53 '", timeout=30)
    print("✅ Test 5 PASSED: AdGuard Home is running and listening on port 53")

    # ── Test 6: Server routing for WireGuard clients is correct ──
    # Verify the server routes wg0 client IPs through wg0, not the public interface
    # This is the exact issue that caused the production outage.
    server.succeed("ip route get 10.100.0.99 | grep -q 'dev wg0'")
    print("✅ Test 6 PASSED: Server routes WireGuard client IPs via wg0")

    print("🎉 All WireGuard connectivity tests passed!")
  '';
}
