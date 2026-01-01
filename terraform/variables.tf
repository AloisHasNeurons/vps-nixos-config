variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "server_name" {
  description = "Name of the VPS"
  type        = string
  default     = "nixos-vps"
}

variable "server_type" {
  description = "Hetzner Server Type (e.g. cx23, cpx31)"
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner Location (e.g. nbg1, fsn1)"
  type        = string
  default     = "nbg1"
}

variable "ssh_public_key_path" {
  description = "Path to the local SSH public key to upload"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
