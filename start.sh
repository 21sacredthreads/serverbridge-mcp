#!/usr/bin/env bash
# First startup: verify inputs, then grant the non-root container read access.
set -Eeuo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")"

[[ -f .env ]] || { echo 'Run ./install.sh first' >&2; exit 1; }
./check.sh

# ssh-mcp runs as UID 1000 inside its container. The installer deliberately
# leaves these files owned by the host operator until key installation and
# host fingerprint verification have been completed.
if [[ "$(id -u)" != 1000 ]]; then
  if [[ "$(id -u)" == 0 ]]; then
    chown -R 1000:1000 .runtime/ssh
    chown 1000:1000 config/servers.toml
  else
    command -v sudo >/dev/null 2>&1 || {
      echo 'sudo is required to grant the container UID 1000 access to SSH files' >&2; exit 1;
    }
    sudo chown -R 1000:1000 .runtime/ssh
    sudo chown 1000:1000 config/servers.toml
  fi
fi
docker compose up -d
docker compose ps
printf '\nServerBridge containers launched. Next, test the authenticated MCP endpoint.\n'
printf 'For changes to the SSH host key after first startup, use sudo ./trust-host.sh HOST PORT.\n'
