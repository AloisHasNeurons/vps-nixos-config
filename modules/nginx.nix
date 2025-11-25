{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Default catch-all
    virtualHosts."localhost" = {
      default = true;
      extraConfig = ''
        return 200 "Hello from Nginx!";
      '';
    };
  };
}
