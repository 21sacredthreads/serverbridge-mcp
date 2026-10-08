# ServerBridge MCP — User Guide

> **Status:** Early integration / testing release. This guide documents the repository as it currently exists. **A full install on a clean VPS has not yet been independently verified.** First use a disposable or staging server, not critical production infrastructure.

## 1. What is ServerBridge MCP?

ServerBridge MCP helps an AI assistant interact with Linux servers you administer using ordinary language. Instead of manually opening an SSH terminal for every task, you can ask a compatible MCP client to list configured servers, inspect service status, or run an approved command.

**Example:** “On my staging server, show the hostname, uptime, and available disk space. Don't change anything.”

The request takes this path:

~~~text
Your MCP-enabled AI client
     |
     | HTTPS /mcp, login required
     v
ServerBridge authentication proxy (public :443)
     |
     | Private Docker network + backend bearer token
     v
ssh-mcp backend (not directly published)
     |
     | Verified SSH host key + dedicated SSH key
     v
Your chosen Linux server (non-root user)
~~~

**Important distinction:** ServerBridge packages and configures two existing projects rather than implementing its own SSH engine: [blackaxgit/ssh-mcp](https://github.com/blackaxgit/ssh-mcp) and [sigbit/mcp-auth-proxy](https://github.com/sigbit/mcp-auth-proxy). Both have their own licenses and maintenance schedules.

### What it can do

| Tool | Purpose | Risk level |
| --- | --- | --- |
| `list_servers` | Show available server aliases | Read-only |
| `list_groups` | Show configured server groups | Read-only |
| `execute` | Run a command on one server | Depends on command |
| `execute_on_group` | Run a command across a group | Potentially high |
| `upload_file` | Transfer a file using SFTP | Changes remote files |
| `download_file` | Retrieve a file using SFTP | May expose sensitive data |

The underlying SFTP tools require a configured local **transfer root in the MCP container**; they do **not** automatically access files on your laptop. The default installer does not set up a host-side shared transfer directory, so treat SFTP as an **advanced feature** requiring additional configuration and validation.

## 2. Before you start

This initial installer is designed for a **clean, Linux-based VPS** hosting ServerBridge. The VPS running ServerBridge can also be the SSH target, but only when that account and SSH configuration are explicitly authorized.

You need:

1. A Linux VPS you control with a terminal and administrator access for installing Docker.
2. [Docker Engine](https://docs.docker.com/engine/install/) and the [Docker Compose plugin](https://docs.docker.com/compose/install/linux/), plus Git, Bash, OpenSSH client utilities, and OpenSSL.
3. A domain or subdomain, for example `mcp.example.com`, pointing to the **ServerBridge host**, not necessarily the SSH target.
4. Public inbound TCP **80 and 443** available for HTTPS/certificate issuance, and outbound SSH access from the ServerBridge host to your target.
5. A dedicated, **non-root** user on the target server (for example `deploy`), authorized to accept an SSH public key.
6. A trusted source for the target's SSH host-key fingerprint (for example your provider's console).

**Not suitable as-is:** a VPS already running Nginx, Caddy, Traefik, Coolify, or another service on ports 80/443. Read [Existing reverse proxy](existing-reverse-proxy.md) instead of starting the default Compose stack.

### Verify the prerequisites

On the clean VPS:

~~~bash
docker --version
docker compose version
git --version
ssh -V
openssl version
~~~

If a command is missing, install it using your distribution's official instructions. The installer **does not install Docker** or change your firewall.

Set a DNS A record such as:

| DNS setting | Example |
| --- | --- |
| Type | A |
| Name | mcp |
| Value | Your **ServerBridge VPS** public IPv4 |
| Resulting hostname | mcp.example.com |

If using a DNS provider with a reverse-proxy/CDN feature, verify that its proxy settings do not interfere with certificate issuance. DNS propagation can take time.

## 3. Download and run the guided installer

Run the following **on the clean ServerBridge VPS**, not inside ChatGPT:

~~~bash
git clone https://github.com/21sacredthreads/serverbridge-mcp.git
cd serverbridge-mcp
chmod +x install.sh trust-host.sh check.sh start.sh
./install.sh
~~~

The installer asks for:

| Question | Example | Explanation |
| --- | --- | --- |
| Public MCP hostname | `mcp.example.com` | Where your AI client connects |
| Server alias | `staging-1` | Friendly name for the SSH target |
| Target SSH hostname/IP | `203.0.113.10` | Address the MCP backend uses to reach the server |
| Target SSH username | `deploy` | A non-root account |
| Target SSH port | `22` | Your server's SSH port |

The example IP `203.0.113.10` is documentation-only; substitute your real server address.

When you confirm, the script creates:
- `.env` — unique proxy password, bearer token, and domain.
- `.runtime/ssh/id_ed25519` and `.pub` — a new dedicated SSH key pair.
- `.runtime/ssh/known_hosts` — initially empty until host verification.
- `config/servers.toml` — private target/server inventory.

**It does not:** start containers, configure DNS, change the remote server, install a public key for you, or grant the target user sudo permissions.

The private key, tokens, and real inventory must **never** be committed to GitHub.

## 4. Authorize the SSH public key

On the target server, use an already trusted SSH connection or your hosting provider console. Add the public key printed by the installer to the **target user's** `~/.ssh/authorized_keys`.

If you already have SSH access from the ServerBridge host and `ssh-copy-id` is installed, one option is:

~~~bash
ssh-copy-id -i .runtime/ssh/id_ed25519.pub -p 22 deploy@203.0.113.10
~~~

Replace the username, address, and port. **Only the public key** (ending `.pub`) belongs in `authorized_keys` — never the private key.

Use your target's SSH authorization restrictions and least-privilege controls as needed. The public key is readable; the private key should remain protected on the ServerBridge host.

## 5. Verify the target server's identity

From the repository directory on the ServerBridge host:

~~~bash
./trust-host.sh 203.0.113.10 22
~~~

The script shows one or more SSH host-key fingerprints retrieved from the network. **Compare these fingerprints against an independent trusted source** (provider console, or another already authenticated management channel). Type `VERIFIED` **only after comparing**. A fingerprint obtained via `ssh-keyscan` alone is *not* proof of identity.

This writes the verified keys to the dedicated `known_hosts` file, while leaving SSH host verification enabled.

## 6. Validate and start the stack

~~~bash
./check.sh
./start.sh
docker compose ps
~~~

`./check.sh` verifies that configuration files exist and Docker Compose parses them. It is **not** an end-to-end connectivity or security test.

If a container stops or fails:

~~~bash
docker compose logs --tail=100 auth-proxy
docker compose logs --tail=100 ssh-mcp
~~~

Before sharing output publicly, redact tokens, passwords, public addresses, internal hostnames, and other sensitive information.

The expected public MCP URL is:

~~~text
https://mcp.example.com/mcp
~~~

Do **not** connect your AI client to TCP port 8000. That backend endpoint must remain private. A URL entered in a normal web browser may not display a webpage because MCP is a machine-to-machine protocol.

## 7. Connect to an MCP-compatible AI client

### ChatGPT

Actual menus and access vary by account, workspace policy, and platform. If your ChatGPT account allows **custom MCP apps**:

1. On ChatGPT web, open **Settings → Apps** (or the workspace's app settings).
2. Enable developer mode if the account/workspace permits it.
3. Choose **Create** a custom app/MCP connector.
4. Enter a recognizable name such as `ServerBridge MCP`.
5. Enter the HTTPS URL, such as `https://mcp.example.com/mcp`.
6. Choose the available authentication flow and complete the proxy's password-based sign-in when prompted.
7. Run **Scan tools** (or the corresponding discover/test action) and check that server listing and command execution tools appear.
8. Select the app in a new conversation, then run a **read-only** test first.

For the latest menus, permissions, and limitations, consult [OpenAI's developer mode / MCP apps guide](https://help.openai.com/en/articles/12584461-developer-mode-and-full-mcp-connectors-in-chatgpt). Not all accounts or workspaces can enable remote command-execution tools. A successful connection to the MCP URL does not guarantee that every tool is permitted by your client.

### Other MCP clients

Choose a client that supports **remote MCP over HTTPS** with the required OAuth-compatible authorization flow. Add the same `https://mcp.example.com/mcp` endpoint and follow that client's authorization steps. Configuration is client-specific; desktop clients that only support local/stdio MCP may require a separate adapter.

## 8. Your first five example prompts

After the client discovers the tools and you have selected the connection, try these **in order**, on a staging target:

1. “List the servers available through ServerBridge MCP. Do not run any commands yet.”
2. “Show which server groups are configured.”
3. “Preview, using dry-run only, `whoami && hostname && uptime` on `staging-1`.”
4. “Run `whoami && hostname && uptime` on `staging-1`. Do not alter any files or services.”
5. “On `staging-1`, show disk usage using `df -h` and summarize any volumes that look nearly full. Read-only.”

For a service status, another **read-only** example is:

~~~text
On staging-1, show the status of the nginx service.
Do not restart, reinstall, or modify anything.
~~~

**Operations to treat as high risk:** `rm`, system/package upgrades, `systemctl restart`, database migration, deployment commands, commands with `sudo`, and any tool invocation affecting a *group* of servers. Require human review before running them. Client confirmation UI is **not** a substitute for SSH permissions.

## 9. Day-to-day operations

Run these on the machine hosting ServerBridge, inside its repository directory:

| Task | Command |
| --- | --- |
| Show containers | `docker compose ps` |
| Start for first time | `./start.sh` |
| Proxy logs | `docker compose logs --tail=100 auth-proxy` |
| SSH backend logs | `docker compose logs --tail=100 ssh-mcp` |
| Stop containers | `docker compose down` |
| Check configuration | `./check.sh` |

**Do not use `docker compose down -v` casually:** the `-v` option removes named volumes including proxy state.

To add more target servers, edit the local, gitignored `config/servers.toml` based on [the upstream server inventory format](https://github.com/blackaxgit/ssh-mcp/blob/main/config/servers.example.toml). Each additional target needs its own appropriately authorized key/host-verification configuration; follow the upstream documentation and retest before exposing it. The initial installer only configures **one** target.

To upgrade upstream Docker images, review release notes and image digests first, then test in staging. This project currently defaults to `latest`; production installations should pin reviewed versions or digests.

## 10. Troubleshooting

| Symptom | Likely next check |
| --- | --- |
| Port 80/443 already in use | Stop; use [existing reverse proxy guide](existing-reverse-proxy.md) |
| Certificate/HTTPS errors | DNS, firewall, TLS issuance, proxy logs |
| ChatGPT cannot connect | Endpoint URL, proxy auth, account/workspace MCP permissions |
| SSH permission denied | Correct user, host, key in `authorized_keys`, backend logs |
| SSH host key mismatch | Verify against your provider's trusted fingerprint; do not disable checks |
| Backend token error/401 | Check private local `.env` and proxy/backend configuration match |
| No server names appear | Check private `config/servers.toml` and service logs |
| SFTP transfer fails | Review upstream transfer-root security requirements and path restrictions |
| `./check.sh` fails | Check missing files and Docker Compose availability |

See the fuller [troubleshooting guide](troubleshooting.md). **Never paste the full `.env`, SSH private key, or raw auth logs into an issue.**

## 11. Security and responsible use

ServerBridge can run real operating-system commands on SSH targets. An assistant may misinterpret instructions or receive malicious text from a webpage, log, or file. Protect against mistakes and prompt injection:

- Run with a dedicated non-root target account and **least privilege**, preferably no passwordless sudo.
- Start in staging. Confirm the exact server name before write operations.
- Use narrow SSH permissions and network controls. Treat command-detection filters as advisory, not a secure sandbox.
- Keep `.env`, `.runtime/`, `config/servers.toml`, backups, and Docker access private.
- Verify host fingerprints independently. Use HTTPS and strong, unique credentials.
- For shared access, use an approved identity provider, access restrictions, and audited workflows.
- Do not grant the assistant access to credentials, production backups, private customer data, or unrelated services.
- Rotate credentials if exposed and review the [project security policy](../SECURITY.md).

## 12. Before declaring an installation successful

- [ ] DNS resolves to the intended ServerBridge host.
- [ ] Docker services are healthy and proxy HTTPS is valid.
- [ ] Direct access to raw backend port 8000 is **not** public.
- [ ] An allowed client can sign in and discover the permitted tools.
- [ ] `list_servers` shows only intended SSH targets.
- [ ] `execute` dry-run succeeds on staging.
- [ ] A harmless read-only command succeeds over verified SSH.
- [ ] Unauthorized access is rejected and secrets do not appear in logs.

**The public repository is an early testing release.** This checklist is for users to validate their own setup; it does not claim that the repository has already passed a clean-VPS end-to-end test.

---

**Further reading:** [Quick start](../README.md) · [Troubleshooting](troubleshooting.md) · [Reverse proxy setups](existing-reverse-proxy.md) · [Security](../SECURITY.md) · [SSH backend](https://github.com/blackaxgit/ssh-mcp) · [Auth proxy](https://sigbit.github.io/mcp-auth-proxy/)
