# ServerBridge MCP

**Connect your AI assistant to your own Linux VPS over SSH — with authenticated, HTTPS-accessible MCP.**

A reusable self-hosted deployment wrapper for two excellent upstream projects:

- [blackaxgit/ssh-mcp](https://github.com/blackaxgit/ssh-mcp) (MPL-2.0): MCP-over-SSH command execution, fleet groups and SFTP.
- [sigbit/mcp-auth-proxy](https://github.com/sigbit/mcp-auth-proxy) (MIT): OAuth-compatible front door with password sign-in and automatic TLS.

This repository is **an integration and guided installer**, not a fork or a claim of authorship over either upstream project. No original production server files are included.

> [!WARNING]
> This service can execute commands on servers you authorize. Treat its public endpoint and login credentials as privileged infrastructure access. Start with a dedicated non-root SSH account, minimal sudo rights (prefer none), and a staging server. Do not publish credentials or SSH keys. Upstream dangerous-command detection is NOT a security boundary.

## Architecture

```text
AI client → HTTPS :443 → OAuth/password auth proxy
                           └→ private Docker network → ssh-mcp
                                                       └→ SSH with dedicated key → YOUR VPS
```

The SSH backend is not published on a host port. Only the authentication proxy publishes host ports; the backend can still make outbound SSH connections.

## Requirements

- Fresh Linux VPS with Docker Engine + Compose v2, Bash, OpenSSH client tools, and OpenSSL.
- A domain/subdomain pointing (DNS A/AAAA) to this VPS.
- TCP ports **80 and 443 free and reachable** for the proxy's automatic TLS certificate issuance.
- An **existing non-root SSH user** on a target Linux server, authorized to receive a dedicated public key.
- Independent trusted access to verify the target server's SSH host-key fingerprint.
- If Docker already uses 80/443 (Traefik, Nginx, Caddy, Coolify, etc.), DO NOT start this stack as-is: see [existing proxy guidance](docs/existing-reverse-proxy.md).

## Quick setup (guided)

```bash
git clone https://github.com/21sacredthreads/serverbridge-mcp.git
cd serverbridge-mcp
chmod +x install.sh trust-host.sh check.sh
./install.sh
```

The installer asks for the MCP subdomain, SSH host, non-root account and port. It creates **new credentials** in local `.env`, a dedicated SSH key pair under `.runtime/ssh/`, and a private `config/servers.toml`. It does **not** change any remote server or start Docker automatically.

1. Authorize the public key displayed by the installer in the target account's `~/.ssh/authorized_keys`. Use your provider console or an existing trusted SSH session. An alternative, if suitable, is `ssh-copy-id -i .runtime/ssh/id_ed25519.pub -p 22 deploy@YOUR-SERVER` (change user, host, and port).
2. Run `./trust-host.sh YOUR-SERVER 22`. Compare the displayed SSH fingerprint to a trusted fingerprint from your provider or an already trusted connection. Only then type `VERIFIED`.
3. Run `./check.sh` to validate local files and Compose interpolation.
4. Start the stack: `docker compose up -d`.
5. Verify: `docker compose ps`. Connect your AI app to `https://YOUR-MCP-DOMAIN/mcp` and complete password-based authentication. Your password is stored in `.env` and is never printed by the installer.

For a quick check after connection, ask the assistant to **list available servers** and **dry-run a harmless command**, then run a harmless read-only command. Different MCP clients have different setup screens.

## Security notes

- Never commit `.env`, `.runtime/`, or `config/servers.toml`; they are gitignored. Scan commits for secrets before pushing.
- Use a **dedicated least-privilege** user, never reuse a VPS root SSH key. For strong containment, use a command-restricted account or an intermediary on the target host.
- Root access and automatic sudo are NOT configured by this package.
- The SSH MCP server's dangerous-command filters are bypassable and do not replace server-side permission restrictions.
- `ssh-keyscan` must be independently verified to avoid man-in-the-middle attacks.
- Do not expose port 8000 publicly; the Compose file uses an internal-only network for that connection.
- `.env` contains secrets; protect backups, volumes, Docker access and CI logs.
- Password-only login is intended for small self-hosted setups. For shared access, configure an OAuth/OIDC identity provider and an allowlist; see the [upstream proxy docs](https://sigbit.github.io/mcp-auth-proxy/docs/oauth-setup/).
- Images default to `latest` for convenience. Pin verified releases or image digests for production, review changes, and keep dependencies updated.
- Your client may ask to approve privileged tool calls. Review commands before approval; prefer `dry_run`.

## Commands

```bash
./check.sh                 # Validate local config after key + host enrollment
docker compose up -d        # Start on clean VPS
docker compose ps           # Show service status
docker compose logs --tail=100 auth-proxy   # Review proxy issues
docker compose logs --tail=100 ssh-mcp      # Review backend issues
docker compose down         # Stop (preserves volumes)
```

## Supported capabilities

The upstream SSH MCP image provides six tools: execute on one server, execute on a group, upload/download via SFTP, list servers, and list groups. Availability depends on client and configuration.

## License and credits

The original configuration, scripts and documentation in this repository are MIT-licensed; see [LICENSE](LICENSE). The upstream images are separately licensed, maintained and distributed by their respective authors: [ssh-mcp (MPL-2.0)](https://github.com/blackaxgit/ssh-mcp) and [mcp-auth-proxy (MIT)](https://github.com/sigbit/mcp-auth-proxy). They are referenced as external images and are not vendored here.

## Project status

**Initial integration / testing release.** Static checks do not constitute an end-to-end deployment test. The packaged installer must be validated on a disposable clean VPS before production or public release. Issues and PRs welcome after the first verified installation.