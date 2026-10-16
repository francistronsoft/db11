#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$ROOT_DIR/SHA256SUMS" ]; then
  echo "SHA256SUMS nao encontrado em $ROOT_DIR" >&2
  exit 2
fi

cd "$ROOT_DIR"
sha256sum --check SHA256SUMS

for required_file in TRONSOFTOS_COMMIT TRONSOFTOS_GIT.tar.gz scripts/initialize-app-git.sh; do
  [ -f "$required_file" ] || { echo "Bundle incompleto: $required_file ausente." >&2; exit 2; }
done
grep -qE '^[0-9a-f]{40}$' TRONSOFTOS_COMMIT
tar -tzf TRONSOFTOS_GIT.tar.gz > /dev/null
