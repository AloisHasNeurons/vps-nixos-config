{config, ...}: {
  services.tandoor-recipes = {
    enable = true;
    address = "127.0.0.1";
    port = 8080;
    database.createLocally = true;
    extraConfig = {
      SECRET_KEY_FILE = "/run/credentials/tandoor-recipes.service/tandoor-secret-key";
    };
  };

  systemd.services.tandoor-recipes.serviceConfig.LoadCredential = [
    "tandoor-secret-key:${config.age.secrets.tandoor-secret-key.path}"
  ];
}
