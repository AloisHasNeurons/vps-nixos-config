{
  pkgs,
  lib,
  config,
  ...
}: let
  # Node Exporter Full (grafana.com #1860). Pinned to the last version before the
  # October 2026 reorganization; panel IDs 74/77/78/152, embedded by Glance,
  # are the same in every version checked.
  nodeExporterFull = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/rfmoz/grafana-dashboards/99a25cc154c21c4fcbae1aa24352bf1b6764d847/prometheus/node-exporter-full.json";
    hash = "sha256-3+opah4hCqZoGXYU03CLVnGKmb53lKHCwBLNUdp+y4k=";
  };

  dashboards = pkgs.linkFarm "grafana-dashboards" [
    {
      name = "node-exporter-full.json";
      path = nodeExporterFull;
    }
    {
      name = "vps-services.json";
      path = pkgs.writeText "vps-services.json" (builtins.toJSON (import ./dashboards/vps-services.nix {inherit lib;}));
    }
  ];
in {
  # Grafana - Visualization
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3002;
        domain = "grafana.crapadouille.fr";
        root_url = "https://grafana.crapadouille.fr";
      };

      # Enable embedding in iframes (for Glance).
      # Anonymous Viewer + cookie_samesite = "disabled" is only acceptable because
      # the grafana vhost is VPN-only. Revisit both if Grafana is ever made public.
      security = {
        admin_user = "admin";
        # Only used when grafana.db is first created. To change the password of an
        # existing install: `grafana cli admin reset-admin-password <new>`.
        admin_password = "$__file{${config.age.secrets.grafana-admin-password.path}}";
        allow_embedding = true;
        cookie_samesite = "disabled";
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
      };

      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Viewer";
      };

      auth.disable_login_form = false;

      # Nix manages updates
      analytics = {
        check_for_updates = false;
        check_for_plugin_updates = false;
        reporting_enabled = false;
      };
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:9090";
          isDefault = true;
        }
      ];

      # Dashboards come from git: edits made in the UI can't be saved, change
      # the JSON (or dashboards/*.nix) instead
      dashboards.settings.providers = [
        {
          name = "default";
          options.path = dashboards;
        }
      ];
    };
  };

  systemd.services.grafana.unitConfig.OnFailure = "notify-failure@%n.service";
}
