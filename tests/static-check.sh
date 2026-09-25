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

grep -q 'snapshot.debian.org/archive/debian/20260831T000000Z/' "$ROOT_DIR/config/bullseye.sources.list"
grep -q 'snapshot.debian.org/archive/debian-security/20260901T000000Z/' "$ROOT_DIR/config/bullseye.sources.list"
if grep -qE '^deb .*http://' "$ROOT_DIR/config/bullseye.sources.list"; then
  echo "Os repositorios permanentes devem usar HTTPS." >&2
  exit 1
fi
grep -q 'Acquire::Check-Valid-Until "false"' "$ROOT_DIR/config/99bullseye-archive"

echo "Validacao estatica concluida."
