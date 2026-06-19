{config, ...}: {
  services.tandoor-recipes = {
    enable = true;
    address = "127.0.0.1";
    port = 8085;
    database.createLocally = true;
    extraConfig = {
      SECRET_KEY_FILE = "/run/credentials/tandoor-recipes.service/tandoor-secret-key";
      ALLOWED_HOSTS = "tandoor.crapadouille.fr,localhost,127.0.0.1";
    };
  };

  systemd.services.tandoor-recipes.serviceConfig.LoadCredential = [
    "tandoor-secret-key:${config.age.secrets.tandoor-secret-key.path}"
  ];
}
