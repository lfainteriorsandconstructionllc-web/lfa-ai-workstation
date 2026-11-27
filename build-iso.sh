#!/usr/bin/env bash
# Construye LFA-AI-OS-1.0.0-amd64.iso (híbrida UEFI + BIOS) de forma 100% desatendida
# a partir de la ISO oficial kubuntu-26.04.1-desktop-amd64.iso y lfa-ai-workstation_1.0.0_all.deb
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script con sudo:"
  echo "  sudo $0"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
BASE_ISO="${1:-$ROOT/iso-base/kubuntu-26.04.1-desktop-amd64.iso}"
DEB_PKG="$ROOT/dist/lfa-ai-workstation_1.0.0_all.deb"
OUT_ISO="$ROOT/dist/LFA-AI-OS-1.0.0-amd64.iso"
WORK="$ROOT/build/iso-work"
LOG="$ROOT/build/build-iso.log"

mkdir -p "$ROOT/build" "$ROOT/dist"
exec > >(tee "$LOG") 2>&1

if [[ ! -f "$BASE_ISO" ]]; then
  echo "ERROR: No se encontró la ISO base en: $BASE_ISO"
  exit 1
fi

if [[ ! -f "$DEB_PKG" ]]; then
  echo "ERROR: No se encontró el paquete .deb en: $DEB_PKG"
  echo "Ejecuta primero ./build-deb.sh"
  exit 1
fi

echo "==> 1/7 Verificando herramientas (squashfs-tools, xorriso, rsync)..."
if ! command -v mksquashfs >/dev/null 2>&1 || ! command -v xorriso >/dev/null 2>&1 || ! command -v rsync >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq squashfs-tools xorriso rsync
fi

cleanup() {
  set +e
  for m in dev/pts dev proc sys run; do
    if mountpoint -q "$WORK/squashfs/$m" 2>/dev/null; then
      umount -lf "$WORK/squashfs/$m" 2>/dev/null || true
    fi
  done
  if mountpoint -q "$WORK/squashfs" 2>/dev/null; then
    umount -lf "$WORK/squashfs" 2>/dev/null || true
  fi
  if mountpoint -q "$WORK/mnt" 2>/dev/null; then
    umount "$WORK/mnt" 2>/dev/null || true
  fi
}
trap cleanup EXIT

rm -rf "$WORK"
mkdir -p "$WORK/mnt" "$WORK/iso" "$WORK/squashfs"

echo "==> 2/7 Extrayendo ISO base ($BASE_ISO)..."
mount -o loop,ro "$BASE_ISO" "$WORK/mnt"
rsync -a "$WORK/mnt/" "$WORK/iso/"
umount "$WORK/mnt"
chmod -R u+w "$WORK/iso"

TARGET_SQFS=""
for candidate in \
  "$WORK/iso/casper/filesystem.squashfs" \
  "$WORK/iso/casper/minimal.standard.squashfs" \
  "$WORK/iso/casper/minimal.desktop.squashfs"; do
  if [[ -f "$candidate" ]]; then
    TARGET_SQFS="$candidate"
    break
  fi
done

if [[ -z "$TARGET_SQFS" ]]; then
  TARGET_SQFS="$(find "$WORK/iso/casper" -maxdepth 1 -name '*.squashfs' -printf '%s %p\n' | sort -nr | head -n1 | awk '{print $2}')"
fi

if [[ -z "$TARGET_SQFS" || ! -f "$TARGET_SQFS" ]]; then
  echo "ERROR: No se encontró ningún archivo .squashfs en casper/"
  exit 1
fi
echo "    Capa squashfs detectada: $(basename "$TARGET_SQFS")"

echo "==> 3/7 Desempaquetando sistema de archivos raíz..."
unsquashfs -q -d "$WORK/squashfs" "$TARGET_SQFS"

echo "==> 4/7 Instalando lfa-ai-workstation_1.0.0_all.deb dentro del chroot..."
cp "$DEB_PKG" "$WORK/squashfs/tmp/lfa-ai-workstation.deb"

# DNS público temporal dentro del chroot (evita stub 127.0.0.53)
RESOLV_BAK=""
if [[ -e "$WORK/squashfs/etc/resolv.conf" || -L "$WORK/squashfs/etc/resolv.conf" ]]; then
  mv "$WORK/squashfs/etc/resolv.conf" "$WORK/squashfs/etc/resolv.conf.lfabak"
  RESOLV_BAK=1
fi
cat > "$WORK/squashfs/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Respaldar sources.list.d original (la ISO solo trae file:///cdrom) y habilitar repos Ubuntu online temporalmente
mv "$WORK/squashfs/etc/apt/sources.list.d" "$WORK/squashfs/etc/apt/sources.list.d.lfabak"
mkdir -p "$WORK/squashfs/etc/apt/sources.list.d"
cat > "$WORK/squashfs/etc/apt/sources.list.d/lfa-temp-ubuntu.sources" <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: resolute resolute-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

mount --bind /dev "$WORK/squashfs/dev"
mount --bind /dev/pts "$WORK/squashfs/dev/pts"
mount -t proc proc "$WORK/squashfs/proc"
mount -t sysfs sysfs "$WORK/squashfs/sys"
mount --bind /run "$WORK/squashfs/run"

chroot "$WORK/squashfs" /bin/bash -euo pipefail -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y /tmp/lfa-ai-workstation.deb
  rm -f /tmp/lfa-ai-workstation.deb

  # Establecer LFA Dorado como tema por defecto en /etc/skel para usuarios nuevos
  mkdir -p /etc/skel/.config
  cat > /etc/skel/.config/kdeglobals <<EOF
[General]
ColorScheme=LFADorado

[Icons]
Theme=LFA

[KDE]
LookAndFeelPackage=org.lfa.dorado
widgetStyle=Breeze
EOF

  cat > /etc/skel/.config/plasmarc <<EOF
[Theme]
name=LFA-Plasma
EOF

  apt-get autoremove -y -qq
  apt-get clean
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
'

# Desmontar binds y restaurar sources.list.d y resolv.conf originales
for m in run sys proc dev/pts dev; do
  umount -lf "$WORK/squashfs/$m" || true
done

rm -rf "$WORK/squashfs/etc/apt/sources.list.d"
mv "$WORK/squashfs/etc/apt/sources.list.d.lfabak" "$WORK/squashfs/etc/apt/sources.list.d"

rm -f "$WORK/squashfs/etc/resolv.conf"
if [[ -n "$RESOLV_BAK" ]]; then
  mv "$WORK/squashfs/etc/resolv.conf.lfabak" "$WORK/squashfs/etc/resolv.conf"
fi

echo "==> 5/7 Recomprimiendo squashfs con zstd (puede tardar 5–10 minutos)..."
rm -f "$TARGET_SQFS"
mksquashfs "$WORK/squashfs" "$TARGET_SQFS" -comp zstd -Xcompression-level 15 -noappend -processors "$(nproc)"

SIZE_FILE="${TARGET_SQFS%.squashfs}.size"
if [[ -f "$SIZE_FILE" ]]; then
  du -sx --block-size=1 "$WORK/squashfs" | awk '{print $1}' > "$SIZE_FILE"
fi

echo "==> 6/7 Actualizando md5sum.txt y metadatos de la ISO..."
if [[ -f "$WORK/iso/.disk/info" ]]; then
  echo "LFA AI OS 1.0.0 (Based on Kubuntu 26.04.1 LTS) - amd64 ($(date +%Y%m%d))" > "$WORK/iso/.disk/info"
fi

(
  cd "$WORK/iso"
  find . -type f ! -name md5sum.txt ! -path './isolinux/*' -print0 | xargs -0 md5sum > md5sum.txt
)

echo "==> 7/7 Generando ISO híbrida UEFI + BIOS exacta con xorriso..."
# Leer las banderas exactas de arranque El Torito + partición EFI de la ISO original
mapfile -t BOOT_ARGS < <(
  xorriso -indev "$BASE_ISO" -report_el_torito as_mkisofs 2>/dev/null \
    | grep -v '^-V ' \
    | sed "s/^'//; s/'$//"
)

# Ejecutar xorriso preservando exactamente MBR + partición EFI GPT + El Torito (-iso-level 3 permite filesystem.squashfs > 4 GiB)
eval xorriso -as mkisofs \
  -iso-level 3 \
  -r -V "'LFA_AI_OS_1_0'" \
  -o "'$OUT_ISO'" \
  "$(xorriso -indev "$BASE_ISO" -report_el_torito as_mkisofs 2>/dev/null | grep -v '^-V ' | tr '\n' ' ')" \
  "'$WORK/iso'"

if [[ -n "${SUDO_USER:-}" ]]; then
  chown "$SUDO_USER:$SUDO_USER" "$OUT_ISO"
fi

(
  cd "$ROOT/dist"
  sha256sum "$(basename "$OUT_ISO")" > "SHA256SUMS-ISO.txt"
  if [[ -n "${SUDO_USER:-}" ]]; then
    chown "$SUDO_USER:$SUDO_USER" "SHA256SUMS-ISO.txt"
  fi
)

rm -rf "$WORK"

echo ""
echo "================================================================"
echo "✓ ISO generada con éxito: $OUT_ISO"
echo "  Tamaño: $(du -h "$OUT_ISO" | awk '{print $1}')"
echo "  SHA256: $(cat "$ROOT/dist/SHA256SUMS-ISO.txt")"
echo "================================================================"
