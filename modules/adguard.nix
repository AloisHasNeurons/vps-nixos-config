{
  config,
  pkgs,
  ...
}: {
  services.adguardhome = {
    enable = true;
    port = 3000;
    settings = {
      http = {
        address = "127.0.0.1:3000"; # Web UI only on localhost (proxied by nginx)
      };
      dns = {
        bind_hosts = ["127.0.0.1" "10.100.0.1"];
        port = 53;
        # Parallel upstream requests for speed
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        bootstrap_dns = ["1.1.1.1" "8.8.8.8" "9.9.9.9"];
        rate_limit = 0; # Unlimited
      };
      filtering = {
        safe_browsing = true; # Block phishing/malware
        safe_search = {
          enabled = false;
        };
      };
      filters = [
        {
          enabled = true;
          url = "https://big.oisd.nl"; # OISD Big (Comprehensive, low false positives)
          name = "OISD Big";
          id = 1;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"; # AdGuard DNS filter
          name = "AdGuard DNS filter";
          id = 2;
        }
      ];
      statistics = {
        enabled = true;
        interval = "24h"; # retention
      };
      querylog = {
        enabled = true;
        interval = "2160h"; # 90 days retention
      };
    };
  };
}
