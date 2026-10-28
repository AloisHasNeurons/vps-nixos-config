{
  pkgs,
  lib,
  config,
  ...
}: let
  exporters = config.services.prometheus.exporters;

  # Sites probed by blackbox over HTTPS, as a tailnet client sees them: the
  # names resolve through AdGuard to the Tailscale IP, so VPN-only vhosts let the
  # probe in. A probe fails on a bad certificate (e.g. a name missing from it).
  sites = {
    photos = "https://photos.crapadouille.fr/api/server/ping";
    share = "https://share.photos.crapadouille.fr/share/healthcheck";
    grafana = "https://grafana.crapadouille.fr/api/health";
    home = "https://home.crapadouille.fr/";
    tandoor = "https://tandoor.crapadouille.fr/";
    adguard = "https://adguard.crapadouille.fr/";
  };

  blackboxConfig = (pkgs.formats.yaml {}).generate "blackbox.yml" {
    modules = {
      https_2xx = {
        prober = "http";
        timeout = "10s";
        http = {
          preferred_ip_protocol = "ip4";
          fail_if_not_ssl = true;
        };
      };
      # AdGuard must keep rewriting our domain to the Tailscale IP
      dns_tailnet_rewrite = {
        prober = "dns";
        timeout = "5s";
        dns = {
          query_name = "photos.crapadouille.fr";
          query_type = "A";
          preferred_ip_protocol = "ip4";
          validate_answer_rrs.fail_if_none_matches_regexp = ["100\\.109\\.82\\.105"];
        };
      };
    };
  };

  # Point a scrape job at blackbox, passing each target as the `target` param
  blackboxRelabel = [
    {
      source_labels = ["__address__"];
      target_label = "__param_target";
    }
    {
      source_labels = ["__param_target"];
      target_label = "instance";
    }
    {
      target_label = "__address__";
      replacement = "127.0.0.1:${toString exporters.blackbox.port}";
    }
  ];

  localJob = name: port: {
    job_name = name;
    static_configs = [{targets = ["127.0.0.1:${toString port}"];}];
  };

  alertRules = {
    groups = [
      {
        name = "vps";
        rules = [
          {
            alert = "TargetDown";
            expr = "up == 0";
            for = "5m";
            annotations.summary = "Prometheus can't scrape {{ $labels.job }} ({{ $labels.instance }})";
          }
          {
            alert = "SiteDown";
            expr = ''probe_success{job="blackbox-https"} == 0'';
            for = "3m";
            annotations.summary = "{{ $labels.site }} is failing its HTTPS probe (down, bad status or bad certificate)";
          }
          {
            alert = "CertificateExpiringSoon";
            expr = ''(probe_ssl_earliest_cert_expiry{job="blackbox-https"} - time()) / 86400 < 21'';
            for = "1h";
            annotations.summary = "Certificate for {{ $labels.site }} expires in {{ $value | humanize }} days: check acme-order-renew-crapadouille.fr";
          }
          {
            alert = "TailnetDnsRewriteBroken";
            expr = ''probe_success{job="blackbox-dns"} == 0'';
            for = "5m";
            annotations.summary = "AdGuard no longer rewrites crapadouille.fr to the Tailscale IP";
          }
          {
            alert = "DiskAlmostFull";
            expr = ''1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} > 0.85'';
            for = "10m";
            annotations.summary = "Root filesystem is {{ $value | humanizePercentage }} full";
          }
          {
            alert = "DiskFillingUp";
            expr = ''predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[6h], 24 * 3600) < 0'';
            for = "1h";
            annotations.summary = "At the current rate, the root filesystem fills up within 24h";
          }
          {
            alert = "MemoryLow";
            expr = "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10";
            for = "15m";
            annotations.summary = "Only {{ $value | humanizePercentage }} of memory is available";
          }
          {
            alert = "SystemdUnitFailed";
            expr = ''node_systemd_unit_state{state="failed"} == 1'';
            for = "5m";
            annotations.summary = "{{ $labels.name }} is in a failed state";
          }
          {
            alert = "BackupStale";
            expr = "time() - backup_last_success_timestamp_seconds > 26 * 3600";
            for = "10m";
            annotations.summary = "Last successful {{ $labels.backup }} backup was {{ $value | humanizeDuration }} ago";
          }
          {
            # Covers a backup that has never succeeded since this was set up
            alert = "BackupNeverRecorded";
            expr = ''absent(backup_last_success_timestamp_seconds{backup="restic"}) or absent(backup_last_success_timestamp_seconds{backup="postgres"})'';
            for = "27h";
            annotations.summary = "No successful {{ $labels.backup }} backup recorded in the last 27h";
          }
        ];
      }
    ];
  };
in {
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";

    # Default is 1m, too coarse for Node Exporter Full (built around 15s)
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    retentionTime = "30d";
    # Prometheus shares the disk with Immich: never let it be what fills it
    extraFlags = ["--storage.tsdb.retention.size=5GB"];

    exporters = {
      node = {
        enable = true;
        port = 9100;
        listenAddress = "127.0.0.1";
        # Added on top of node_exporter's defaults (cpu, disk, memory, network...)
        enabledCollectors = ["systemd" "processes"];
        # textfile is a default collector: backup.nix writes timestamps here
        extraFlags = ["--collector.textfile.directory=/var/lib/node-exporter-textfile"];
      };

      blackbox = {
        enable = true;
        port = 9115;
        listenAddress = "127.0.0.1";
        configFile = blackboxConfig;
      };

      nginx = {
        enable = true;
        port = 9113;
        listenAddress = "127.0.0.1";
      };

      postgres = {
        enable = true;
        port = 9187;
        listenAddress = "127.0.0.1";
        runAsLocalSuperUser = true;
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
      (localJob "prometheus" 9090)
      (localJob "alertmanager" config.services.prometheus.alertmanager.port)
      (localJob "grafana" config.services.grafana.settings.server.http_port)
      (localJob "blackbox" exporters.blackbox.port)
      (localJob "nginx" exporters.nginx.port)
      (localJob "postgres" exporters.postgres.port)
      {
        job_name = "blackbox-https";
        metrics_path = "/probe";
        params.module = ["https_2xx"];
        static_configs =
          lib.mapAttrsToList (site: url: {
            targets = [url];
            labels.site = site;
          })
          sites;
        relabel_configs = blackboxRelabel;
      }
      {
        job_name = "blackbox-dns";
        metrics_path = "/probe";
        params.module = ["dns_tailnet_rewrite"];
        static_configs = [
          {
            targets = ["127.0.0.1:53"];
            labels.site = "adguard-dns";
          }
        ];
        relabel_configs = blackboxRelabel;
      }
    ];

    rules = [(builtins.toJSON alertRules)];

    alertmanagers = [
      {static_configs = [{targets = ["127.0.0.1:${toString config.services.prometheus.alertmanager.port}"];}];}
    ];
  };

  # stub_status for the nginx exporter, on the catch-all localhost vhost
  services.nginx.statusPage = true;

  systemd.tmpfiles.rules = [
    "d /var/lib/node-exporter-textfile 0755 root root -"
  ];

  systemd.services.prometheus.unitConfig.OnFailure = "notify-failure@%n.service";
}
