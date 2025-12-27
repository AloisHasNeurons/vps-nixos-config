{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Define the domain for our services
    # In a real setup, this would be passed as a variable or defined in a higher-level config.
    virtualHosts = let
      domain = "example.com";
    in {
      "adguard.${domain}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
        };
      };

      "home.${domain}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

      "vault.${domain}" = {
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
