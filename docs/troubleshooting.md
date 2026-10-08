# Troubleshooting

**80/443 already in use:** Do not redeploy over a running reverse proxy; consult [existing reverse proxy](existing-reverse-proxy.md).

**Domain doesn't resolve:** Verify DNS A/AAAA points to the correct host, firewall permits inbound 80/443, and no CDN interferes with certificate validation.

**Proxy starts but ChatGPT cannot complete login:** Check external URL, OAuth discovery, `/.auth/` routes, and proxy logs. Use HTTPS, not the raw backend IP.

**SSH authentication rejected:** Confirm the public key from `.runtime/ssh/id_ed25519.pub` is authorized for the selected non-root account. Check user, host and port in `config/servers.toml`.

**Host key verification fails:** Verify the host key against your provider console or independent trusted source. Do not disable strict host-key checking.

**Permission denied reading SSH key:** Container uses UID 1000. Check ownership and mode of `.runtime/ssh/` and `config/servers.toml`.

**Backend returns 401:** `PROXY_BEARER_TOKEN` on the proxy must match `SSH_MCP_HTTP_TOKEN` on the backend. This Compose file uses a single variable.

**No tools appear in client:** Verify MCP client compatibility, app connection and tool permissions.

**Shared VPS with existing Traefik/Caddy/Nginx:** The default stack expects 80/443 to be free; use staging and adapt manually.
