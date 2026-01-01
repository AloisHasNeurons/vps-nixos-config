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

# Provision infrastructure with Terraform
provision:
    cd terraform && terraform init && terraform apply

# Install NixOS on the provisioned server
install:
    #!/usr/bin/env sh
    IP=$(cd terraform && terraform output -raw ipv4_address)
    echo "Deploying to ${IP}..."
    nix run github:nix-community/nixos-anywhere -- --copy-host-keys --flake .#vps root@${IP}
