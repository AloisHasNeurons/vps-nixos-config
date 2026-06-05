{config, ...}: {
  # Déclaration Agenix pour injecter les secrets au runtime
  age.secrets.restic-env.file = ../../secrets/restic-env.age;
  age.secrets.restic-password.file = ../../secrets/restic-password.age;

  services.restic.backups = {
    vps-data = {
      initialize = true;
      # Les chemins à sauvegarder (uniquement l'état)
      paths = [
        "/var/lib"
      ];

      # Syntaxe native B2
      repository = "b2:Alois-NixOS-VPS-B2-Backup";

      # Lien vers les secrets Agenix
      environmentFile = config.age.secrets.restic-env.path;
      passwordFile = config.age.secrets.restic-password.path;

      # Exécution tous les jours à 3h du matin
      timerConfig = {
        OnCalendar = "03:00";
        Persistent = true;
      };

      # Nettoyage automatique des anciens snapshots
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
    };
  };
}
