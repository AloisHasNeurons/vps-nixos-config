# justfile
default:
    @just --list

# Build and run the VM
nix := "/nix/var/nix/profiles/default/bin/nix"

run-vm:
    sudo {{nix}} run .#vps-vm

# SSH into the running VM ignoring host keys
ssh-vm:
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 12222 alois@localhost

# Run CI checks locally
check:
    nix flake check
    nix build .#nixosConfigurations.vps.config.system.build.toplevel --dry-run
