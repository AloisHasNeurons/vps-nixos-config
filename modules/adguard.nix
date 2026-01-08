{
  config,
  pkgs,
  ...
}: {
  services.adguardhome = {
    enable = true;
    mutableSettings = false;

    settings = {
      http = {
        address = "127.0.0.1:3000";
        session_ttl = "720h";
      };

      users = [
        {
          name = "admin";
          password = "$2a$12$IZz/nGZ3Mp0vsoqOnm2MzuHzeHKRljy4xWp1McpUk.I0wE5x8WvuG";
        }
      ];

      dns = {
        upstream_dns = [
          "https://dns.google/dns-query"
          "https://dns.cloudflare.com/dns-query"
          "tls://dns.quad9.net"
        ];

        bootstrap_dns = ["1.1.1.1" "8.8.8.8" "9.9.9.9"];
        bind_hosts = ["127.0.0.1" "10.100.0.1"];
        port = 53;

        ratelimit = 0;

        blocking_mode = "default";

        upstream_mode = "parallel";
        dnssec_enabled = true; # Validate DNSSEC signatures

        cache_size = 536870912; # 512MB Cache (in bytes)
        cache_ttl_min = 300; # Enforce at least 5 minute cache
        cache_optimistic = true; # Serve expired cache immediately, refresh in background

        # Split DNS: Resolve photos locally when on VPN so Nginx sees VPN IP
        rewrites = [
          {
            domain = "photos.crapadouille.fr";
            answer = "10.100.0.1";
          }
        ];
      };

      filtering = {
        safe_browsing = true;
        safe_search = {
          enabled = false;
        };
      };

      filters = [
        {
          enabled = true;
          url = "https://big.oisd.nl";
          name = "OISD Big";
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
          name = "HaGeZi Pro"; # Backup list for redundancy
        }
      ];

      statistics = {
        enabled = true;
        interval = "24h";
      };

      querylog = {
        enabled = true;
        interval = "168h";
      };
    };
  };
}
