#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT_DIR/config/versions.env"

OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
TRONSOFTOS_REPOSITORY="${TRONSOFTOS_REPOSITORY_OVERRIDE:-$TRONSOFTOS_REPOSITORY}"
TRONSOFTOS_REF="${TRONSOFTOS_REF_OVERRIDE:-$TRONSOFTOS_REF}"
STAGE_DIR="$WORK_DIR/db11-kit-${KIT_VERSION}-amd64"
ARCHIVE="$OUTPUT_DIR/db11-kit-${KIT_VERSION}-amd64.tar.gz"

required_commands=(curl docker git sha256sum tar)
for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Comando obrigatorio ausente: $command_name" >&2
    exit 2
  }
done

if [ "$(uname -m)" != "x86_64" ]; then
  echo "O gerador atual suporta apenas hosts x86_64/amd64." >&2
  exit 2
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$OUTPUT_DIR" "$STAGE_DIR/packages" "$STAGE_DIR/node" "$STAGE_DIR/app"

echo "[1/6] Baixando Node.js ${NODE_VERSION}..."
node_archive="node-v${NODE_VERSION}-linux-x64.tar.xz"
curl --fail --location --retry 5 --output "$STAGE_DIR/node/$node_archive" \
  "https://nodejs.org/dist/v${NODE_VERSION}/${node_archive}"
printf '%s  %s\n' "$NODE_SHA256" "$STAGE_DIR/node/$node_archive" | sha256sum --check

echo "[2/6] Baixando pacotes Debian 11 e Docker fixados..."
docker run --rm \
  --env DEBIAN_FRONTEND=noninteractive \
  --env "DOCKER_CE_VERSION=$DOCKER_CE_VERSION" \
  --env "DOCKER_CLI_VERSION=$DOCKER_CLI_VERSION" \
  --env "CONTAINERD_VERSION=$CONTAINERD_VERSION" \
  --env "DOCKER_BUILDX_VERSION=$DOCKER_BUILDX_VERSION" \
  --env "DOCKER_COMPOSE_VERSION=$DOCKER_COMPOSE_VERSION" \
  --volume "$ROOT_DIR/config:/kit-config:ro" \
  --volume "$STAGE_DIR/packages:/out" \
  debian:11.11-slim bash -euxo pipefail -c '
    cp /kit-config/bullseye.sources.list /etc/apt/sources.list
    cp /kit-config/99bullseye-archive /etc/apt/apt.conf.d/99bullseye-archive
    apt-get update
    xargs -r apt-get install --download-only --reinstall -y < /kit-config/debian-packages.txt
    cp /var/cache/apt/archives/*.deb /out/

    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bullseye stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install --download-only --reinstall -y \
      "docker-ce=${DOCKER_CE_VERSION}" \
      "docker-ce-cli=${DOCKER_CLI_VERSION}" \
      "containerd.io=${CONTAINERD_VERSION}" \
      "docker-buildx-plugin=${DOCKER_BUILDX_VERSION}" \
      "docker-compose-plugin=${DOCKER_COMPOSE_VERSION}"
    cp /var/cache/apt/archives/*.deb /out/
  '

echo "[3/6] Obtendo TronSoftOS em ${TRONSOFTOS_REF}..."
git clone --filter=blob:none --no-checkout "$TRONSOFTOS_REPOSITORY" "$STAGE_DIR/app/tronsoftos"
git -C "$STAGE_DIR/app/tronsoftos" fetch --depth 1 origin "$TRONSOFTOS_REF"
git -C "$STAGE_DIR/app/tronsoftos" checkout --detach FETCH_HEAD

echo "[4/6] Compilando frontend com Node.js ${NODE_VERSION}..."
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$STAGE_DIR/app/tronsoftos/frontend:/src" \
  --workdir /src \
  "node:${NODE_VERSION}-bullseye" \
  bash -euc 'npm ci --no-audit --fund=false && npm run build && rm -rf node_modules'

git -C "$STAGE_DIR/app/tronsoftos" rev-parse HEAD > "$STAGE_DIR/TRONSOFTOS_COMMIT"
rm -rf "$STAGE_DIR/app/tronsoftos/.git"

echo "[5/6] Copiando instalador e configuracoes..."
mkdir -p "$STAGE_DIR/config" "$STAGE_DIR/scripts"
cp "$ROOT_DIR/config/versions.env" "$STAGE_DIR/config/versions.env"
cp "$ROOT_DIR/config/bullseye.sources.list" "$STAGE_DIR/config/bullseye.sources.list"
cp "$ROOT_DIR/config/99bullseye-archive" "$STAGE_DIR/config/99bullseye-archive"
cp "$ROOT_DIR/scripts/install-kit.sh" "$STAGE_DIR/scripts/install-kit.sh"
cp "$ROOT_DIR/scripts/verify-kit.sh" "$STAGE_DIR/scripts/verify-kit.sh"
cp "$ROOT_DIR/docs/provocateur.md" "$STAGE_DIR/README-PROVOCATEUR.md"
chmod +x "$STAGE_DIR/scripts/"*.sh

echo "[6/6] Gerando checksums e arquivo final..."
(
  cd "$STAGE_DIR"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)
tar -C "$WORK_DIR" -czf "$ARCHIVE" "$(basename "$STAGE_DIR")"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

echo "Kit criado: $ARCHIVE"
echo "Checksum:   $ARCHIVE.sha256"
