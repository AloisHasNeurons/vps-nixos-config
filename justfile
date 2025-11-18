# justfile
default:
    @just --list

# Build and run the VM
run-vm:
    sudo nix run .#vps-vm

# SSH into the running VM ignoring host keys
ssh-vm:
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 alois@localhost
