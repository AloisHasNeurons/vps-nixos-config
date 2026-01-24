{
  config,
  pkgs,
  ...
}: {
  services.mealie = {
    enable = true;
    port = 9000;
  };
}
