{config, ...}: let
  # A single Grafana panel as an iframe. Panel IDs are fixed: see
  # modules/monitoring/grafana.nix and modules/monitoring/dashboards/
  grafanaPanel = dashboard: panel: height: {
    widget = {
      type = "iframe";
      src = "https://grafana.crapadouille.fr/d-solo/${dashboard}?orgId=1&refresh=1m&panelId=panel-${toString panel}&var-node=vps&theme=dark";
      inherit height;
    };
  };
  nodeExporterFull = "rYdddlPWk/node-exporter-full";
  vpsServices = "vps-services/vps-services";
in {
  services.homepage-dashboard = {
    enable = true;
    listenPort = 3001;

    settings = {
      title = "Crapadouille";
      favicon = "https://cdn-icons-png.flaticon.com/512/2593/2593635.png";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";

      layout = [
        {
          System = {
            style = "row";
            columns = 4;
          };
        }
        {
          Health = {
            style = "row";
            columns = 5;
          };
        }
        {
          Activity = {
            style = "row";
            columns = 3;
          };
        }
        {
          Network = {
            style = "row";
            columns = 2;
          };
        }
        # {
        #   Security = {
        #     style = "row";
        #     columns = 1;
        #   };
        # }
        {
          Media = {
            style = "row";
            columns = 4;
          };
        }
        {
          Food = {
            style = "row";
            columns = 1;
          };
        }
        {
          Markets = {
            style = "row";
            columns = 4;
          };
        }
      ];

      providers = {
        finnhub = "{{HOMEPAGE_VAR_FINNHUB_KEY}}";
      };
    };

    # Header: Search only
    widgets = [
      {
        search = {
          provider = "custom";
          url = "https://www.qwant.com/?q=";
          target = "_blank";
          suggestionUrl = "https://api.qwant.com/v3/suggest?q=";
          showSearchSuggestions = true;
          focus = true;
        };
      }
    ];

    services = [
      # Row 1: System Monitoring (Grafana iframes + link)
      {
        System = [
          {"CPU Usage" = grafanaPanel nodeExporterFull 77 200;}
          {"Memory" = grafanaPanel nodeExporterFull 78 200;}
          {"Network" = grafanaPanel nodeExporterFull 74 200;}
          {"Disk Space" = grafanaPanel nodeExporterFull 152 200;}
          {
            Grafana = {
              icon = "grafana.svg";
              href = "https://grafana.crapadouille.fr";
              description = "Monitoring";
              ping = "http://127.0.0.1:3002";
            };
          }
        ];
      }
      # Health: is everything up, renewed and backed up (VPS Services dashboard)
      {
        Health = [
          {"Sites" = grafanaPanel vpsServices 1 150;}
          {"Certificate expiry" = grafanaPanel vpsServices 2 150;}
          {"Last backup" = grafanaPanel vpsServices 3 150;}
          {"Failed units" = grafanaPanel vpsServices 4 150;}
          {"Firing alerts" = grafanaPanel vpsServices 5 150;}
        ];
      }
      # Activity: response times, web traffic, database growth
      {
        Activity = [
          {"Response time" = grafanaPanel vpsServices 6 220;}
          {"HTTP requests" = grafanaPanel vpsServices 9 220;}
          {"Database size" = grafanaPanel vpsServices 11 220;}
        ];
      }
      # Row 2: Network
      {
        Network = [
          {
            AdGuard = {
              icon = "adguard-home.svg";
              href = "https://adguard.crapadouille.fr";
              description = "DNS Filtering";
              widget = {
                type = "adguard";
                url = "http://127.0.0.1:3000";
                username = "{{HOMEPAGE_VAR_ADGUARD_USER}}";
                password = "{{HOMEPAGE_VAR_ADGUARD_PASS}}";
                fields = [
                  "queries"
                  "blocked"
                  "filtered"
                  "latency"
                ];
              };
            };
          }
          {
            Tailscale = {
              icon = "tailscale.svg";
              href = "#";
              description = "Mesh Network";
              ping = "100.100.100.100";
            };
          }
        ];
      }
      # Row 3: Security
      # {
      #   Security = [
      #     {
      #       Vaultwarden = {
      #         icon = "vaultwarden.svg";
      #         href = "https://vault.crapadouille.fr";
      #         description = "Password Manager";
      #         ping = "http://127.0.0.1:8000";
      #       };
      #     }
      #   ];
      # }
      # Row 4: Media
      {
        Media = [
          {
            Immich = {
              icon = "immich.svg";
              href = "https://photos.crapadouille.fr";
              description = "Photo Backup";
              widget = {
                type = "immich";
                version = "2";
                url = "http://127.0.0.1:2283";
                key = "{{HOMEPAGE_VAR_IMMICH_KEY}}"; # API key from Immich admin
              };
            };
          }
          # {
          #   Jellyfin = {
          #     icon = "jellyfin.svg";
          #     href = "https://jellyfin.crapadouille.fr";
          #     description = "Media Player";
          #     ping = "http://127.0.0.1:8096";
          #   };
          # }
          # {
          #   Jellyseerr = {
          #     icon = "jellyseerr.svg";
          #     href = "https://jellyseerr.crapadouille.fr";
          #     description = "Media Requests";
          #     ping = "http://127.0.0.1:5055";
          #   };
          # }
          # {
          #   Prowlarr = {
          #     icon = "prowlarr.svg";
          #     href = "https://prowlarr.crapadouille.fr";
          #     description = "Indexer Manager";
          #     ping = "http://127.0.0.1:9696";
          #   };
          # }
          # {
          #   Sonarr = {
          #     icon = "sonarr.svg";
          #     href = "https://sonarr.crapadouille.fr";
          #     description = "TV Shows";
          #     ping = "http://127.0.0.1:8989";
          #   };
          # }
          # {
          #   Radarr = {
          #     icon = "radarr.svg";
          #     href = "https://radarr.crapadouille.fr";
          #     description = "Movies";
          #     ping = "http://127.0.0.1:7878";
          #   };
          # }
          # {
          #   Bazarr = {
          #     icon = "bazarr.svg";
          #     href = "https://bazarr.crapadouille.fr";
          #     description = "Subtitles";
          #     ping = "http://127.0.0.1:6767";
          #   };
          # }
        ];
      }
      # Row 5: Food
      {
        Food = [
          {
            Tandoor = {
              icon = "tandoor";
              href = "https://tandoor.crapadouille.fr";
              description = "Recipe Manager";
              ping = "http://127.0.0.1:8085";
            };
          }
        ];
      }
      # Row 6: Markets
      {
        Markets = [
          {
            "BTC/USD" = {
              icon = "bitcoin.svg";
              href = "https://coinmarketcap.com/currencies/bitcoin/";
              description = "Bitcoin (USD)";
              widget = {
                type = "coinmarketcap";
                key = "{{HOMEPAGE_VAR_COINMARKETCAP_KEY}}";
                slugs = ["bitcoin"];
                defaultinterval = "24h";
              };
            };
          }
          {
            "BTC/EUR" = {
              icon = "bitcoin.svg";
              href = "https://coinmarketcap.com/currencies/bitcoin/";
              description = "Bitcoin (EUR)";
              widget = {
                type = "coinmarketcap";
                key = "{{HOMEPAGE_VAR_COINMARKETCAP_KEY}}";
                slugs = ["bitcoin"];
                currency = "EUR";
                defaultinterval = "24h";
              };
            };
          }
          {
            "MSCI World" = {
              icon = "mdi-chart-line";
              href = "https://finance.yahoo.com/quote/URTH";
              description = "iShares MSCI World";
              widget = {
                type = "stocks";
                provider = "finnhub";
                watchlist = ["URTH"];
              };
            };
          }
          {
            "Emerging Markets" = {
              icon = "mdi-chart-areaspline";
              href = "https://finance.yahoo.com/quote/EEM";
              description = "iShares MSCI EM";
              widget = {
                type = "stocks";
                provider = "finnhub";
                watchlist = ["EEM"];
              };
            };
          }
        ];
      }
    ];

    # Load environment secrets from agenix (for HOMEPAGE_VAR_* templating)
    environmentFiles = [config.age.secrets.homepage-env.path];

    # Fix for "Host validation failed" when behind a proxy
    allowedHosts = "home.crapadouille.fr,localhost,127.0.0.1";
  };
}
