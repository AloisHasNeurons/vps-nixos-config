terraform {
  cloud {
    organization = "AloisHasNeurons-Personal"
    workspaces {
      name = "vps-nixos"
    }
  }
}

resource "hcloud_ssh_key" "default" {
  name       = "terraform-deploy-key"
  public_key = var.ssh_public_key
}

resource "hcloud_server" "vps" {
  name        = var.server_name
  image       = "ubuntu-24.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]

  # Guard against accidental destruction: the server holds the Immich photos.
  # Hetzner requires both flags to have the same value.
  delete_protection  = true
  rebuild_protection = true

  # Daily Hetzner snapshots (7 kept, ~20% of the server price)
  backups = true

  lifecycle {
    # NixOS is installed over the initial Ubuntu image, so `image` is only
    # meaningful at creation time and must never trigger a replacement.
    ignore_changes  = [user_data, ssh_keys, image]
    prevent_destroy = true
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = <<-EOT
    #cloud-config
    users:
      - name: root
        ssh_authorized_keys:
          - ${var.ssh_public_key}
  EOT
}
