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
      # Prevent clickjacking
      add_header X-Frame-Options "SAMEORIGIN" always;
      # Prevent MIME sniffing
      add_header X-Content-Type-Options "nosniff" always;
      # Basic Content Security Policy (adjust as needed for specific apps)
      # add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
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
