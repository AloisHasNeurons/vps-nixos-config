<p align="center">
  <img src="https://github.com/AloisHasNeurons/vps-nixos-config/blob/master/.github/project_snippet.png?raw=true" alt="Project Snippet" width="700">
</p>

<h1 align="center">Declarative NixOS VPS Configuration</h1>

<p align="center">
  <a href="https://nixos.org/">
    <img src="https://img.shields.io/badge/NixOS-unstable-blue.svg?logo=nixos" alt="NixOS Unstable">
  </a>
  <a href="https://github.com/AloisHasNeurons/vps-nixos-config/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  </a>
  <a href="https://github.com/AloisHasNeurons/vps-nixos-config/actions">
    <img src="https://github.com/AloisHasNeurons/vps-nixos-config/actions/workflows/ci-nix.yml/badge.svg" alt="CI Status">
  </a>
  <a href="https://github.com/AloisHasNeurons/vps-nixos-config/actions">
    <img src="https://github.com/AloisHasNeurons/vps-nixos-config/actions/workflows/deploy.yml/badge.svg" alt="CD Status">
  </a>
</p>

<p align="center">
  This repository represents the culmination of my journey into modern <b>DevOps, Systems Engineering, and SRE</b> principles. It is a fully declarative, reproducible, and verifiable server configuration built with NixOS and Terraform.
  <br />
  <br />
  <a href="#-the-challenge"><strong>The Challenge</strong></a>
  ·
  <a href="#-the-solution-method"><strong>The Solution</strong></a>
  ·
  <a href="#-observability--monitoring"><strong>Observability</strong></a>
  ·
  <a href="#-gitops--automation"><strong>GitOps</strong></a>
  ·
  <a href="#-security--ci"><strong>Security</strong></a>
</p>

---

## The Challenge

Managing servers manually ("ClickOps") or via imperative scripts (Bash/Ansible) often leads to **Configuration Drift**. Over time, the state of the server diverges from the documentation, making updates terrifying and rollbacks impossible.

I wanted to solve the "Fear of Updates." I wanted a system where:
1.  **Destruction is trivial**: I can delete the server right now and have it back online, with a different cloud provider, or in my bedroom, in 10 minutes, exactly as it was.
2.  **Security is proved**: I don't just *hope* I closed the firewall ports; my CI pipeline *proves* it before I deploy.
3.  **Maintenance is automated**: Dependency updates should be mundane, not special events.

## The Solution

To achieve this, I adopted a strict **Infrastructure as Code (IaC)** philosophy, separating the concern into distinct layers:

### 1. The Infrastructure Layer (Terraform)
I treat the server hardware as disposable. Using **Terraform** with the **Hetzner Cloud** provider, I define the physical resources (Servers, SSH Keys, Volumes).
*   **Why?** Terraform tracks the state of the cloud resources. If I change the server type in `main.tf`, Terraform handles the complex replacement logic automatically.

### 2. The Configuration Layer (NixOS)
Once the hardware exists, **NixOS** takes over. Unlike traditional distros, NixOS is declarative.
*   **Why?** I don't write scripts to *change* the system state (e.g., `apt-get install nginx`). I define the *final* state (e.g., `services.nginx.enable = true`). Nix ensures the reality matches the definition, atomically and reliably.

---

## GitOps & Automated Maintenance vs Toil

A key SRE principle is eliminating toil. I implemented a **GitOps workflow** to handle system updates automatically using **Renovate Bot**.

**The Workflow:**
1.  **Scan:** Renovate scans my `flake.nix` for outdated inputs (NixOS system updates) or dependencies.
2.  **PR:** It opens a Pull Request automatically (e.g., *"Update NixOS to 25.05"*).
3.  **Verify:** GitHub Actions CI runs the full test suite (including the [security scanner](#-security--ci)).
4.  **Merge & Deploy:** Once merged, the CD pipeline automatically deploys the update.

**The Safety Net:**
*   **Atomic Updates:** If the build fails on the server, the switch is aborted. The system is never left in a broken state.
*   **Rollbacks:** Every deployment creates a new boot generation. If a service behaves incorrectly, a single command (`nixos-rebuild switch --rollback`) instantaneous reverts the entire system state.

---

## Observability & Monitoring

You can't manage what you can't measure. I integrated a full monitoring stack to ensure system health and performance visibility.

*   **Prometheus:** Scrapes metrics from system services (`node_exporter`) and applications.
*   **Grafana:** Visualizes these metrics in a unified dashboard.
*   **Homepage:** A central entry point aggregating status from all services (Docker APIs, system stats, weather, markets) into a single "Mission Control" UI.

This setup allows me to spot resource bottlenecks (CPU/RAM spikes) or service outages immediately.

---

## Security & Continuous Verification

Trust, but verify. A unique feature of this project is the **Forward-Compatible Security Scanner**.

Most security setups rely on manual periodic audits. I automated this by writing a custom **NixOS Integration Test** that runs inside the GitHub Actions CI pipeline.

### The "Default Deny" Scanner
Before any code is merged, the CI system:
1.  **Boots a VM** with the exact production configuration.
2.  **Simulates an Attack**: A secondary attacker machine runs an `nmap` scan against the VM.
3.  **Audits Ports**: It acts as a whitelist. If *any* port is found open that isn't explicitly allowed (SSH/22, HTTP/80, HTTPS/443), the **pipeline fails**.

> **Result:** It is impossible for me to accidentally expose an internal service (like the `Grafana`, or `Adguard` admin panel) to the public internet. The bad deploy is blocked before it ever leaves git.

---

## Architecture & Tech Stack

This stack is designed to be a comprehensive, self-hosted ecosystem.

### Core Stack
*   **OS & Deployment:** `NixOS` (Unstable) + `Nix Flakes`
*   **Provisioning:** `Terraform` + `Terraform Cloud`
*   **Secret Management:** `Agenix` (Age-encrypted secrets stored in Git)
*   **CI/CD:** `GitHub Actions`
*   **Maintenance:** `Renovate Bot`

### Hosted Services
*   **Networking:** WireGuard VPN + NFTables (Masquerading)
*   **Reverse Proxy:** Nginx (ACME/Let's Encrypt)
*   **Observability:** Grafana + Prometheus
*   **Media & Storage:** Immich (Self-hosted Photos/Videos)
*   **DNS Filtering:** AdGuard Home
*   **Dashboard:** Homepage (Unified Service Status)
*   **Recipe manager:** Tandoor
---

## Usage & Deployment

The entire lifecycle is managed via `just` recipes, simplifying complex commands into standard verbs. And the deployment to the server is automatic when pushed to GitHub.

### Local Testing
You can run the full test suite locally without touching the real server:

```bash
# Run the security integration test (boots a VM)
nix flake check

# Build a local VM for manual testing
nix run .#vps-vm
```

### Deployment Commands

```bash
# 1. Provision infrastructure (Terraform)
just provision

# 2. Deploy updates (Configures NixOS, runs reboot checks)
just deploy
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
<p align="center">
  <em>Aloïs Vincent - Software Engineering Student</em>
</p>
