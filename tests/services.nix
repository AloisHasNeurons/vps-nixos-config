# Services integration test
#
# Verifies that all critical services:
#   1. Start successfully (systemd units reach active state)
#   2. Listen on their expected ports
#   3. Nginx responds correctly per virtual host
#   4. SSH security settings are enforced
#
# This catches regressions from nixpkgs updates (renamed options,
# broken dependencies, config schema changes, etc.)
#
{
  pkgs,
  inputs,
  ...
}:
pkgs.testers.nixosTest {
  name = "services-integration";

  skipTypeCheck = true;

  nodes = {
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
        pkgs.lib.mkForce (pkgs.writeText "dummy-wg" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4=");
      age.secrets.grafana-secret-key.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-grafana" "0123456789abcdef0123456789abcdef");
      age.secrets.immich-env.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-immich" "DB_PASSWORD=dummy");
      age.secrets.homepage-env.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-homepage" "HOMEPAGE_VAR=dummy");

      networking.wireguard.interfaces.wg0.privateKeyFile =
        pkgs.lib.mkForce (toString (pkgs.writeText "dummy-wg" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4="));

      # --- VM test overrides ---
      networking.hostName = pkgs.lib.mkForce "server";
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
      users.users.root.hashedPasswordFile = pkgs.lib.mkForce null;
      networking.useDHCP = true;
    };
  };

  testScript = {nodes, ...}: ''
    start_all()

    server.wait_for_unit("multi-user.target")

    # ══════════════════════════════════════════════
    # Test 1: All critical systemd units are active
    # ══════════════════════════════════════════════
    critical_units = [
        "nginx.service",
        "adguardhome.service",
        "grafana.service",
        "prometheus.service",
        "prometheus-node-exporter.service",
        "mealie.service",
        "homepage-dashboard.service",
        "fail2ban.service",
        "sshd.service",
    ]

    for unit in critical_units:
        server.wait_for_unit(unit, timeout=60)
        print(f"✅ Test 1: {unit} is active")

    # ══════════════════════════════════════════════
    # Test 2: Services are listening on expected ports
    # ══════════════════════════════════════════════
    # Note: Immich (2283) is excluded — it needs a real database and
    # decrypted secrets to start, which aren't available in the test VM.
    # Immich is validated by the post-deploy health check instead.
    expected_ports = {
        80: "Nginx HTTP",
        443: "Nginx HTTPS",
        3000: "AdGuard Home",
        3001: "Homepage",
        3002: "Grafana",
        9000: "Mealie",
        9090: "Prometheus",
        9100: "Node Exporter",
    }

    for port, name in expected_ports.items():
        server.wait_for_open_port(port, timeout=60)
        print(f"✅ Test 2: {name} listening on port {port}")

    # ══════════════════════════════════════════════
    # Test 3: Nginx virtual host responses
    # ══════════════════════════════════════════════

    # Default catch-all should respond
    server.succeed("curl -s http://localhost/ | grep -q 'Hello from Nginx!'")
    print("✅ Test 3: Nginx default catch-all responds correctly")

    # VPN-restricted vhosts should return 403 from localhost
    # (localhost is allowed in nginx config, so they should return 200 or proxy response)
    # We just verify Nginx doesn't 502/503 (backend is actually running)
    for vhost in ["adguard", "mealie", "home", "grafana"]:
        http_code = server.succeed(
            f"curl -sk -o /dev/null -w '%{{http_code}}' "
            f"-H 'Host: {vhost}.crapadouille.fr' https://localhost/"
        ).strip()
        if http_code in ["502", "503", "504"]:
            raise Exception(
                f"Nginx returned {http_code} for {vhost}.crapadouille.fr — "
                f"backend service is not reachable!"
            )
        print(f"✅ Test 3: {vhost}.crapadouille.fr responds ({http_code})")

    # ══════════════════════════════════════════════
    # Test 4: SSH security settings are enforced
    # ══════════════════════════════════════════════
    server.succeed("sshd -T | grep -qi 'passwordauthentication no'")
    print("✅ Test 4: SSH PasswordAuthentication is disabled")

    server.succeed("sshd -T | grep -qi 'permitrootlogin no'")
    print("✅ Test 4: SSH PermitRootLogin is disabled")

    server.succeed("sshd -T | grep -qi 'permitemptypasswords no'")
    print("✅ Test 4: SSH PermitEmptyPasswords is disabled")

    # ══════════════════════════════════════════════
    # Test 5: Monitoring stack connectivity
    # ══════════════════════════════════════════════
    # Prometheus can scrape node-exporter
    server.succeed(
        "curl -s http://127.0.0.1:9100/metrics | grep -q 'node_cpu_seconds_total'"
    )
    print("✅ Test 5: Node exporter metrics endpoint is working")

    # Prometheus is scraping targets
    server.wait_until_succeeds(
        "curl -s http://127.0.0.1:9090/api/v1/targets | grep -q 'node'",
        timeout=60
    )
    print("✅ Test 5: Prometheus is scraping node target")

    print("🎉 All service integration tests passed!")
  '';
}
