{
  config,
  pkgs,
  lib,
  ...
}: {
  services.homepage-dashboard = {
    enable = true;
    listenPort = 3001;

    settings = {
      title = "Crapadouille";
      favicon = "https://cdn-icons-png.flaticon.com/512/2593/2593635.png";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";

      layout = {
        Network = {
          style = "row";
          columns = 2;
        };
        Security = {
          style = "row";
          columns = 2;
        };
        Markets = {
          style = "row";
          columns = 4; # 4 cards side by side
        };
      };

      providers = {
        finnhub = "{{HOMEPAGE_VAR_FINNHUB_KEY}}";
      };
    };

    # Header: Search + System Resources
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
      {
        resources = {
          label = "System";
          cpu = true;
          memory = true;
          disk = "/";
          uptime = true;
        };
      }
    ];

    services = [
      # Row 1: Network | Security
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
                fields = ["queries" "blocked" "filtered" "latency"];
              };
            };
          }
          {
            WireGuard = {
              icon = "wireguard.svg";
              href = "#";
              description = "VPN Server";
              ping = "10.100.0.1";
            };
          }
        ];
      }
      {
        Security = [
          {
            Vaultwarden = {
              icon = "vaultwarden.svg";
              href = "https://vault.crapadouille.fr";
              description = "Password Manager";
              ping = "http://127.0.0.1:8000";
            };
          }
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
      # Row 2: Markets (Crypto + Stocks combined)
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
  };

  # Load environment secrets from agenix
  systemd.services.homepage-dashboard.serviceConfig = {
    EnvironmentFile = lib.mkForce config.age.secrets.homepage-env.path;
  };

  # Fix for "Host validation failed" when behind a proxy
  systemd.services.homepage-dashboard.environment = {
    HOSTNAME = "127.0.0.1";
    HOMEPAGE_ALLOWED_HOSTS = lib.mkForce "home.crapadouille.fr,localhost,127.0.0.1";
  };
}
