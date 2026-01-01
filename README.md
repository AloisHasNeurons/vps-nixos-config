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
    <img src="https://github.com/AloisHasNeurons/vps-nixos-config/actions/workflows/ci.yml/badge.svg" alt="CI Status">
  </a>
  <a href="https://github.com/AloisHasNeurons/vps-nixos-config/actions">
    <img src="https://github.com/AloisHasNeurons/vps-nixos-config/actions/workflows/deploy.yml/badge.svg" alt="CD Status">
  </a>
</p>

<p align="center">
  This repository represents the culmination of my journey into modern **DevOps, Systems Engineering, and SRE principles**. It is a fully declarative, reproducible, and verifiable server configuration built with NixOS and Terraform.
  <br />
  <br />
  <a href="#-the-challenge"><strong>The Challenge</strong></a>
  ·
  <a href="#-the-solution-method"><strong>The Solution</strong></a>
  ·
  <a href="#-tech-stack"><strong>Tech Stack</strong></a>
  ·
  <a href="#-infrastructure-as-code-terraform"><strong>Terraform</strong></a>
  ·
  <a href="#-security--ci"><strong>Security & CI</strong></a>
</p>

---

## The Challenge

Managing servers manually ("ClickOps") or via imperative scripts (Bash/Ansible) often leads to **Configuration Drift**. Over time, the state of the server diverges from the documentation, making updates terrifying and rollbacks impossible.

I wanted to solve the "Fear of Updates." I wanted a system where:
1.  **Destruction is trivial**: I can delete the server right now and have it back online, with a different cloud provider, or in my bedroom, in 10 minutes, exactly as it was.
2.  **Security is proved**: I don't just *hope* I closed the firewall ports; my CI pipeline *proves* it before I deploy.
3.  **State is explicit**: If it's not in the git repo, it doesn't exist.

## The Solution

To achieve this, I adopted a strict **Infrastructure as Code (IaC)** philosophy, separating the concern into two distinct layers:

### 1. The Infrastructure Layer (Terraform)
I treat the server hardware as disposable. Using **Terraform** with the **Hetzner Cloud** provider, I define the physical resources (Servers, SSH Keys, Volumes).
*   **Why?** Terraform tracks the state of the cloud resources. If I change the server type in `main.tf`, Terraform handles the complex replacement logic automatically. It removes the human element from provisioning.

### 2. The Configuration Layer (NixOS)
Once the hardware exists, **NixOS** takes over. Unlike traditional distros, NixOS is declarative.
*   **Why?** I don't write scripts to *change* the system state (e.g., `apt-get install nginx`). I define the *final* state (e.g., `services.nginx.enable = true`). Nix ensures the reality matches the definition, atomically and reliably.

---

## 🛠️ Infrastructure as Code: Terraform

I leveraged **Terraform Cloud** to store the state file remotely, ensuring that the infrastructure can be managed from any machine or CI pipeline without risking state corruption.

**Key Implementation Details:**
*   **Resource Lifecycle:** The server configuration prevents accidental destruction by ignoring changes to `user_data` after initial provisioning.
*   **Secret Injection:** SSH keys and API tokens are injected dynamically, never hardcoded.
*   **Output Piping:** Terraform outputs the server's public IP, which is automatically picked up by the deployment pipeline.

```hcl
resource "hcloud_server" "vps" {
  name        = "nixos-server"
  image       = "ubuntu-24.04" # Bootstrap image
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  # Prevent accidental recreation of the persistent server
  lifecycle {
    ignore_changes = [user_data, ssh_keys]
  }
}
```

---

## 🛡️ Security & Continuous Verification

Trust, but verify. A unique feature of this project is the **Forward-Compatible Security Scanner**.

Most security setups rely on manual periodic audits. I automated this by writing a custom **NixOS Integration Test** that runs inside the GitHub Actions CI pipeline.

### The "Default Deny" Scanner
Before any code is merged, the CI system:
1.  **Boots a VM** with the exact production configuration.
2.  **Simulates an Attack**: A secondary attacker machine runs an `nmap` scan against the VM.
3.  **Audits Ports**: It acts as a whitelist. If *any* port is found open that isn't explicitly allowed (SSH/22, HTTP/80, HTTPS/443), the **pipeline fails**.

> **Result:** It is impossible for me to accidentally expose an internal service (like the `Vaultwarden` admin panel or `Adguard` DNS) to the public internet. The bad deploy is blocked before it ever leaves git.

---

## Architecture & Tech Stack

This stack is designed to be a comprehensive, self-hosted ecosystem.

### Core Stack
*   **OS & Deployment:** `NixOS` (Unstable) + `Nix Flakes`
*   **Provisioning:** `Terraform` + `Terraform Cloud`
*   **Secret Management:** `Agenix` (Age-encrypted secrets stored in Git)
*   **CI/CD:** `GitHub Actions`

### Hosted Services
*   **Networking:** WireGuard VPN + NFTables (Masquerading)
*   **Reverse Proxy:** Nginx (ACME/Let's Encrypt)
*   **DNS Filtering:** AdGuard Home
*   **Dashboard:** Homepage
*   **Password Management:** Vaultwarden

---

## Usage & Deployment

The entire lifecycle is managed via `just` recipes, simplifying complex commands into standard verbs.

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

# 2. Install NixOS on a fresh server (Nix-Anywhere)
just install

# 3. Deploy updates to existing server
just deploy
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
<p align="center">
  <em>Aloïs Vincent - Software Engineering Student</em>
</p>
