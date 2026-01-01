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

# Update NixOS on the running server (faster than install)
deploy:
    #!/usr/bin/env sh
    IP=$(cd terraform && terraform output -raw ipv4_address)
    echo "Updating server at ${IP}..."
    nix run nixpkgs#nixos-rebuild -- switch --flake .#vps --target-host root@${IP}

# Regenerate WireGuard client configs with current server public key
wg-clients:
    #!/usr/bin/env bash
    set -e
    SERVER_PUBKEY=$(cat secrets/wireguard-server.pub)
    ENDPOINT="crapadouille.fr:51820"
    
    # Laptop config
    LAPTOP_KEY=$(cat clients/laptop.key)
    printf '[Interface]\nPrivateKey = %s\nAddress = 10.100.0.2/24\nDNS = 10.100.0.1\n\n[Peer]\nPublicKey = %s\nEndpoint = %s\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25\n' "$LAPTOP_KEY" "$SERVER_PUBKEY" "$ENDPOINT" > clients/laptop.conf
    echo "Generated clients/laptop.conf"
    
    # Phone config
    PHONE_KEY=$(cat clients/phone.key)
    printf '[Interface]\nPrivateKey = %s\nAddress = 10.100.0.3/24\nDNS = 10.100.0.1\n\n[Peer]\nPublicKey = %s\nEndpoint = %s\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25\n' "$PHONE_KEY" "$SERVER_PUBKEY" "$ENDPOINT" > clients/phone.conf
    echo "Generated clients/phone.conf"
    echo ""
    echo "Don't forget to update your devices with the new configs!"

# Regenerate WireGuard SERVER keys (run this when rotating keys)
wg-server-key:
    #!/usr/bin/env bash
    set -e
    echo "Generating new WireGuard server keys..."
    
    # Generate new keypair
    PRIVATE_KEY=$(nix-shell -p wireguard-tools --run 'wg genkey')
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | nix-shell -p wireguard-tools --run 'wg pubkey')
    
    # Save public key (not secret)
    echo "$PUBLIC_KEY" > secrets/wireguard-server.pub
    echo "Saved public key to secrets/wireguard-server.pub"
    
    # Encrypt private key with age
    echo "$PRIVATE_KEY" | nix-shell -p age --run 'age -r "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2uzDX8j0gCkpfmB+G9HU3PEEOGp02Nfh4FcIlQ+EWb" -r "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa1VOKGJI/j5mfvo5QsKk/tX+vNr3CdjdYYNfbPxdDK" -o secrets/wireguard-private-key.age'
    echo "Encrypted private key to secrets/wireguard-private-key.age"
    
    echo ""
    echo "New server public key: $PUBLIC_KEY"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'just wg-clients' to regenerate client configs"
    echo "  2. Commit changes"
    echo "  3. Redeploy server"
