# New Machine Setup Guide

How to get this project fully working on a fresh OS install after cloning the repo.

---

## Prerequisites

| Tool | Purpose | Install Guide |
|---|---|---|
| **Nix** (with flakes) | Package manager & build system | [nixos.org/download](https://nixos.org/download/) |
| **Git** | Clone the repo | Comes with most distros |

> [!TIP]
> Once Nix is installed, all other tools (`just`, `agenix`, `terraform`, `openssh`) are provided automatically by the dev shell — just run `nix develop` from the repo root.

---

## Step 1 — Restore SSH Keys

This is the **most critical step**. SSH keys are used for:
- Connecting to the VPS via SSH
- Decrypting Agenix secrets (`.age` files)
- Authenticating with Terraform Cloud

### If You Backed Up Your Keys

Copy your existing `id_ed25519` (private) and `id_ed25519.pub` (public) keys to `~/.ssh/`:

```bash
cp /backup/location/id_ed25519 ~/.ssh/
cp /backup/location/id_ed25519.pub ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

Verify your key matches one of the keys listed in [`secrets/secrets.nix`](../secrets/secrets.nix):
```bash
cat ~/.ssh/id_ed25519.pub
# Should match one of the keys in secrets.nix
```

### If You Lost Your Keys (New Keypair)

Generate a new ed25519 keypair:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Then update the following files with your new public key:

1. **`secrets/secrets.nix`** — Replace the old public key with your new one so Agenix knows you're an authorized recipient.
2. **`configuration.nix`** — Update `users.users.alois.openssh.authorizedKeys.keys` so the VPS accepts your new key.
3. **Re-encrypt all secrets** (requires access from a machine that still has an old authorized key):
   ```bash
   nix develop  # Enter dev shell for agenix
   agenix -r    # Re-encrypt all .age files for the updated recipient list
   ```
4. Deploy the updated config to the VPS: `just deploy`

> [!CAUTION]
> If **all** authorized keys are lost and no machine can decrypt the `.age` files, you will need to regenerate every secret from scratch (WireGuard server key, Homepage env, Immich env, Grafana secret key). See *Step 5* for WireGuard key regeneration.

---

## Step 2 — Clone the Repo & Enter Dev Shell

```bash
git clone git@github.com:AloisHasNeurons/vps-nixos-config.git
cd vps-nixos-config
nix develop
```

The dev shell provides: `just`, `agenix`, `terraform`, `openssh`.

Verify you can decrypt secrets:

```bash
cd secrets
agenix -d wireguard-private-key.age > /dev/null && echo "✅ Decryption works"
```

If this fails, your SSH key is not in the recipient list — go back to Step 1.

---

## Step 3 — Recreate the `.env` File

The Hetzner Cloud API token is gitignored. Create it from the example:

```bash
cp .env.example .env
```

Edit `.env` and paste your Hetzner API token (get one from [Hetzner Console → Security → API Tokens](https://console.hetzner.cloud/)):

```bash
export TF_VAR_hcloud_token="your-token-here"
```

---

## Step 4 — Set Up Terraform

Terraform state is stored remotely in **Terraform Cloud** (org: `AloisHasNeurons-Personal`, workspace: `vps-nixos`).

```bash
# Authenticate with Terraform Cloud
terraform login

# Initialize (pulls remote state)
cd terraform
terraform init
cd ..
```

You can now use `just provision` and `just deploy`.

---

## Step 5 — Restore WireGuard VPN Client

The `clients/` directory is entirely gitignored — after cloning, it will be empty.

### If You Backed Up Client Keys

Restore `laptop.key` (and optionally `phone.key`) into `clients/`, then regenerate the configs:

```bash
just wg-clients
```

This reads `secrets/wireguard-server.pub` (tracked in git) and your client private keys to produce `laptop.conf` and `phone.conf`.

Then import the config:

```bash
# Option A: wg-quick
sudo cp clients/laptop.conf /etc/wireguard/wg0.conf
sudo wg-quick up wg0

# Option B: NetworkManager (GNOME)
nmcli connection import type wireguard file clients/laptop.conf
```

### If You Lost Client Keys (New Client Keypair)

1. Generate a new client keypair:
   ```bash
   wg genkey | tee clients/laptop.key | wg pubkey > clients/laptop.pub
   ```

2. Update `modules/wireguard.nix` — replace the old `publicKey` for the laptop peer with the contents of `clients/laptop.pub`.

3. Regenerate the client config:
   ```bash
   just wg-clients
   ```

4. Deploy so the server knows the new client public key:
   ```bash
   just deploy
   ```

5. Import the config on your machine (see above).

### If You Need to Rotate the Server Key Too

```bash
just wg-server-key   # Generates new server keypair, encrypts private key
just wg-clients      # Regenerates all client configs with the new server pubkey
just deploy          # Deploys to the VPS
```

> [!WARNING]
> Rotating the server key invalidates **all** existing client configs (laptop, phone, desktop). You'll need to re-import configs on every device.

---

## Summary Checklist

| # | Step | Key Files |
|---|---|---|
| 1 | Restore/generate SSH keys | `~/.ssh/id_ed25519`, `secrets/secrets.nix`, `configuration.nix` |
| 2 | Clone repo + `nix develop` | `flake.nix` |
| 3 | Recreate `.env` | `.env.example` → `.env` |
| 4 | `terraform login` + `init` | `terraform/` |
| 5 | Restore/generate WireGuard client keys | `clients/`, `modules/wireguard.nix` |

---

## What You Don't Need to Worry About

- **GitHub Actions secrets** (`SSH_PRIVATE_KEY`, `HCLOUD_TOKEN`, `TF_API_TOKEN`) — stored on GitHub, unaffected by a local reinstall.
- **VPS host key** — already in `secrets/secrets.nix` and doesn't change unless you destroy and recreate the server.
- **Server-side config** — fully declarative; it deploys from the repo via `just deploy` or the CD pipeline.
