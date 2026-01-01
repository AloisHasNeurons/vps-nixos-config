resource "hcloud_ssh_key" "default" {
  name       = "terraform-deploy-key"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_server" "vps" {
  name        = var.server_name
  image       = "ubuntu-24.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = <<-EOT
    #cloud-config
    users:
      - name: root
        ssh_authorized_keys:
          - ${file(var.ssh_public_key_path)}
  EOT
}
