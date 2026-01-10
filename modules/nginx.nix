{
  config,
  pkgs,
  ...
}: let
  domain = "crapadouille.fr";
in {
  # ACME (Let's Encrypt) configuration
  security.acme = {
    acceptTerms = true;
    defaults.email = "alois.vincent@imt-atlantique.net";
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
        default       immich_public_proxy;
        10.100.0.0/24 immich_vpn_direct;
        127.0.0.1     immich_vpn_direct;
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
            allow 10.100.0.0/24;
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
            allow 10.100.0.0/24;
            allow 127.0.0.1;
            deny all;
          '';
        };
      };

      "vault.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8000";
          proxyWebsockets = true;
          # Restrict to VPN
          extraConfig = ''
            allow 10.100.0.0/24;
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
            allow 10.100.0.0/24;
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
