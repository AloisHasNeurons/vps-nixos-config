# Nginx

**Nginx** is used as a reverse proxy to handle incoming web traffic and route it to the appropriate services.

## Configuration

The configuration is located in [`modules/nginx.nix`](../modules/nginx.nix).

*   **Ports**: `80` (HTTP), `443` (HTTPS)

## Usage

Nginx is configured to automatically handle proxying. Currently, it serves a default "Hello from Nginx!" page on `localhost`.
Future services will be exposed via subdomains or paths managed by Nginx.
