# Existing reverse proxy / shared VPS

The default Compose file is intended for a **clean** VPS. It publishes TCP 80/443 for the OAuth proxy. If Traefik, Caddy, Nginx, Coolify or another platform already owns those ports, DO NOT start this stack unchanged.

Advanced approach (requires separate security testing):

1. Remove the `ports` mapping from the auth-proxy service; attach that service only to a private Docker network shared with the existing reverse proxy.
2. Set `NO_AUTO_TLS=true` on the auth proxy. Terminate TLS on the existing reverse proxy, forwarding `/mcp`, `/.well-known/`, and `/.auth/` paths to the auth proxy HTTP port 80. Preserve Host and forwarded protocol headers.
3. Ensure `ssh-mcp` is available only on the internal Docker network, with bearer authentication. Do not expose port 8000.
4. Validate OAuth discovery, redirects and callback URLs, token forwarding, Host validation, and end-to-end tool invocation before external access.

The installer deliberately does not modify existing reverse proxy configuration.
