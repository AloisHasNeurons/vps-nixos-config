{ config, pkgs, ... }:

{
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_PORT = 8000;
      ROCKET_ADDRESS = "0.0.0.0";
    };
  };
}
