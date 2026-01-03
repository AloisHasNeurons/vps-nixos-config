{
  config,
  pkgs,
  ...
}: {
  # Prometheus - Metrics collection
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";

    # Collect metrics from these exporters
    exporters = {
      node = {
        enable = true;
        port = 9100;
        listenAddress = "127.0.0.1";
        enabledCollectors = [
          "cpu"
          "diskstats"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "stat"
          "time"
          "vmstat"
          "systemd"
          "processes"
        ];
      };
    };

    # Scrape configs
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = ["127.0.0.1:9100"];
            labels = {
              instance = "vps";
            };
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = ["127.0.0.1:9090"];
          }
        ];
      }
    ];

    # Retention
    retentionTime = "30d";
  };

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

      # Anonymous access (read-only, behind VPN)
      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Viewer";
      };

      # Disable login form since we use anonymous
      auth = {
        disable_login_form = false; # Keep login available for admin
      };

      security = {
        admin_user = "admin";
        admin_password = "admin"; # Change on first login!
      };
    };

    # Pre-configure Prometheus as data source
    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          editable = false;
        }
      ];

      # Pre-configured dashboards
      dashboards.settings.providers = [
        {
          name = "default";
          options.path = "/var/lib/grafana/dashboards";
        }
      ];
    };
  };

  # Create a basic node exporter dashboard
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
  ];
}
