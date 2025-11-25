# AdGuard Home

**AdGuard Home** is a network-wide software for blocking ads and tracking.

## Configuration

The configuration is located in [`modules/adguard.nix`](../modules/adguard.nix).

*   **Port**: `3000` (Web Interface)
*   **DNS Port**: `53`
*   **Upstream DNS**: Cloudflare (`1.1.1.1`) and Google (`8.8.8.8`)

## Usage

Access the web interface at `http://<server-ip>:3000`.

### Initial Setup
1.  Navigate to the web interface.
2.  Follow the setup wizard.
3.  Create an admin account.

### Clients
To use AdGuard Home, configure your devices to use the VPS IP address (or the WireGuard IP `10.100.0.1`) as their DNS server.
