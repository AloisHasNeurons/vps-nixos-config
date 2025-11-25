# Vaultwarden

**Vaultwarden** is an unofficial Bitwarden compatible server written in Rust. It is ideal for self-hosted password management.

## Configuration

The configuration is located in [`modules/vaultwarden.nix`](../modules/vaultwarden.nix).

*   **Port**: `8000`

## Usage

Access the web vault at `http://<server-ip>:8000`.

### Account Creation
1.  Navigate to the web vault.
2.  Click "Create Account".
3.  **Important**: Since this is a self-hosted instance, you cannot use your existing Bitwarden.com account. You must create a new one.

### Clients
You can use the official Bitwarden apps (Mobile, Desktop, Browser Extension).
1.  Open the app settings.
2.  Configure the **Self-hosted Environment** URL to `http://<server-ip>:8000`.
3.  Log in with your new account.
