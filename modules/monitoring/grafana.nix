{config, ...}: {
  # Prometheus - Metrics collection
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";

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

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = ["127.0.0.1:9100"];
            labels.instance = "vps";
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [{targets = ["127.0.0.1:9090"];}];
      }
    ];

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

      # Enable embedding in iframes (for Homepage).
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

      dashboards.settings.providers = [
        {
          name = "default";
          options.path = "/var/lib/grafana/dashboards";
        }
      ];
    };
  };

  # Create dashboards directory
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
  ];
}
