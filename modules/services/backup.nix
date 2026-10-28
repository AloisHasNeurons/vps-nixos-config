{
  pkgs,
  config,
  ...
}: let
  # Horodatage du dernier succès, lu par le collecteur textfile de node_exporter
  # (alertes BackupStale / BackupNeverRecorded dans prometheus.nix).
  # Préfixe "+" : s'exécute en root, postgresqlBackup tourne en tant que postgres.
  recordSuccess = backup:
    "+"
    + pkgs.writeShellScript "record-backup-${backup}" ''
      f=/var/lib/node-exporter-textfile/backup-${backup}.prom
      echo "backup_last_success_timestamp_seconds{backup=\"${backup}\"} $(date +%s)" > "$f.tmp"
      mv "$f.tmp" "$f"
    '';
in {
  # Déclaration Agenix pour injecter les secrets au runtime
  age.secrets.restic-env.file = ../../secrets/restic-env.age;
  age.secrets.restic-password.file = ../../secrets/restic-password.age;

  # Dumps cohérents de Postgres (Immich + Tandoor) avant le backup restic.
  # Copier /var/lib/postgresql à chaud ne garantit pas une restauration utilisable.
  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    startAt = "02:30";
    # Pas de gzip : restic compresse déjà et déduplique mieux un dump en clair
    compression = "none";
  };

  services.restic.backups = {
    vps-data = {
      initialize = true;
      # Les chemins à sauvegarder (uniquement l'état)
      paths = [
        "/var/lib"
        config.services.postgresqlBackup.location
      ];

      # Données inutiles, régénérables, ou incohérentes si copiées à chaud
      exclude = [
        "/var/lib/swapfile"
        "/var/lib/postgresql" # couvert par les dumps de postgresqlBackup
        "/var/lib/containers"
        "/var/lib/prometheus2"
        "${config.services.immich.mediaLocation}/thumbs"
        "${config.services.immich.mediaLocation}/encoded-video"
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

      # Vérification d'intégrité d'un échantillon des données après le prune
      checkOpts = ["--read-data-subset=5%"];
    };
  };

  # Alertes Telegram si le dump ou le backup échoue (y compris le `restic check`)
  systemd.services.postgresqlBackup.unitConfig.OnFailure = "notify-failure@%n.service";
  systemd.services.restic-backups-vps-data.unitConfig.OnFailure = "notify-failure@%n.service";

  # ExecStartPost ne s'exécute que si tout ExecStart a réussi (backup, prune, check)
  systemd.services.postgresqlBackup.serviceConfig.ExecStartPost = [(recordSuccess "postgres")];
  systemd.services.restic-backups-vps-data.serviceConfig.ExecStartPost = [(recordSuccess "restic")];
}
