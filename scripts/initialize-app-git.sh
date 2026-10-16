#!/usr/bin/env bash
set -euo pipefail

archive="${1:?Arquivo de metadados Git obrigatorio}"
app="${2:?Diretorio instalado obrigatorio}"
commit="${3:?Commit esperado obrigatorio}"
repository="${4:?Repositorio esperado obrigatorio}"
service_user="${5:-tronsoftos}"

[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { echo "Commit do kit invalido." >&2; exit 2; }
[ -d "$app" ] && [ ! -L "$app" ] || { echo "Diretorio da aplicacao invalido." >&2; exit 2; }
service_uid="$(id -u "$service_user")"
service_group="$(id -gn "$service_user")"

as_service() {
  if [ "$(id -u)" = "$service_uid" ]; then "$@";
  else runuser -u "$service_user" -- "$@"; fi
}

verify_repository() {
  local target="$1" head origin branch
  head="$(as_service git -C "$target" rev-parse HEAD)"
  origin="$(as_service git -C "$target" remote get-url origin)"
  branch="$(as_service git -C "$target" symbolic-ref --short HEAD)"
  [ "$head" = "$commit" ] && [ "$origin" = "$repository" ] && [ "$branch" = main ] || {
    echo "Repositorio Git divergente do kit; nada foi sobrescrito. Use a atualizacao pelo painel para uma instalacao existente." >&2
    return 1
  }
}

if [ -e "$app/.git" ] || [ -L "$app/.git" ]; then
  verify_repository "$app"
  echo "Vinculo Git existente validado e preservado."
  exit 0
fi

[ -f "$archive" ] || { echo "Metadados Git ausentes no kit." >&2; exit 2; }
temporary="$(mktemp -d "$app/.db11-git-XXXXXX")"
trap 'rm -rf -- "$temporary"' EXIT
tar --no-same-owner -xzf "$archive" -C "$temporary"
[ -d "$temporary/.git" ] && [ ! -L "$temporary/.git" ] || { echo "Metadados Git invalidos." >&2; exit 2; }
if [ "$(id -u)" = 0 ]; then chown -R "$service_user:$service_group" "$temporary"; fi
verify_repository "$temporary"
# Move somente metadados; nunca checkout/reset dos arquivos ja instalados.
[ ! -e "$app/.git" ] && [ ! -L "$app/.git" ]
mv -T -- "$temporary/.git" "$app/.git"
verify_repository "$app"
echo "Vinculo Git validado: main/origin; atualizacao pelo painel disponivel."
