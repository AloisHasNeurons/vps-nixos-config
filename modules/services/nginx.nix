{config, ...}: let
  domain = "crapadouille.fr";
in {
  # ACME Wildcard Configuration
  security.acme = {
    acceptTerms = true;
    defaults.email = "alois.vincent@imt-atlantique.net";
    certs."${domain}" = {
      # The wildcard only covers one level: share.photos needs its own name
      extraDomainNames = ["*.${domain}" "share.photos.${domain}"];
      dnsProvider = "ovh";
      dnsPropagationCheck = true;
      # The server resolves through Tailscale DNS, i.e. its own AdGuard, which
      # rewrites our domain. Use public DNS so the zone lookup sees the real zone.
      dnsResolver = "1.1.1.1:53";
      # OVH_ENDPOINT, OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY
      environmentFile = config.age.secrets.acme-ovh.path;
      group = "nginx"; # Gives Nginx permission to read the keys
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedTlsSettings = true;

    # Harden Nginx - Security Headers
    commonHttpConfig = ''
      # Add HSTS header with preloading to force HTTPS
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      # Prevent MIME sniffing
      add_header X-Content-Type-Options "nosniff" always;
      # CSP: unsafe-eval needed for Grafana plugins, unsafe-inline for inline scripts
      add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
    '';

    virtualHosts = {
      "adguard.${domain}" = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
          # Restrict to VPN
          extraConfig = ''
            allow 100.64.0.0/10; # Tailscale CGNAT range
            allow 127.0.0.1;
            deny all;
          '';
        };
      };

      "tandoor.${domain}" = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8085";
          proxyWebsockets = true;
          # Restrict to VPN
          extraConfig = ''
            allow 100.64.0.0/10; # Tailscale CGNAT range
            allow 127.0.0.1;
            deny all;
          '';
        };
      };

      "home.${domain}" = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
          # Restrict to VPN
          extraConfig = ''
            allow 100.64.0.0/10; # Tailscale CGNAT range
            allow 127.0.0.1;
            deny all;
          '';
        };
      };

      "grafana.${domain}" = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3002";
          proxyWebsockets = true;
          # Restrict to VPN
          extraConfig = ''
            allow 100.64.0.0/10; # Tailscale CGNAT range
            allow 127.0.0.1;
            deny all;
          '';
        };
      };

      "photos.${domain}" = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:2283";
          proxyWebsockets = true;
          # Restrict to VPN. Immich needs larger uploads for photos/videos
          extraConfig = ''
            allow 100.64.0.0/10; # Tailscale CGNAT range
            allow 127.0.0.1;
            deny all;

            client_max_body_size 50G;
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
          '';
        };
      };

      # Public: Immich Public Proxy only serves the links shared from Immich
      "share.photos.${domain}" = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.immich-public-proxy.port}";
        };
      };

      # ── Media Suite (Tailscale only) ──────────────────────────────

      # "jellyfin.${domain}" = {
      #   useACMEHost = domain;
      #   forceSSL = true;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:8096";
      #     proxyWebsockets = true;
      #     extraConfig = ''
      #       allow 100.64.0.0/10; # Tailscale CGNAT range
      #       allow 127.0.0.1;
      #       deny all;
      #
      #       # Allow large media streaming responses
      #       client_max_body_size 0;
      #       proxy_read_timeout 600s;
      #       proxy_send_timeout 600s;
      #     '';
      #   };
      # };
      #
      # "jellyseerr.${domain}" = {
      #   useACMEHost = domain;
      #   forceSSL = true;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:5055";
      #     proxyWebsockets = true;
      #     extraConfig = ''
      #       allow 100.64.0.0/10; # Tailscale CGNAT range
      #       allow 127.0.0.1;
      #       deny all;
      #     '';
      #   };
      # };
      #
      # "prowlarr.${domain}" = {
      #   useACMEHost = domain;
      #   forceSSL = true;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:9696";
      #     proxyWebsockets = true;
      #     extraConfig = ''
      #       allow 100.64.0.0/10; # Tailscale CGNAT range
      #       allow 127.0.0.1;
      #       deny all;
      #     '';
      #   };
      # };
      #
      # "sonarr.${domain}" = {
      #   useACMEHost = domain;
      #   forceSSL = true;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:8989";
      #     proxyWebsockets = true;
      #     extraConfig = ''
      #       allow 100.64.0.0/10; # Tailscale CGNAT range
      #       allow 127.0.0.1;
      #       deny all;
      #     '';
      #   };
      # };
      #
      # "radarr.${domain}" = {
      #   useACMEHost = domain;
      #   forceSSL = true;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:7878";
      #     proxyWebsockets = true;
      #     extraConfig = ''
      #       allow 100.64.0.0/10; # Tailscale CGNAT range
      #       allow 127.0.0.1;
      #       deny all;
      #     '';
      #   };
      # };
      #
      # "bazarr.${domain}" = {
      #   useACMEHost = domain;
      #   forceSSL = true;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:6767";
      #     proxyWebsockets = true;
      #     extraConfig = ''
      #       allow 100.64.0.0/10; # Tailscale CGNAT range
      #       allow 127.0.0.1;
      #       deny all;
      #     '';
      #   };
      # };

      # Default catch-all
      # In a location, not at server level: a server-level `return` would also
      # answer /nginx_status (statusPage, for the Prometheus nginx exporter)
      "localhost" = {
        default = true;
        locations."/".extraConfig = ''
          return 200 "Hello from Nginx!";
        '';
      };
    };
  };
}
