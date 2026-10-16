#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/config/versions.env"
base_iso="${1:?Informe a ISO Debian 11.11 DVD-1}"
kit="${2:?Informe o diretorio do kit offline preparado}"
output="${3:-$ROOT_DIR/dist/tronsoftos-db11-${KIT_VERSION}-amd64.iso}"
expected=4cd8d17e3cd6ccb065decc52bff1fc8e4dbc3756e98e34e9acb004dc14ee3d69
for command in xorriso sha256sum md5sum tar; do command -v "$command" >/dev/null || { echo "Comando ausente: $command" >&2; exit 2; }; done
[ -f "$kit/OFFLINE" ] || { echo 'O pacote informado nao esta preparado para uso offline.' >&2; exit 2; }
[ ! -e "$output" ] || { echo 'Arquivo de saida ja existe; escolha outro nome.' >&2; exit 2; }
printf '%s  %s\n' "$expected" "$base_iso" | sha256sum --check
bash "$kit/scripts/verify-kit.sh"
mkdir -p "$(dirname "$output")"
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
for file in isolinux/txt.cfg boot/grub/grub.cfg md5sum.txt; do
  mkdir -p "$temporary/$(dirname "$file")"
  xorriso -osirrox on -indev "$base_iso" -extract "/$file" "$temporary/$file"
  chmod u+w "$temporary/$file"
done
cat "$ROOT_DIR/iso/isolinux-entry.cfg" >> "$temporary/isolinux/txt.cfg"
cat "$ROOT_DIR/iso/grub-entry.cfg" >> "$temporary/boot/grub/grub.cfg"
awk '$2 != "./isolinux/txt.cfg" && $2 != "./boot/grub/grub.cfg" && $2 != "./md5sum.txt"' "$temporary/md5sum.txt" > "$temporary/md5sum.new"
for file in isolinux/txt.cfg boot/grub/grub.cfg; do
  printf '%s  ./%s\n' "$(md5sum "$temporary/$file" | cut -d' ' -f1)" "$file" >> "$temporary/md5sum.new"
done
(
  cd "$kit"
  find . -type f -print0 | sort -z | xargs -0 md5sum | sed 's#  ./#  ./tronsoftos/kit/#'
) >> "$temporary/md5sum.new"
for file in preseed.cfg INSTALAR.txt instalar; do
  printf '%s  ./tronsoftos/%s\n' "$(md5sum "$ROOT_DIR/iso/$file" | cut -d' ' -f1)" "$file" >> "$temporary/md5sum.new"
done
xorriso -indev "$base_iso" -outdev "$output" \
  -map "$kit" /tronsoftos/kit \
  -map "$ROOT_DIR/iso/preseed.cfg" /tronsoftos/preseed.cfg \
  -map "$ROOT_DIR/iso/INSTALAR.txt" /tronsoftos/INSTALAR.txt \
  -map "$ROOT_DIR/iso/instalar" /tronsoftos/instalar \
  -map "$temporary/isolinux/txt.cfg" /isolinux/txt.cfg \
  -map "$temporary/boot/grub/grub.cfg" /boot/grub/grub.cfg \
  -map "$temporary/md5sum.new" /md5sum.txt \
  -boot_image any replay -commit -end
xorriso -indev "$output" -report_el_torito plain 2>&1 | tee "$output.boot.txt"
grep -q BIOS "$output.boot.txt"
grep -q UEFI "$output.boot.txt"
(cd "$(dirname "$output")" && sha256sum "$(basename "$output")" > "$(basename "$output").sha256")
printf 'ISO gerada: %s\n' "$output"
