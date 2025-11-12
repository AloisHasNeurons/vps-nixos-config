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

## Tech Stack

* **Operating System:** [NixOS](https://nixos.org/) (Unstable channel)
* **Package Management:** [Nix Flakes](https://nixos.wiki/wiki/Flakes)
* **Secret Management:** [Agenix](https://github.com/ryantm/agenix) (for handling credentials and API keys)
* **Services (Planned):**
    * [AdGuard Home](https://adguard.com/en/adguard-home.html) (Network-wide ad blocker)
    * [Homepage](https://gethomepage.dev/) (Service dashboard)
    * [Glances](https://nicolargo.github.io/glances/) (System monitoring)
    * [Gitea](https://gitea.io/en-us/) (Self-hosted Git service)
    * [Nginx](https://www.nginx.com/) (Reverse proxy)

## Local Testing & Usage

This flake includes a `vps-vm` package that builds a local QEMU virtual machine. This allows for testing the configuration *before* deploying to a live server.

To build and run the VM locally:

```bash
# 1. Build the VM package defined in flake.nix
nix build .#vps-vm

# 2. Run the VM
# (This will launch QEMU and forward all specified ports)
./result/bin/run-vps-vm
```

You can then access the VM via SSH or test its services: `ssh alois@localhost -p 2222`

---

## Roadmap

* [ ] Implement base infrastructure: `Nginx`, `Wireguard`, and `Agenix`.
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
