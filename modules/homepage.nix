{ config, pkgs, ... }:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 3001;
    settings = {
      title = "My Dashboard";
      services = [];
    };
  };
}
