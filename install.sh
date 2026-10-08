#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")"
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }
for cmd in docker openssl ssh-keygen ssh-keyscan; do need "$cmd"; done
docker compose version >/dev/null 2>&1 || fail 'Docker Compose v2 is required.'
[[ ! -e .env && ! -e config/servers.toml ]] || fail 'Existing installation detected; refusing to overwrite.'
[[ -t 0 ]] || fail 'Run interactively in a terminal.'
printf '\nServerBridge MCP guided setup (clean VPS, ports 80/443 free)\n'
read -rp 'Public MCP hostname (e.g. mcp.example.com): ' domain
[[ "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ && "$domain" == *.* && "$domain" != *..* ]] || fail 'Invalid hostname.'
read -rp 'Server alias (e.g. staging-1): ' alias
[[ "$alias" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]] || fail 'Invalid server alias.'
read -rp 'Target SSH hostname/IP: ' host
[[ "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.:-]*$ ]] || fail 'Invalid target host.'
read -rp 'Target non-root SSH username: ' user
[[ "$user" =~ ^[a-z_][a-z0-9_-]*$ && "$user" != root ]] || fail 'Use a valid non-root username.'
read -rp 'Target SSH port [22]: ' port
port="${port:-22}"
[[ "$port" =~ ^[0-9]+$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 )) || fail 'Invalid SSH port.'
printf 'Point DNS for %s at this machine; ensure ports 80/443 are free.\n' "$domain"
read -rp 'Generate new SSH key and credentials? [y/N] ' answer
[[ "${answer,,}" == y || "${answer,,}" == yes ]] || { echo 'Cancelled'; exit 0; }
mkdir -p .runtime/ssh config
chmod 700 .runtime .runtime/ssh
ssh-keygen -q -t ed25519 -f .runtime/ssh/id_ed25519 -N '' -C serverbridge-mcp
touch .runtime/ssh/known_hosts
chmod 600 .runtime/ssh/id_ed25519 .runtime/ssh/known_hosts
chmod 644 .runtime/ssh/id_ed25519.pub
password="$(openssl rand -hex 24)"
token="$(openssl rand -hex 32)"
cat > .env <<EOF
MCP_DOMAIN=$domain
ACCESS_PASSWORD=$password
SSH_MCP_HTTP_TOKEN=$token
SSH_MCP_IMAGE=ghcr.io/blackaxgit/ssh-mcp:latest
AUTH_PROXY_IMAGE=ghcr.io/sigbit/mcp-auth-proxy:latest
EOF
chmod 600 .env
cat > config/servers.toml <<EOF
[settings]
command_timeout = 30
max_output_bytes = 51200
max_command_bytes = 65536
known_hosts = true
max_parallel_hosts = 5
[groups]
production = { description = "Managed servers" }
[servers.$alias]
hostname = "$host"
port = $port
user = "$user"
identity_file = "/home/sshmcp/.ssh/id_ed25519"
groups = ["production"]
description = "Managed Linux VPS"
EOF
chmod 600 config/servers.toml
# Keep credentials owned by the installing user until the public key is copied
# and the host key verified. start.sh transfers SSH files to the container UID.
printf '\nCreated configuration; NO services started and no remote changes made.\n'
printf '1. Install the following public key for target user in ~/.ssh/authorized_keys:\n'
cat .runtime/ssh/id_ed25519.pub
printf '\n2. Independently verify and trust host fingerprint: ./trust-host.sh %s %s\n' "$host" "$port"
printf '3. Validate: ./check.sh\n4. Start safely: ./start.sh\n5. MCP URL: https://%s/mcp\n' "$domain"
printf 'Access password is in .env; never commit it.\n'
