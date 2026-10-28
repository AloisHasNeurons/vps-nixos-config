{config, ...}: let
  # A single Grafana panel as an iframe. Panel IDs are fixed: see
  # modules/monitoring/grafana.nix and modules/monitoring/dashboards/
  grafanaPanel = dashboard: panel: height: {
    type = "iframe";
    source = "https://grafana.crapadouille.fr/d-solo/${dashboard}?orgId=1&refresh=1m&panelId=panel-${toString panel}&var-node=vps&theme=dark";
    inherit height;
    # The Grafana panel shows its own title
    hide-header = true;
  };
  nodeExporterFull = "rYdddlPWk/node-exporter-full";
  vpsServices = "vps-services/vps-services";

  # Side-by-side widgets, under a title
  row = title: max-columns: widgets: {
    type = "split-column";
    inherit title max-columns widgets;
  };

  # Click goes to the public hostname, the status check stays on loopback
  site = title: url: check-url: icon: {inherit title url check-url icon;};
in {
  services.glance = {
    enable = true;

    # HOMEPAGE_VAR_* (AdGuard login, Immich API key): the secret predates Glance,
    # and Glance substitutes ${VAR} from the environment
    environmentFile = config.age.secrets.homepage-env.path;

    settings = {
      server = {
        host = "127.0.0.1";
        port = 3001;
        proxied = true; # Behind nginx
      };

      branding = {
        app-name = "Crapadouille";
        hide-footer = true;
      };

      # Catppuccin Mocha
      theme = {
        background-color = "240 21 15";
        contrast-multiplier = 1.2;
        primary-color = "217 92 83";
        positive-color = "115 54 76";
        negative-color = "347 70 65";
      };

      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "clock";
                  hour-format = "24h";
                }
                {
                  type = "monitor";
                  title = "Services";
                  cache = "1m";
                  sites = [
                    (site "Immich" "https://photos.crapadouille.fr" "http://127.0.0.1:2283/api/server/ping" "di:immich")
                    (site "Photo sharing" "https://share.photos.crapadouille.fr" "http://127.0.0.1:3004/share/healthcheck" "di:immich")
                    (site "Tandoor" "https://tandoor.crapadouille.fr" "http://127.0.0.1:8085/" "di:tandoor-recipes")
                    (site "Grafana" "https://grafana.crapadouille.fr" "http://127.0.0.1:3002/api/health" "di:grafana")
                    (site "AdGuard Home" "https://adguard.crapadouille.fr" "http://127.0.0.1:3000/" "di:adguard-home")
                  ];
                }
                {
                  type = "custom-api";
                  title = "Photos";
                  title-url = "https://photos.crapadouille.fr";
                  cache = "15m";
                  url = "http://127.0.0.1:2283/api/server/statistics";
                  headers = {
                    x-api-key = "\${HOMEPAGE_VAR_IMMICH_KEY}";
                    Accept = "application/json";
                  };
                  template = ''
                    <div class="flex justify-between text-center">
                      <div>
                        <div class="color-highlight size-h3">{{ .JSON.Int "photos" | formatNumber }}</div>
                        <div class="size-h6">PHOTOS</div>
                      </div>
                      <div>
                        <div class="color-highlight size-h3">{{ .JSON.Int "videos" | formatNumber }}</div>
                        <div class="size-h6">VIDEOS</div>
                      </div>
                      <div>
                        <div class="color-highlight size-h3">{{ div (.JSON.Float "usage") 1073741824.0 | printf "%.1f" }} GB</div>
                        <div class="size-h6">USED</div>
                      </div>
                    </div>
                  '';
                }
                {
                  type = "dns-stats";
                  title = "AdGuard";
                  title-url = "https://adguard.crapadouille.fr";
                  service = "adguard";
                  url = "http://127.0.0.1:3000";
                  username = "\${HOMEPAGE_VAR_ADGUARD_USER}";
                  password = "\${HOMEPAGE_VAR_ADGUARD_PASS}";
                  hour-format = "24h";
                }
              ];
            }
            {
              size = "full";
              widgets = [
                (row "Health" 5 [
                  (grafanaPanel vpsServices 1 150) # Sites
                  (grafanaPanel vpsServices 2 150) # Certificate expiry
                  (grafanaPanel vpsServices 3 150) # Last backup
                  (grafanaPanel vpsServices 4 150) # Failed units
                  (grafanaPanel vpsServices 5 150) # Firing alerts
                ])
                (row "System" 2 [
                  (grafanaPanel nodeExporterFull 77 220) # CPU
                  (grafanaPanel nodeExporterFull 78 220) # Memory
                  (grafanaPanel nodeExporterFull 74 220) # Network
                  (grafanaPanel nodeExporterFull 152 220) # Disk space
                ])
                (row "Activity" 3 [
                  (grafanaPanel vpsServices 6 220) # Response time
                  (grafanaPanel vpsServices 9 220) # HTTP requests
                  (grafanaPanel vpsServices 11 220) # Database size
                ])
              ];
            }
          ];
        }
      ];
    };
  };

  systemd.services.glance.unitConfig.OnFailure = "notify-failure@%n.service";
}
