#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT_DIR/scripts/build-kit.sh"
bash -n "$ROOT_DIR/scripts/install-kit.sh"
bash -n "$ROOT_DIR/scripts/verify-kit.sh"

if grep -RIE --exclude='static-check.sh' --exclude-dir='.git' \
  '(TUNNEL_TOKEN=eyJ|CF_TUNNEL_TOKEN=eyJ|client_secret[[:space:]]*=)' "$ROOT_DIR"; then
  echo "Possivel segredo encontrado no repositorio." >&2
  exit 1
fi

grep -q '^deb http://archive.debian.org/debian bullseye ' "$ROOT_DIR/config/bullseye.sources.list"
grep -q 'Acquire::Check-Valid-Until "false"' "$ROOT_DIR/config/99bullseye-archive"

echo "Validacao estatica concluida."
