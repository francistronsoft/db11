#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$ROOT_DIR/SHA256SUMS" ]; then
  echo "SHA256SUMS nao encontrado em $ROOT_DIR" >&2
  exit 2
fi

cd "$ROOT_DIR"
sha256sum --check SHA256SUMS
