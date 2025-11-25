# WireGuard

**WireGuard** is a fast, modern, secure VPN tunnel. It is used to securely access the VPS and its internal services.

## Configuration

The configuration is located in [`modules/wireguard.nix`](../modules/wireguard.nix).

*   **Port**: `51820` (UDP)
*   **Interface**: `wg0`
*   **Server IP**: `10.100.0.1/24`

## Secrets
The private key is managed by **Agenix** and stored in `secrets/wireguard-private-key.age`.

## Client Configuration
To connect a client (e.g., your phone or laptop), you need to:
1.  Generate a keypair for the client.
2.  Add the client's public key to the `peers` list in `modules/wireguard.nix`.
3.  Configure the client with the server's public key and endpoint IP.
