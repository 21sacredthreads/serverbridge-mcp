#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
for f in .env config/servers.toml .runtime/ssh/id_ed25519 .runtime/ssh/id_ed25519.pub .runtime/ssh/known_hosts; do
  if [[ ! -s "$f" ]]; then
    # Once ./start.sh transfers SSH files to UID 1000, host operator may
    # need sudo to stat files in the non-readable key directory.
    if [[ "$f" == .runtime/ssh/* || "$f" == config/servers.toml ]] && command -v sudo >/dev/null 2>&1; then
      sudo test -s "$f" || { printf 'Missing or empty: %s\n' "$f" >&2; exit 1; }
    else
      printf 'Missing or empty: %s\n' "$f" >&2
      exit 1
    fi
  fi
done
docker compose config --quiet || { echo 'Compose validation failed' >&2; exit 1; }
echo 'Local configuration checks passed.'
echo 'This does not verify DNS, HTTPS, SSH authorization, or end-to-end MCP connectivity.'
