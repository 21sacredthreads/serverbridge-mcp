#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
for f in .env config/servers.toml .runtime/ssh/id_ed25519 .runtime/ssh/id_ed25519.pub .runtime/ssh/known_hosts; do
  [[ -s "$f" ]] || { printf 'Missing or empty: %s\n' "$f" >&2; exit 1; }
done
docker compose config --quiet || { echo 'Compose validation failed' >&2; exit 1; }
echo 'Static configuration checks passed.'
echo 'This does not verify DNS, port availability, SSH authorization, or end-to-end MCP connectivity.'
