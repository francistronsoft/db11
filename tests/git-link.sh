#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
source_repo="$temporary/source"
snapshot="$temporary/snapshot"
app="$temporary/installed"
archive="$temporary/git.tar.gz"
user="$(id -un)"

git init -q "$source_repo"
git -C "$source_repo" config user.name 'Kit test'
git -C "$source_repo" config user.email 'kit-test@example.invalid'
printf 'source\n' > "$source_repo/VERSION"
git -C "$source_repo" add VERSION
git -C "$source_repo" commit -qm 'test fixture'
commit="$(git -C "$source_repo" rev-parse HEAD)"

git init -q "$snapshot"
git -C "$snapshot" remote add origin "$source_repo"
git -C "$snapshot" fetch -q --depth 1 origin "$commit"
git -C "$snapshot" checkout -q -B main FETCH_HEAD
git -C "$snapshot" config branch.main.remote origin
git -C "$snapshot" config branch.main.merge refs/heads/main
git -C "$snapshot" config core.filemode false
git -C "$snapshot" update-ref refs/remotes/origin/main HEAD
tar -C "$snapshot" -czf "$archive" .git

mkdir -p "$app/state" "$app/config"
printf 'local-settings\n' > "$app/.env"
printf 'events\n' > "$app/state/events.jsonl"
printf 'custom\n' > "$app/config/managed-apps.json"
printf 'local-source-must-not-be-reset\n' > "$app/VERSION"
before="$(find "$app" -type f -print0 | sort -z | xargs -0 sha256sum)"
bash "$ROOT_DIR/scripts/initialize-app-git.sh" "$archive" "$app" "$commit" "$source_repo" "$user"
test "$(git -C "$app" rev-parse HEAD)" = "$commit"
test "$(git -C "$app" branch --show-current)" = main
test "$(git -C "$app" remote get-url origin)" = "$source_repo"
test "$(git -C "$app" config branch.main.merge)" = refs/heads/main
test "$(git -C "$app" show :VERSION)" = source
test "$(find "$app" -path "$app/.git" -prune -o -type f -print0 | sort -z | xargs -0 sha256sum)" = "$before"

metadata_before="$(find "$app/.git" -type f -print0 | sort -z | xargs -0 sha256sum)"
bash "$ROOT_DIR/scripts/initialize-app-git.sh" "$archive" "$app" "$commit" "$source_repo" "$user"
test "$(find "$app/.git" -type f -print0 | sort -z | xargs -0 sha256sum)" = "$metadata_before"
if bash "$ROOT_DIR/scripts/initialize-app-git.sh" "$archive" "$app" 0000000000000000000000000000000000000000 "$source_repo" "$user"; then
  echo 'Repositorio existente divergente foi aceito.' >&2; exit 1
fi
test "$(git -C "$app" rev-parse HEAD)" = "$commit"

if [ "$(id -u)" = 0 ] && id nobody >/dev/null 2>&1; then
  chmod 755 "$temporary"
  owned_app="$temporary/service-owned"
  mkdir "$owned_app"
  chown "nobody:$(id -gn nobody)" "$owned_app"
  bash "$ROOT_DIR/scripts/initialize-app-git.sh" "$archive" "$owned_app" "$commit" "$source_repo" nobody
  test "$(runuser -u nobody -- git -C "$owned_app" rev-parse HEAD)" = "$commit"
  test "$(stat -c %U "$owned_app/.git")" = nobody
fi

mkdir "$temporary/wrong-commit"
if bash "$ROOT_DIR/scripts/initialize-app-git.sh" "$archive" "$temporary/wrong-commit" 0000000000000000000000000000000000000000 "$source_repo" "$user"; then
  echo 'Metadados de commit divergente foram aceitos.' >&2; exit 1
fi
test ! -e "$temporary/wrong-commit/.git"

# Prova que o checkout raso instalado pode buscar main e fazer fast-forward.
printf 'next\n' > "$source_repo/VERSION"
git -C "$source_repo" add VERSION
git -C "$source_repo" commit -qm 'next fixture'
git -C "$source_repo" branch -f main HEAD
git -C "$app" fetch -q origin main
git -C "$app" merge-base --is-ancestor "$commit" FETCH_HEAD

echo 'Vinculo Git: instalacao offline, preservacao, idempotencia e fetch aprovados.'
