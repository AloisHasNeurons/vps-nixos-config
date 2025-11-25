<p align="center">
  <a href="https://nixos.org/">
    <img src="https://img.shields.io/badge/NixOS-unstable-blue.svg?logo=nixos" alt="NixOS Unstable">
  </a>
  <a href="https://github.com/AloisHasNeurons/vps-nixos-config/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  </a>
  <a href="https://nixos.org/">
    <img src="https://img.shields.io/badge/Built%20with-Nix-5277C3.svg?logo=nix" alt="Built with Nix">
  </a>
  <a href="https://github.com/alois-vincent/vps-nixos-config/commits/master">
    <img src="https://img.shields.io/github/last-commit/AloisHasNeurons/vps-nixos-config" alt="Last Commit">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/status-work_in_progress-yellow.svg" alt="Status: WIP">
  </a>
</p>

<p align="center">
  <img src="https://github.com/AloisHasNeurons/vps-nixos-config/blob/master/.github/project_snippet.png?raw=true" alt="Project Snippet" width="700">
</p>

<h1 align="center">Declarative NixOS VPS Configuration</h1>

<p align="center">
  This repository contains the declarative configuration for my personal VPS, built entirely with NixOS and Nix Flakes.
  <br />
  <br />
  <a href="#-purpose--objective"><strong>Purpose</strong></a>
  ·
  <a href="#-tech-stack"><strong>Tech Stack</strong></a>
  ·
  <a href="#-local-testing--usage"><strong>Local Testing</strong></a>
  ·
  <a href="#-roadmap"><strong>Roadmap</strong></a>
</p>

---

## Purpose & Objective

The goal of this project is to manage a server in a fully reproducible, declarative, and auditable way. This serves as a practical portfolio for DevOps, Systems Engineering, and Site Reliability Engineering (SRE) principles.

This configuration defines the *entire state* of the server, from the operating system and user accounts to the services and security.

## Project Status

This configuration is **actively under development**. The immediate goal is to finalize the base system setup and begin deploying services. The "Last Commit" badge at the top reflects the most recent progress.

## Tech Stack & Service Philosophy

This stack is designed to be a comprehensive, self-hosted ecosystem. Services are provisioned declaratively using NixOS modules.

### Core Infrastructure
* **OS & Deployment:** `NixOS` (Unstable) + `Nix Flakes`
* **Secret Management:** `Agenix` (for handling credentials and API keys)
* **Networking (VPN):** `Wireguard` (for secure, remote access to the server and LAN)
* **Reverse Proxy:** `Nginx` (to manage and secure web traffic to all services)
* **Monitoring:** `Prometheus` + `Grafana` (Industry-standard metrics and visualization)
* **Dashboard:** `Homepage` (A clean navigation portal for all services)
* **DNS Filtering:** `Adguard Home` (Network-wide ad & tracker blocking)

### Application Services (Planned)
* **Password Management:** `Vaultwarden` (Bitwarden-compatible, lightweight server)
* **Photo Management:** `Immich` (Google Photos alternative)
* **File Storage (S3):** `MinIO` (S3-compatible object storage, great for cloud-native skills)
* **File Storage (Drive):** `Nextcloud` (A full-featured Google Drive alternative)
* **Git Server:** `Gitea` (Lightweight self-hosted Git service)
* **Media Server:** `Jellyfin` (Self-hosted media streaming)
* **System View:** `Glance` (Quick system resource monitoring)

### Provisioning & Deployment (Planned)
* **Initial Install:** `nix-infect` or `nix-anywhere` (for provisioning a non-NixOS machine)
* **Remote Updates:** (e.g., `deploy-rs`, `colmena`, or custom shell scripts)


## Local Testing & Usage

This flake includes a `vps-vm` package that builds a local QEMU virtual machine. This allows for testing the configuration *before* deploying to a live server.

To build and run the VM locally:

```bash
# Build the VM package defined in flake.nix
nix run .#vps-vm
```

You can then access the VM via SSH or test its services: `ssh alois@localhost -p 2222`

---

## Roadmap

* [x] Implement base infrastructure: `Nginx`, `Wireguard`, and `Agenix`.
* [ ] Deploy initial utility services (`Homepage`, `Adguard`, `Vaultwarden`).
* [ ] Configure `Prometheus` + `Grafana` for core system monitoring.
* [ ] Deploy stateful services with persistent volumes (`Immich`, `Gitea`, `MinIO`).
* [ ] (Future) Explore initial provisioning and remote deployment using a tool like `nix-infect` or `nix-anywhere`.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
<p align="center">
  <em>Aloïs Vincent - Software Engineering Student</em>
</p>
