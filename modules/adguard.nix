{ config, pkgs, ... }:

{
  services.adguardhome = {
    enable = true;
    port = 3000;
    settings = {
      http = {
        address = "127.0.0.1:3000"; # Web UI only on localhost (proxied by nginx)
      };
      dns = {
        # Only bind DNS on localhost and WireGuard interface - NOT public!
        bind_hosts = [ "127.0.0.1" "10.100.0.1" ];
        port = 53;
        upstream_dns = [ "1.1.1.1" "8.8.8.8" ];
      };
    };
  };
}
