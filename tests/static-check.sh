#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT_DIR/scripts/build-kit.sh"
bash -n "$ROOT_DIR/scripts/install-kit.sh"
bash -n "$ROOT_DIR/scripts/verify-kit.sh"
bash -n "$ROOT_DIR/scripts/initialize-app-git.sh"
bash -n "$ROOT_DIR/tests/git-link.sh"

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
grep -q 'sha256sum "$(basename "$ARCHIVE")"' "$ROOT_DIR/scripts/build-kit.sh"
grep -q 'Nao execute pelo clone do Git' "$ROOT_DIR/scripts/install-kit.sh"
. "$ROOT_DIR/config/versions.env"
test "$(cat "$ROOT_DIR/VERSION")" = "$KIT_VERSION"
grep -q '72351d671d6e23be053aa08aaab4ae3e064fc418' "$ROOT_DIR/config/versions.env"
bash -n "$ROOT_DIR/scripts/prepare-offline.sh"
bash -n "$ROOT_DIR/scripts/build-iso.sh"
grep -q 'TRONSOFTOS_GIT.tar.gz' "$ROOT_DIR/scripts/build-kit.sh"
grep -q 'initialize-app-git.sh' "$ROOT_DIR/scripts/install-kit.sh"
if grep -q 'f1d25a78' "$ROOT_DIR/.github/workflows/build-kit.yml"; then
  echo "Workflow ainda sobrepoe o manifesto com commit antigo." >&2
  exit 1
fi
bash "$ROOT_DIR/tests/git-link.sh"

echo "Validacao estatica concluida."
