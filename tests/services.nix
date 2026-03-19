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
    server = {pkgs, ...}: {
      _module.args.inputs = inputs;

      imports = [
        ../configuration.nix
        ../disk-config.nix
        inputs.agenix.nixosModules.default
        inputs.disko.nixosModules.disko
      ];

      # --- Dummy secrets (can't decrypt real ones in test VM) ---
      age.secrets.grafana-secret-key.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-grafana" "0123456789abcdef0123456789abcdef");
      age.secrets.immich-env.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-immich" "DB_PASSWORD=dummy");
      age.secrets.homepage-env.file =
        pkgs.lib.mkForce (pkgs.writeText "dummy-homepage" "HOMEPAGE_VAR=dummy");

      # --- VM test overrides ---
      networking.hostName = pkgs.lib.mkForce "server";
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
      users.users.root.hashedPasswordFile = pkgs.lib.mkForce null;
      networking.useDHCP = true;
    };
  };

  testScript = {...}: ''
    start_all()

    server.wait_for_unit("multi-user.target")

    # ══════════════════════════════════════════════
    # Test 1: All critical systemd units are active
    # ══════════════════════════════════════════════
    # NOTE: Grafana, Homepage, and Immich are excluded because they depend on
    # agenix secrets (grafana-secret-key, homepage-env, immich-env).
    # Agenix can't decrypt dummy files in the test VM, so the secret files
    # under /run/agenix/ never get created and these services fail to start.
    # They are validated by the post-deploy health check instead.
    critical_units = [
        "nginx.service",
        "adguardhome.service",
        "prometheus.service",
        "prometheus-node-exporter.service",
        "mealie.service",
        "fail2ban.service",
        "sshd.service",
    ]

    for unit in critical_units:
        server.wait_for_unit(unit, timeout=60)
        print(f"✅ Test 1: {unit} is active")

    # ══════════════════════════════════════════════
    # Test 2: Services are listening on expected ports
    # ══════════════════════════════════════════════
    expected_ports = {
        80: "Nginx HTTP",
        443: "Nginx HTTPS",
        3000: "AdGuard Home",
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

    # Verify Nginx proxies to services that are actually running
    # (excludes Grafana/Homepage whose backends aren't up in the test VM)
    for vhost in ["adguard", "mealie"]:
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
    # Note: we download to a file first then grep, because node-exporter
    # produces very large output and piping directly causes SIGPIPE errors.
    server.wait_until_succeeds(
        "curl -sf http://127.0.0.1:9100/metrics -o /tmp/metrics"
        " && grep -q 'node_cpu_seconds_total' /tmp/metrics",
        timeout=30
    )
    print("✅ Test 5: Node exporter metrics endpoint is working")

    # Prometheus is scraping targets
    server.wait_until_succeeds(
        "curl -sf http://127.0.0.1:9090/api/v1/targets -o /tmp/targets"
        " && grep -q 'node' /tmp/targets",
        timeout=60
    )
    print("✅ Test 5: Prometheus is scraping node target")

    print("🎉 All service integration tests passed!")
  '';
}
