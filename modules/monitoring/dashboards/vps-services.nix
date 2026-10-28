# "VPS Services" dashboard: sites, certificates, backups, alerts, nginx, Postgres.
# Panel IDs are stable on purpose: Glance embeds panels by ID (glance.nix).
{lib}: let
  # Same datasource variable as Node Exporter Full: no hardcoded datasource UID
  ds = {
    type = "prometheus";
    uid = "\${ds_prometheus}";
  };

  query = expr: legend: {
    datasource = ds;
    inherit expr;
    legendFormat = legend;
    refId = "A";
  };

  thresholds = steps: {
    mode = "absolute";
    steps =
      map (s: {
        color = builtins.elemAt s 0;
        value = builtins.elemAt s 1;
      })
      steps;
  };

  panel = {
    id,
    title,
    type,
    x,
    y,
    w,
    h,
    targets,
    unit ? "none",
    steps ? [["green" null]],
    defaults ? {},
    options ? {},
  }: {
    inherit id title type targets options;
    datasource = ds;
    gridPos = {inherit x y w h;};
    fieldConfig = {
      defaults =
        {
          inherit unit;
          thresholds = thresholds steps;
          color.mode = "thresholds";
        }
        // defaults;
      overrides = [];
    };
  };

  # recursiveUpdate: a panel can tweak one option without dropping the others
  stat = args:
    panel (lib.recursiveUpdate {
        type = "stat";
        options = {
          colorMode = "background";
          graphMode = "none";
          textMode = "value_and_name";
          justifyMode = "center";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
      }
      args);

  timeseries = args:
    panel (lib.recursiveUpdate {
        type = "timeseries";
        defaults = {
          color.mode = "palette-classic";
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            showPoints = "never";
          };
        };
        options = {
          legend = {
            displayMode = "list";
            placement = "bottom";
            showLegend = true;
          };
          tooltip = {
            mode = "multi";
            sort = "desc";
          };
        };
      }
      args);
in {
  uid = "vps-services";
  title = "VPS Services";
  tags = ["vps"];
  timezone = "browser";
  refresh = "1m";
  schemaVersion = 39;
  time = {
    from = "now-24h";
    to = "now";
  };

  templating.list = [
    {
      name = "ds_prometheus";
      label = "Datasource";
      type = "datasource";
      query = "prometheus";
    }
  ];

  panels = [
    # ── Health at a glance ────────────────────────────────────────
    (stat {
      id = 1;
      title = "Sites";
      x = 0;
      y = 0;
      w = 8;
      h = 5;
      targets = [(query ''probe_success{job="blackbox-https"}'' "{{site}}")];
      steps = [["red" null] ["green" 1]];
      defaults.mappings = [
        {
          type = "value";
          options = {
            "0" = {
              text = "DOWN";
              color = "red";
            };
            "1" = {
              text = "UP";
              color = "green";
            };
          };
        }
      ];
    })
    (stat {
      id = 2;
      title = "Certificate expiry";
      x = 8;
      y = 0;
      w = 4;
      h = 5;
      targets = [(query ''min(probe_ssl_earliest_cert_expiry{job="blackbox-https"}) - time()'' "Earliest")];
      unit = "s";
      steps = [["red" null] ["orange" (14 * 86400)] ["green" (21 * 86400)]];
    })
    (stat {
      id = 3;
      title = "Last backup";
      x = 12;
      y = 0;
      w = 4;
      h = 5;
      targets = [(query "time() - backup_last_success_timestamp_seconds" "{{backup}}")];
      unit = "s";
      steps = [["green" null] ["red" (26 * 3600)]];
    })
    (stat {
      id = 4;
      title = "Failed units";
      x = 16;
      y = 0;
      w = 4;
      h = 5;
      targets = [(query ''count(node_systemd_unit_state{state="failed"} == 1) or vector(0)'' "Failed")];
      steps = [["green" null] ["red" 1]];
      options.textMode = "value";
    })
    (stat {
      id = 5;
      title = "Firing alerts";
      x = 20;
      y = 0;
      w = 4;
      h = 5;
      targets = [(query ''count(ALERTS{alertstate="firing"}) or vector(0)'' "Firing")];
      steps = [["green" null] ["red" 1]];
      options.textMode = "value";
    })

    # ── Sites & disk ──────────────────────────────────────────────
    (timeseries {
      id = 6;
      title = "Response time";
      x = 0;
      y = 5;
      w = 12;
      h = 8;
      targets = [(query ''probe_duration_seconds{job="blackbox-https"}'' "{{site}}")];
      unit = "s";
    })
    (panel {
      id = 7;
      title = "Root disk used";
      type = "gauge";
      x = 12;
      y = 5;
      w = 4;
      h = 8;
      targets = [(query ''100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})'' "Used")];
      unit = "percent";
      steps = [["green" null] ["orange" 70] ["red" 85]];
      defaults = {
        min = 0;
        max = 100;
      };
      options.reduceOptions = {
        calcs = ["lastNotNull"];
        fields = "";
        values = false;
      };
    })
    (timeseries {
      id = 8;
      title = "Disk free and 7-day forecast";
      x = 16;
      y = 5;
      w = 8;
      h = 8;
      targets = [
        (query ''node_filesystem_avail_bytes{mountpoint="/"}'' "Free")
        ((query ''predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1d], 7 * 86400)'' "Forecast in 7 days") // {refId = "B";})
      ];
      unit = "bytes";
    })

    # ── nginx & Postgres ──────────────────────────────────────────
    (timeseries {
      id = 9;
      title = "HTTP requests";
      x = 0;
      y = 13;
      w = 12;
      h = 8;
      targets = [(query "sum(rate(nginx_http_requests_total[$__rate_interval]))" "Requests/s")];
      unit = "reqps";
    })
    (timeseries {
      id = 10;
      title = "nginx connections";
      x = 12;
      y = 13;
      w = 12;
      h = 8;
      targets = [
        (query "nginx_connections_active" "Active")
        ((query "nginx_connections_waiting" "Idle keep-alive") // {refId = "B";})
      ];
    })
    (timeseries {
      id = 11;
      title = "Database size";
      x = 0;
      y = 21;
      w = 12;
      h = 8;
      targets = [(query ''pg_database_size_bytes{datname!~"template.*|postgres"}'' "{{datname}}")];
      unit = "bytes";
    })
    (timeseries {
      id = 12;
      title = "Database connections";
      x = 12;
      y = 21;
      w = 12;
      h = 8;
      targets = [(query ''pg_stat_database_numbackends{datname!~"template.*|postgres"}'' "{{datname}}")];
    })
  ];
}
