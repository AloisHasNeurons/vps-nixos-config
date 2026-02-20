let
  # Host key for the Hetzner VPS (retrieved via ssh-keyscan)
  vps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBzuib8d7JCplkfIeTUx4zXADUpjmymCwecxU4HOjy9l root@nixos-vps";
  alois_laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa1VOKGJI/j5mfvo5QsKk/tX+vNr3CdjdYYNfbPxdDK alois@fedora";
  users = [alois_laptop vps];
in {
  "wireguard-private-key.age".publicKeys = users;
  "homepage-env.age".publicKeys = users;
  "immich-env.age".publicKeys = users;
  "grafana-secret-key.age".publicKeys = users;
}
