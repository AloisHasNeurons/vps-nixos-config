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
  <a href="#-the-solution"><strong>The Solution</strong></a>
  ·
  <a href="#-uptime-monitoring"><strong>Uptime Monitoring</strong></a>
  ·
  <a href="#-observability--monitoring"><strong>Observability</strong></a>
  ·
  <a href="#-gitops--automation"><strong>GitOps</strong></a>
  ·
  <a href="#-security--continuous-verification"><strong>Security</strong></a>
  ·
  <a href="#backups--disaster-recovery"><strong>Backups</strong></a>
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

## Multi-Cloud Serverless Uptime Monitoring

To guarantee high availability and instant incident response, this configuration features a custom **Stateful Multi-Cloud Uptime Monitoring** architecture. Rather than running a monitoring agent on the VPS itself (which goes silent when the host crashes), we check the host externally using serverless platforms.

*   **AWS Monitoring:** An AWS Lambda function is scheduled to run every **1 minute** via EventBridge. It tracks the previous state (`UP` or `DOWN`) in the **AWS SSM Parameter Store**.
*   **Azure Monitoring:** An Azure Function App is scheduled to run every **1 minute** via a Timer Trigger. It tracks the previous state in an **Azure Storage Account blob**.
*   **Telegram Webhook Bridge:** When either cloud detects a state transition (`UP ➔ DOWN` or `DOWN ➔ UP`), it pushes a detailed message directly to a Telegram bot.
*   **Detailed Failure Analysis:** Unlike generic CloudWatch or Azure Metric alerts, the Go code pings the host and returns the **exact connection failure reason or HTTP status code** (e.g. `connect: connection refused` or `502 Bad Gateway`) directly inside the Telegram notification.

---

## GitOps & Automated Maintenance vs Toil

A key SRE principle is eliminating toil. I implemented a **GitOps workflow** to handle system updates automatically using **Renovate Bot**.

**The Workflow:**
1.  **Scan:** Renovate scans my `flake.nix` for outdated inputs (NixOS system updates) or dependencies.
2.  **PR:** It opens a Pull Request automatically (e.g., *"Update NixOS to 25.05"*).
3.  **Verify:** GitHub Actions CI runs the full test suite (including the [security scanner](#-security--continuous-verification)).
4.  **Merge & Deploy:** Once merged, the CD pipeline automatically deploys the update.

**The Safety Net:**
*   **Atomic Updates:** If the build fails on the server, the switch is aborted. The system is never left in a broken state.
*   **Rollbacks:** Every deployment creates a new boot generation. If a service behaves incorrectly, a single command (`nixos-rebuild switch --rollback`) instantaneously reverts the entire system state.

---

## Observability & Monitoring

You can't manage what you can't measure. I integrated a full monitoring stack to ensure system health and performance visibility.

*   **Prometheus:** Scrapes metrics from system services (`node_exporter`) and applications.
*   **Grafana:** Visualizes these metrics in a unified dashboard.
*   **Homepage:** A central entry point aggregating status from all services into a unified UI.
*   **System Alerts:** Any systemd unit failure triggers an automatic Telegram webhook alert containing the last 5 log lines of the crashed service.

---

## Security & Continuous Verification

A unique feature of this project is the **Forward-Compatible Security Scanner**.

Most security setups rely on manual periodic audits. I automated this by writing a custom **NixOS Integration Test** that runs inside the GitHub Actions CI pipeline.

### The "Default Deny" Scanner
Before any code is merged, the CI system:
1.  **Boots a VM** with the exact production configuration.
2.  **Simulates an Attack**: A secondary attacker machine runs an `nmap` scan against the VM.
3.  **Audits Ports**: It acts as a whitelist. If *any* port is found open that isn't explicitly allowed (SSH/22, HTTP/80, HTTPS/443), the **pipeline fails**.

> **Result:** It is impossible for me to accidentally expose an internal service (like the `Grafana` or `Adguard` admin panel) to the public internet. The bad deploy is blocked before it ever leaves git.

---

## Architecture & Tech Stack

This stack is designed to be a comprehensive, self-hosted ecosystem.

### Core Stack
*   **OS & Deployment:** `NixOS` (Unstable) + `Nix Flakes`
*   **Provisioning:** `Terraform` + `HCP Terraform` (Terraform Cloud)
*   **Secret Management:** `Agenix` (Age-encrypted secrets stored in Git)
*   **CI/CD:** `GitHub Actions`
*   **Maintenance:** `Renovate Bot`

### Hosted Services
*   **Networking:** Tailscale Mesh VPN + NFTables (Masquerading)
*   **Reverse Proxy:** Nginx (ACME/Let's Encrypt)
*   **Observability:** Grafana + Prometheus
*   **Media & Storage:** Immich (Self-hosted Photos/Videos)
*   **DNS Filtering:** AdGuard Home
*   **Dashboard:** Homepage (Unified Service Status)
*   **Recipe manager:** Tandoor

---

## Backups & Disaster Recovery

The configuration lives in git, so the only thing that really needs backing up is **state**: photos, databases and service data under `/var/lib`.

| Layer | What | When | Retention |
|-------|------|------|-----------|
| **Postgres dumps** | `pg_dumpall` of every database (`immich`, `tandoor_recipes`) to `/var/backup/postgresql/all.sql` | 02:30 | Overwritten nightly; kept in restic |
| **Restic -> Backblaze B2** | `/var/lib` + the Postgres dumps, encrypted and deduplicated | 03:00 | 7 daily, 4 weekly, 6 monthly |
| **Hetzner backups** | Full-disk snapshot of the server | Daily | 7 |
| **NixOS generations** | The system itself (not data) | Every deploy | See `nix.gc` |

Restic skips data that is useless, regenerable, or unsafe to copy while running: the swapfile, the live `/var/lib/postgresql` files (the dumps cover them), `/var/lib/containers`, Prometheus data, and Immich's `thumbs/` and `encoded-video/`. After each prune, restic also reads a random 5% of the repository to catch corruption. See [`modules/services/backup.nix`](modules/services/backup.nix).

> **Note:** `/etc` is **not** backed up. That includes the SSH host key that agenix uses to decrypt secrets. See [full server rebuild](#4-full-server-rebuild) for what that means.

### Runbook

All commands run on the VPS as root. NixOS installs a `restic-vps-data` wrapper that already loads the B2 credentials, repository and password, so it works like plain `restic`.

#### 1. Check that backups are healthy

```bash
systemctl list-timers 'restic-backups-*' 'postgresqlBackup*'
journalctl -u postgresqlBackup -u restic-backups-vps-data --since yesterday --no-pager | tail -40

sudo restic-vps-data snapshots                         # one snapshot per night
sudo restic-vps-data ls latest /var/backup/postgresql  # all.sql must be there
sudo restic-vps-data ls latest /var/lib                # top level only, no swapfile/postgresql
sudo restic-vps-data stats --mode raw-data             # real size stored in B2
sudo restic-vps-data check --read-data-subset=5%       # integrity check
```

If either unit fails, `OnFailure=notify-failure@%n.service` sends a Telegram alert. That includes a failed `restic check`, which runs inside the backup unit. To test the alert without breaking a backup:

```bash
systemctl show restic-backups-vps-data postgresqlBackup -p OnFailure   # hook is wired
sudo systemctl start notify-failure@restic-backups-vps-data.service    # sends a test alert
```

#### 2. Restore test (non-destructive)

Do this every few months, and after big Immich or Postgres upgrades. It doesn't touch the live services.

**Databases:** load the latest dump into a throwaway Postgres on port 5433. VectorChord must be preloaded, as it is on the live server:

```bash
sudo -u postgres initdb -D /tmp/pgtest
sudo -u postgres pg_ctl -D /tmp/pgtest -l /tmp/pgtest.log \
  -o "-p 5433 -k /tmp -c shared_preload_libraries=vchord.so" start

sudo restic-vps-data dump latest /var/backup/postgresql/all.sql \
  | sudo -u postgres psql -h /tmp -p 5433 -q postgres 2>&1 | grep -i error
```

These errors are expected and harmless:
- `role "postgres" already exists`: `initdb` already created it.
- `extension "vectors" is not available`, plus related errors about `vectors.*`: leftovers of pgvecto.rs, the extension Immich used before VectorChord. Its files are no longer installed.

Any other error (especially around `CREATE TABLE` or `COPY`) means the dump is damaged. Next, compare row counts with the live database. They should match, apart from uploads made since 03:00:

```bash
for port in 5432 5433; do
  sudo -u postgres psql -h /tmp -p $port -d immich -tAc \
    "select '$port', (select count(*) from asset), (select count(*) from person), (select count(*) from smart_search);"
done

sudo -u postgres pg_ctl -D /tmp/pgtest stop && sudo rm -rf /tmp/pgtest /tmp/pgtest.log
```

**Files:** restore a folder next to the live one and compare:

```bash
sudo restic-vps-data restore latest --target /root/restore-test --include /var/lib/immich/upload
sudo diff -r /root/restore-test/var/lib/immich/upload /var/lib/immich/upload && echo IDENTICAL
sudo rm -rf /root/restore-test
```

Restore a sub-folder instead if the disk doesn't have room for a second copy.

#### 3. Real restores

**A few files** (e.g. a deleted photo or a Tandoor image): restore to a side directory, then copy the files back with the right owner:

```bash
sudo restic-vps-data snapshots                         # pick a snapshot ID, or use `latest`
sudo restic-vps-data restore <id> --target /root/restore --include /var/lib/immich/library/<path>
sudo cp -a /root/restore/var/lib/immich/library/<path> /var/lib/immich/library/<path>
sudo chown -R immich:immich /var/lib/immich/library/<path>
```

**A database rollback on the live server.** This replaces the current data, so take a fresh dump first (`sudo systemctl start postgresqlBackup`, then copy `all.sql` somewhere safe):

```bash
sudo systemctl stop immich-server immich-machine-learning tandoor-recipes
sudo restic-vps-data dump <id> /var/backup/postgresql/all.sql > /root/restore.sql

sudo -u postgres psql -c 'DROP DATABASE immich WITH (FORCE);' -c 'DROP DATABASE tandoor_recipes WITH (FORCE);'
sudo -u postgres psql -q -f /root/restore.sql postgres 2>&1 | grep -i error   # "role ... already exists" is expected

sudo systemctl start immich-server immich-machine-learning tandoor-recipes
```

`pg_dumpall` recreates the databases itself, which is why they are dropped first. Loading it into existing databases would duplicate every row.

#### 4. Full server rebuild

There are two ways to bring the server back. Neither has been rehearsed end-to-end yet.

- **Fastest: a Hetzner backup.** In the Hetzner console, rebuild the server from its most recent backup image. The host key comes back too, so agenix works unchanged. Rebuild protection must be turned off temporarily in the console, since Terraform enables it. You lose whatever changed since that backup (up to 24 h).
- **From scratch: restic.** Use this if the Hetzner project or server is gone, or to move to another provider.
  1. Provision a new server (`terraform apply`) and install NixOS on it.
  2. The new server has a **new SSH host key**, so it can't decrypt the existing secrets. On the laptop, put its key in `secrets/secrets.nix` (`ssh-keyscan <ip>`), run `agenix -r` in `secrets/`, commit, and deploy. Until this is done, agenix-backed services (Grafana, Immich, Tandoor, restic itself) fail to start.
  3. Stop the services, then restore the state: `sudo restic-vps-data restore latest --target / --include /var/lib`.
  4. Restore the databases as in the rollback above, using `latest`.
  5. Make sure ownership survived. Restic restores numeric UIDs/GIDs, and a fresh install may have assigned different ones. Run `ls -ln /var/lib`, and `chown -R` where needed (for example `immich:immich /var/lib/immich`).
  6. Start the services, then in Immich run *Administration → Jobs → Generate Thumbnails* and *Transcode Videos* (those folders aren't backed up).

---

## Usage & Deployment

Deployments to the server are fully automated via GitHub Actions when pushing to `master`.

### Local Testing
You can run the full test suite locally without touching the real server:

```bash
# Run the security integration test (boots a VM)
nix flake check

# Build a local VM for manual testing
nix run .#vps-vm
```

### Manual Infrastructure Deployment (Terraform)
If you need to provision or edit infrastructure manually:

```bash
cd terraform
nix develop ../#default --impure -c terraform init
nix develop ../#default --impure -c terraform apply
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
<p align="center">
  <em>Aloïs Vincent - Software Engineering Student</em>
</p>
