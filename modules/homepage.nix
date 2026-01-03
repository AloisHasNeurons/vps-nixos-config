{
  config,
  pkgs,
  lib,
  ...
}: {
  services.homepage-dashboard = {
    enable = true;
    listenPort = 3001;

    # General settings
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
          columns = 1;
        };
        Crypto = {
          style = "row";
          columns = 1;
        };
      };
      providers = {
        finnhub = "{{HOMEPAGE_VAR_FINNHUB_KEY}}";
      };
    };

    # Info widgets (header area)
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
      {
        stocks = {
          provider = "finnhub";
          watchlist = [
            "DCAM.PA" # Amundi PEA MSCI World (Euronext Paris)
            "PAEEM.PA" # Amundi PEA MSCI Emerging Markets (Euronext Paris)
          ];
          color = true;
          cache = 5;
        };
      }
    ];

    # Services (main content area)
    services = [
      {
        Network = [
          {
            AdGuard = {
              icon = "adguard-home.svg";
              href = "https://adguard.crapadouille.fr";
              description = "DNS Filtering & Ad Blocking";
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
              description = "VPN Server (10.100.0.1)";
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
        ];
      }
      {
        Crypto = [
          {
            Bitcoin = {
              icon = "bitcoin.svg";
              href = "https://coinmarketcap.com/currencies/bitcoin/";
              description = "BTC Price Tracker";
              widget = {
                type = "coinmarketcap";
                key = "{{HOMEPAGE_VAR_COINMARKETCAP_KEY}}";
                symbols = ["BTC"];
                currency = "EUR";
                defaultinterval = "1d";
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
