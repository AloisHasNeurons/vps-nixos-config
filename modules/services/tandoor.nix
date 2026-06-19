{...}: {
  services.tandoor-recipes = {
    enable = true;
    address = "127.0.0.1";
    port = 8080;
    database.createLocally = true;
    extraConfig = {
      SECRET_KEY_FILE = "/run/agenix/tandoor-secret-key";
    };
  };
}
