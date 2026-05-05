{...}: let
  domain = "crapadouille.fr";
in {
  # ACME (Let's Encrypt) configuration
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "alois.vincent@imt-atlantique.net";

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

      # Upstreams for Immich Traffic Splitting
      upstream immich_public_proxy {
        server 127.0.0.1:3004;
      }
      upstream immich_vpn_direct {
        server 127.0.0.1:2283;
      }

      # Geo-Map source IP to upstream name (Supports CIDR)
      # VPN/Local -> Immich Direct
      # Public -> Immich Proxy
      geo $remote_addr $immich_backend {
        default          immich_public_proxy;
        100.64.0.0/10    immich_vpn_direct; # Tailscale CGNAT range
        127.0.0.1        immich_vpn_direct;
      }
    '';

    virtualHosts = {
      "adguard.${domain}" = {
        enableACME = true;
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

      "mealie.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:9000";
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
        enableACME = true;
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
        enableACME = true;
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
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://$immich_backend";
          proxyWebsockets = true;
          # Immich needs larger uploads for photos/videos
          extraConfig = ''
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
            add_header X-Content-Type-Options "nosniff" always;
            add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;

            add_header X-Debug-Source-IP $remote_addr always;
            add_header X-Debug-Backend $immich_backend always;

            client_max_body_size 50G;
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

      "gotify.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
          # We don't restrict this to VPN entirely, so the phone can receive
          # push notifications on cellular without the VPN active.
          # We only restrict the admin UI if needed, but for simplicity
          # we keep it open, as Gotify requires authentication for everything.
        };
      };

      # ── Media Suite (Tailscale only) ──────────────────────────────

      # "jellyfin.${domain}" = {
      #   enableACME = true;
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
      #   enableACME = true;
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
      #   enableACME = true;
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
      #   enableACME = true;
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
      #   enableACME = true;
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
      #   enableACME = true;
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
      "localhost" = {
        default = true;
        extraConfig = ''
          return 200 "Hello from Nginx!";
        '';
      };
    };
  };
}
