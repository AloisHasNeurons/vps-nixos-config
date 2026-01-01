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
    defaults.email = "alois.vincent@imt-atlantique.net"; # Change to your email
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "adguard.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
        };
      };

      "home.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

      "vault.${domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8000";
          proxyWebsockets = true;
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
