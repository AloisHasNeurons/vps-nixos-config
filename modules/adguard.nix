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

      dns = {
        bind_hosts = ["127.0.0.1" "10.100.0.1"];
        port = 53;

        rate_limit = 0;

        blocking_mode = "default";

        upstream_dns = [
          "h3://dns.google/dns-query" # Google (Fast)
          "h3://dns.cloudflare.com/dns-query" # Cloudflare (Fast)
          "tls://dns.quad9.net" # Quad9 (Privacy/Security)
        ];

        all_servers = true; # Query all upstreams in parallel (fastest wins)
        dnssec_enabled = true; # Validate DNSSEC signatures

        # Bootstrap with IPs to resolve the DoH/DoQ domains above
        bootstrap_dns = ["1.1.1.1" "8.8.8.8" "9.9.9.9"];

        cache_size = 536870912; # 512MB Cache (in bytes)
        cache_ttl_min = 300; # Enforce at least 5 minute cache
        cache_optimistic = true; # Serve expired cache immediately, refresh in background
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
        interval = "168h"; # Reduced to 7 days. 90 days (2160h) is huge for database performance.
      };
    };
  };
}
