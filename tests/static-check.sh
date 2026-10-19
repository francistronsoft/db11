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
grep -q 'f52adb93ddb8f2a20a62685239c97a8a4f93d179' "$ROOT_DIR/config/versions.env"
bash -n "$ROOT_DIR/scripts/prepare-offline.sh"
bash -n "$ROOT_DIR/scripts/build-iso.sh"
grep -q -- '--no-download --no-remove install' "$ROOT_DIR/scripts/install-kit.sh"
grep -qx udev "$ROOT_DIR/config/debian-packages.txt"
grep -qx linux-image-amd64 "$ROOT_DIR/config/debian-packages.txt"
bash -n "$ROOT_DIR/iso/instalar"
grep -q 'chmod 755 /target/usr/local/sbin/instalar' "$ROOT_DIR/iso/preseed.cfg"
grep -q 'exec /bin/bash "$installer" --install-tronsoftos --offline' "$ROOT_DIR/iso/instalar"
grep -q '/tronsoftos/instalar' "$ROOT_DIR/scripts/build-iso.sh"
grep -q '^tasksel tasksel/first multiselect ssh-server$' "$ROOT_DIR/iso/preseed.cfg"
if grep -qE '^tasksel .*desktop|^d-i partman.*/confirm.* true' "$ROOT_DIR/iso/preseed.cfg"; then
  echo "ISO nao deve instalar desktop nem confirmar particionamento automaticamente." >&2
  exit 1
fi
grep -q 'TRONSOFTOS_GIT.tar.gz' "$ROOT_DIR/scripts/build-kit.sh"
grep -q 'initialize-app-git.sh' "$ROOT_DIR/scripts/install-kit.sh"
if grep -q 'f1d25a78' "$ROOT_DIR/.github/workflows/build-kit.yml"; then
  echo "Workflow ainda sobrepoe o manifesto com commit antigo." >&2
  exit 1
fi
bash "$ROOT_DIR/tests/git-link.sh"

echo "Validacao estatica concluida."
