#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")"
[[ $# -ge 1 && $# -le 2 ]] || { echo 'Usage: ./trust-host.sh HOST [PORT]' >&2; exit 2; }
host="$1"; port="${2:-22}"
[[ "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.:-]*$ ]] || { echo 'Invalid host' >&2; exit 2; }
[[ "$port" =~ ^[0-9]+$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 )) || { echo 'Invalid port' >&2; exit 2; }
[[ -f .runtime/ssh/known_hosts ]] || { echo 'Run ./install.sh first' >&2; exit 1; }
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
ssh-keyscan -T 10 -p "$port" "$host" > "$tmp" 2>/dev/null || true
[[ -s "$tmp" ]] || { echo 'Could not retrieve host keys' >&2; exit 1; }
printf 'Host-key fingerprints reported by the network:\n'
ssh-keygen -lf "$tmp"
printf '\nCompare with an INDEPENDENT trusted source. ssh-keyscan does not authenticate hosts.\n'
read -rp 'Verified all fingerprints independently? Type VERIFIED: ' answer
[[ "$answer" == VERIFIED ]] || { echo 'Not saved'; exit 1; }
if [[ -w .runtime/ssh/known_hosts ]]; then
  cat "$tmp" >> .runtime/ssh/known_hosts
else
  command -v sudo >/dev/null || { echo 'Need sudo to save known_hosts' >&2; exit 1; }
  sudo sh -c 'cat "$1" >> "$2"' sh "$tmp" "$(pwd)/.runtime/ssh/known_hosts"
fi
echo 'Verified host keys saved.'
