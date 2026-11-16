let
  # Host key for the Hetzner VPS. Also used by CI to pin known_hosts
  # (deploy.yml, reboot.yml), so update the file if the server is rebuilt.
  vps = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./vps-host-key.pub);
  alois_laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa1VOKGJI/j5mfvo5QsKk/tX+vNr3CdjdYYNfbPxdDK alois@fedora";
  users = [
    alois_laptop
    vps
  ];
in {
  "homepage-env.age".publicKeys = users;
  "immich-env.age".publicKeys = users;
  "grafana-secret-key.age".publicKeys = users;
  "grafana-admin-password.age".publicKeys = users;
  "tandoor-secret-key.age".publicKeys = users;
  "seedbox-ssh.age".publicKeys = users;
  "restic-env.age".publicKeys = users;
  "restic-password.age".publicKeys = users;
  "telegram-alerts.age".publicKeys = users;
  "alois-password.age".publicKeys = users;
  "acme-ovh.age".publicKeys = users;
  "tailscale-authkey.age".publicKeys = users;
}
