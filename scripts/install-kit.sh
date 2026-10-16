#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; echo "Instalacao do kit falhou na linha $LINENO (exit $rc)." >&2; exit "$rc"' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT_DIR/config/versions.env"

INSTALL_TRONSOFTOS=false
OFFLINE=false
for argument in "$@"; do
  case "$argument" in
    --install-tronsoftos) INSTALL_TRONSOFTOS=true ;;
    --prepare-only) : ;;
    --offline) OFFLINE=true ;;
    *) echo "Uso: sudo $0 [--prepare-only|--install-tronsoftos] [--offline]" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo $0" >&2
  exit 77
fi

if [ "$(dpkg --print-architecture)" != "$DEBIAN_ARCH" ]; then
  echo "Arquitetura incompativel; esperado $DEBIAN_ARCH." >&2
  exit 2
fi

. /etc/os-release
if [ "${ID:-}" != "debian" ] || [ "${VERSION_ID:-}" != "11" ]; then
  echo "Este kit exige Debian 11; detectado ${PRETTY_NAME:-desconhecido}." >&2
  exit 2
fi

if [ ! -f "$ROOT_DIR/SHA256SUMS" ]; then
  echo "Bundle incompleto: SHA256SUMS nao encontrado em $ROOT_DIR." >&2
  echo "Nao execute pelo clone do Git. Baixe e extraia o artefato db11-kit-amd64 do GitHub Actions." >&2
  exit 2
fi

"$ROOT_DIR/scripts/verify-kit.sh"

stamp="$(date +%Y%m%d%H%M%S)"
backup_dir="/root/db11-kit-backup-$stamp"
mkdir -p "$backup_dir"
cp -a /etc/apt/sources.list "$backup_dir/sources.list" 2>/dev/null || true
cp -a /etc/apt/sources.list.d "$backup_dir/sources.list.d" 2>/dev/null || true

ca_package=("$ROOT_DIR"/packages/ca-certificates_*.deb)
openssl_package=("$ROOT_DIR"/packages/openssl_*.deb)
if [ ! -e "${ca_package[0]}" ] || [ ! -e "${openssl_package[0]}" ]; then
  echo "Pacotes locais para inicializar os certificados HTTPS nao encontrados." >&2
  exit 2
fi

export DEBIAN_FRONTEND=noninteractive
if [ "$OFFLINE" != true ]; then
  dpkg -i "${openssl_package[@]}" "${ca_package[@]}"
  update-ca-certificates
fi

install -m 0644 "$ROOT_DIR/config/bullseye.sources.list" /etc/apt/sources.list
install -m 0644 "$ROOT_DIR/config/99bullseye-archive" /etc/apt/apt.conf.d/99bullseye-archive
find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) -exec mv {} "$backup_dir/" \;

if [ "$OFFLINE" = true ]; then
  [ -f "$ROOT_DIR/packages/Packages.gz" ] && [ -f "$ROOT_DIR/images/tronfire-images.tar.gz" ] || {
    echo "Este bundle nao contem o repositorio e as imagens offline." >&2; exit 2;
  }
  [[ "$ROOT_DIR" != *[[:space:]]* ]] || { echo "Extraia o kit offline em um caminho sem espacos." >&2; exit 2; }
  mkdir -p /var/lib/tronsoftos-offline "$ROOT_DIR/packages/partial"
  export TRONSOFTOS_OFFLINE_APT_LIST=/var/lib/tronsoftos-offline/sources.list
  export TRONSOFTOS_OFFLINE_PACKAGES="$ROOT_DIR/packages"
  printf 'deb [trusted=yes] file:%s ./\n' "$ROOT_DIR/packages" > "$TRONSOFTOS_OFFLINE_APT_LIST"
  . "$ROOT_DIR/app/tronsoftos/scripts/offline-support.sh"
  offline_apt_get update
  mapfile -t package_names < <(for package in "$ROOT_DIR"/packages/*.deb; do dpkg-deb -f "$package" Package; done | sort -u)
  offline_apt_get --no-download --no-remove install -y "${package_names[@]}"
else
  apt-get update
  if compgen -G "$ROOT_DIR/packages/*.deb" >/dev/null; then
    dpkg -i "$ROOT_DIR"/packages/*.deb || true
    apt-get --fix-broken install -y
  fi
fi

node_archive="$ROOT_DIR/node/node-v${NODE_VERSION}-linux-x64.tar.xz"
printf '%s  %s\n' "$NODE_SHA256" "$node_archive" | sha256sum --check
node_target="/opt/node-v${NODE_VERSION}-linux-x64"
rm -rf "$node_target"
tar -xJf "$node_archive" -C /opt
ln -sfn "$node_target/bin/node" /usr/local/bin/node
ln -sfn "$node_target/bin/npm" /usr/local/bin/npm
ln -sfn "$node_target/bin/npx" /usr/local/bin/npx

systemctl enable --now docker
if [ "$OFFLINE" = true ]; then
  gzip -dc "$ROOT_DIR/images/tronfire-images.tar.gz" | docker load
  export TRONSOFTOS_OFFLINE=true
  export FIREBIRD_PACKAGE_SHA256="$(awk '$2 ~ /FirebirdCS-/ {print $1}' "$ROOT_DIR/FIREBIRD_ASSETS.sha256")"
  export FIREBIRD_TEMPLATE_SHA256="$(awk '$2 ~ /template.fdb/ {print $1}' "$ROOT_DIR/FIREBIRD_ASSETS.sha256")"
fi

echo "Debian: $(cat /etc/debian_version)"
echo "Node:   $(node --version)"
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"

if [ "$INSTALL_TRONSOFTOS" != "true" ]; then
  echo "Pre-requisitos instalados. Para instalar o TronSoftOS:"
  echo "  sudo $0 --install-tronsoftos"
  exit 0
fi

commit="$(cat "$ROOT_DIR/TRONSOFTOS_COMMIT")"
if [ -e /opt/tronsoftos/.git ] || [ -L /opt/tronsoftos/.git ]; then
  bash "$ROOT_DIR/scripts/initialize-app-git.sh" "$ROOT_DIR/TRONSOFTOS_GIT.tar.gz" \
    /opt/tronsoftos "$commit" "$TRONSOFTOS_REPOSITORY"
fi
TRONSOFTOS_APP_DIR=/opt/tronsoftos \
TRONSOFTOS_SKIP_FRONTEND_BUILD=true \
TRONSOFTOS_GIT_COMMIT="$commit" \
TRONSOFTOS_GIT_BRANCH="main" \
  bash "$ROOT_DIR/app/tronsoftos/install.sh"

bash "$ROOT_DIR/scripts/initialize-app-git.sh" "$ROOT_DIR/TRONSOFTOS_GIT.tar.gz" \
  /opt/tronsoftos "$commit" "$TRONSOFTOS_REPOSITORY"
echo "Kit $KIT_VERSION concluido; TronSoftOS com atualizacao Git habilitada."
