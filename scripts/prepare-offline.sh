#!/usr/bin/env bash
set -euo pipefail
kit="${1:?Diretorio do kit obrigatorio}"
app="$kit/app/tronsoftos"
images="$kit/images"
mkdir -p "$images"
[ -f "$app/scripts/offline-support.sh" ] || { echo 'TronSoftOS empacotado nao suporta instalacao offline.' >&2; exit 2; }

export FIREBIRD_PACKAGE_URL="${FIREBIRD_PACKAGE_URL:-https://tronsoft.bitrix24.com.br/~qQVae}"
export FIREBIRD_TEMPLATE_URL="${FIREBIRD_TEMPLATE_URL:-https://tronsoft.bitrix24.com.br/~wUw0m}"
bash "$app/apps/tronfire/scripts/install-assets.sh"
(
  cd "$app/apps/tronfire/docker/firebird25"
  sha256sum FirebirdCS-2.5.9.27139-0.amd64.tar.gz template.fdb
) > "$kit/FIREBIRD_ASSETS.sha256"

# Build somente na maquina de geracao, nunca na instalacao offline.
docker build --tag tronfire-backend:latest --file "$app/apps/tronfire/backend/Dockerfile" "$app/apps/tronfire"
docker build --tag tronfire-worker:latest --file "$app/apps/tronfire/worker/Dockerfile" "$app/apps/tronfire"
docker pull postgres:16-alpine
docker pull redis:7-alpine
docker image inspect tronfire-backend:latest tronfire-worker:latest postgres:16-alpine redis:7-alpine > "$images/manifest.json"
docker save tronfire-backend:latest tronfire-worker:latest postgres:16-alpine redis:7-alpine | gzip -1 > "$images/tronfire-images.tar.gz"
(
  cd "$kit/packages"
  dpkg-scanpackages --multiversion . /dev/null > Packages
  gzip -c Packages > Packages.gz
)
printf 'core-only\n' > "$kit/OFFLINE"
