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
  default     = "cx33"
}

variable "location" {
  description = "Hetzner Location (e.g. nbg1, fsn1)"
  type        = string
  default     = "fsn1"
}

variable "ssh_public_key" {
  description = "Content of the SSH public key to upload"
  type        = string
}

variable "aws_region" {
  description = "AWS region for monitoring deployment"
  type        = string
  default     = "us-east-1"
}

variable "target_url" {
  description = "URL to monitor"
  type        = string
  default     = "https://crapadouille.fr"
}

variable "telegram_token" {
  description = "Telegram Bot Token for alerts"
  type        = string
  sensitive   = true
  default     = "PLACEHOLDER_TOKEN"
}

variable "telegram_chat_id" {
  description = "Telegram Chat ID to send alerts to"
  type        = string
  sensitive   = true
  default     = "PLACEHOLDER_CHAT_ID"
}
