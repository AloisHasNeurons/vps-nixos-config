let
  alois = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2uzDX8j0gCkpfmB+G9HU3PEEOGp02Nfh4FcIlQ+EWb alois.vincent@imt-atlantique.net";
  users = [ alois ];
in
{
  "wireguard-private-key.age".publicKeys = users;
}
