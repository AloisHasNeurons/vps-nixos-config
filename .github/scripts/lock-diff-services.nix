# Services listed in the "Services" table of the flake.lock PR comment
# (see system-diff.sh). Takes a NixOS system (nixosConfigurations.vps) and
# returns display name -> package, or -> { package; changelog = version: url; }
# for packages whose nixpkgs `meta.changelog` is missing.
# `or null` keeps an older revision evaluating when an entry doesn't exist
# there yet; null entries are skipped.
nixos: let
  c = nixos.config;
  inherit (nixos.pkgs) lib;
in {
  "Linux kernel" = {
    package = c.boot.kernelPackages.kernel or null;
    changelog = v: "https://cdn.kernel.org/pub/linux/kernel/v${lib.versions.major v}.x/ChangeLog-${v}";
  };
  "systemd" = {
    package = c.systemd.package or null;
    changelog = v: "https://github.com/systemd/systemd/releases/tag/v${v}";
  };
  "Immich" = c.services.immich.package or null;
  "PostgreSQL" = c.services.postgresql.package or null;
  "Grafana" = {
    package = c.services.grafana.package or null;
    changelog = v: "https://github.com/grafana/grafana/releases/tag/v${v}";
  };
  "Prometheus" = c.services.prometheus.package or null;
  "Alertmanager" = c.services.prometheus.alertmanager.package or null;
  "AdGuard Home" = {
    package = c.services.adguardhome.package or null;
    changelog = v: "https://github.com/AdguardTeam/AdGuardHome/releases/tag/v${v}";
  };
  "Tandoor Recipes" = c.services.tandoor-recipes.package or null;
  "Glance" = c.services.glance.package or null;
  "nginx" = {
    package = c.services.nginx.package or null;
    changelog = _: "https://nginx.org/en/CHANGES";
  };
  "Tailscale" = c.services.tailscale.package or null;
  "OpenSSH" = c.programs.ssh.package or null;
  "restic" = nixos.pkgs.restic or null;
}
