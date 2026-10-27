{...}: {
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
          # Kept inline on purpose: with mutableSettings = false the whole
          # config ends up in /nix/store anyway, and injecting it from agenix would need
          # a custom preStart on a critical service. The passphrase is long enough that
          # the public bcrypt hash can't realistically be cracked.
          password = "$2a$12$IZz/nGZ3Mp0vsoqOnm2MzuHzeHKRljy4xWp1McpUk.I0wE5x8WvuG";
        }
      ];

      dns = {
        upstream_dns = [
          "https://dns.mullvad.net/dns-query"
          "https://dns.google/dns-query"
          "https://dns.cloudflare.com/dns-query"
          "tls://dns.quad9.net"
        ];

        bootstrap_dns = ["1.1.1.1" "8.8.8.8" "9.9.9.9"];
        bind_hosts = ["127.0.0.1" "0.0.0.0"];
        port = 53;

        ratelimit = 0;

        blocking_mode = "default";

        upstream_mode = "parallel";
        dnssec_enabled = true; # Validate DNSSEC signatures

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

      # Tailnet clients reach every subdomain over Tailscale, whatever the
      # public DNS says. Top-level key: AdGuard ignores unknown keys silently.
      # Only A/AAAA: an untyped rewrite also empties SOA/TXT answers, which broke
      # lego's zone lookup. AAAA gets an empty answer, keeping clients on IPv4.
      user_rules = [
        "||crapadouille.fr^$dnstype=A|AAAA,dnsrewrite=100.109.82.105"
      ];

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
