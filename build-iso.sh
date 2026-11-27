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

if [[ ! -f "$BASE_ISO" ]]; then
  echo "ERROR: No se encontró la ISO base en: $BASE_ISO"
  exit 1
fi

if [[ ! -f "$DEB_PKG" ]]; then
  echo "ERROR: No se encontró el paquete .deb en: $DEB_PKG"
  echo "Ejecuta primero ./build-deb.sh"
  exit 1
fi

echo "==> 1/7 Instalando herramientas de empaquetado (squashfs-tools, xorriso)..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq squashfs-tools xorriso rsync

cleanup() {
  set +e
  for m in dev/pts dev proc sys run; do
    if mountpoint -q "$WORK/squashfs/$m" 2>/dev/null; then
      umount -lf "$WORK/squashfs/$m" 2>/dev/null || true
    fi
  done
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

# Detectar la capa squashfs principal del escritorio (Ubuntu/Kubuntu 24.04–26.04)
TARGET_SQFS=""
for candidate in \
  "$WORK/iso/casper/minimal.standard.squashfs" \
  "$WORK/iso/casper/minimal.desktop.squashfs" \
  "$WORK/iso/casper/filesystem.squashfs"; do
  if [[ -f "$candidate" ]]; then
    TARGET_SQFS="$candidate"
    break
  fi
done

if [[ -z "$TARGET_SQFS" ]]; then
  # Tomar el squashfs más grande dentro de casper/
  TARGET_SQFS="$(find "$WORK/iso/casper" -maxdepth 1 -name '*.squashfs' -printf '%s %p\n' | sort -nr | head -n1 | awk '{print $2}')"
fi

if [[ -z "$TARGET_SQFS" || ! -f "$TARGET_SQFS" ]]; then
  echo "ERROR: No se encontró ningún archivo .squashfs en casper/"
  exit 1
fi
echo "    Capa squashfs detectada: $(basename "$TARGET_SQFS")"

echo "==> 3/7 Desempaquetando sistema de archivos raíz..."
# Si Kubuntu usa capas (minimal + minimal.standard), montamos overlayfs para el chroot
if [[ "$(basename "$TARGET_SQFS")" == "minimal.standard.squashfs" && -f "$WORK/iso/casper/minimal.squashfs" ]]; then
  mkdir -p "$WORK/lower-min" "$WORK/upper-std" "$WORK/ovl-work"
  unsquashfs -q -d "$WORK/lower-min" "$WORK/iso/casper/minimal.squashfs"
  unsquashfs -q -d "$WORK/upper-std" "$TARGET_SQFS"
  mount -t overlay overlay -o "lowerdir=$WORK/lower-min,upperdir=$WORK/upper-std,workdir=$WORK/ovl-work" "$WORK/squashfs"
  REPACK_DIR="$WORK/upper-std"
  USE_OVERLAY=1
else
  unsquashfs -q -d "$WORK/squashfs" "$TARGET_SQFS"
  REPACK_DIR="$WORK/squashfs"
  USE_OVERLAY=0
fi

echo "==> 4/7 Instalando lfa-ai-workstation_1.0.0_all.deb dentro del chroot..."
cp "$DEB_PKG" "$WORK/squashfs/tmp/lfa-ai-workstation.deb"

# DNS temporal dentro del chroot
RESOLV_BAK=""
if [[ -f "$WORK/squashfs/etc/resolv.conf" || -L "$WORK/squashfs/etc/resolv.conf" ]]; then
  mv "$WORK/squashfs/etc/resolv.conf" "$WORK/squashfs/etc/resolv.conf.lfabak"
  RESOLV_BAK=1
fi
cp /etc/resolv.conf "$WORK/squashfs/etc/resolv.conf"

mount --bind /dev "$WORK/squashfs/dev"
mount --bind /dev/pts "$WORK/squashfs/dev/pts"
mount -t proc proc "$WORK/squashfs/proc"
mount -t sysfs sysfs "$WORK/squashfs/sys"
mount --bind /run "$WORK/squashfs/run"

chroot "$WORK/squashfs" /bin/bash -euo pipefail -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
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

# Desmontar binds y restaurar resolv.conf
for m in run sys proc dev/pts dev; do
  umount -lf "$WORK/squashfs/$m" || true
done
rm -f "$WORK/squashfs/etc/resolv.conf"
if [[ -n "$RESOLV_BAK" ]]; then
  mv "$WORK/squashfs/etc/resolv.conf.lfabak" "$WORK/squashfs/etc/resolv.conf"
fi
if [[ "$USE_OVERLAY" -eq 1 ]]; then
  umount "$WORK/squashfs"
fi

echo "==> 5/7 Recomprimiendo squashfs con zstd (puede tardar varios minutos)..."
rm -f "$TARGET_SQFS"
mksquashfs "$REPACK_DIR" "$TARGET_SQFS" -comp zstd -Xcompression-level 15 -noappend -processors "$(nproc)"

# Actualizar tamaño si existe el archivo .size correspondiente
SIZE_FILE="${TARGET_SQFS%.squashfs}.size"
if [[ -f "$SIZE_FILE" ]]; then
  du -sx --block-size=1 "$REPACK_DIR" | awk '{print $1}' > "$SIZE_FILE"
fi

echo "==> 6/7 Actualizando md5sum.txt y metadatos de la ISO..."
if [[ -f "$WORK/iso/.disk/info" ]]; then
  echo "LFA AI OS 1.0.0 (Based on Kubuntu 26.04.1 LTS) - amd64 ($(date +%Y%m%d))" > "$WORK/iso/.disk/info"
fi

(
  cd "$WORK/iso"
  find . -type f ! -name md5sum.txt ! -path './isolinux/*' -print0 | xargs -0 md5sum > md5sum.txt
)

echo "==> 7/7 Generando ISO híbrida UEFI + BIOS con xorriso..."
# Extraer partición EFI e imagen MBR de la ISO original para preservar el arranque exacto
dd if="$BASE_ISO" bs=1 count=432 of="$WORK/boot_hybrid.img" status=none

EFI_IMG=""
for efi_cand in "$WORK/iso/boot/grub/efi.img" "$WORK/iso/EFI/efiboot.img"; do
  if [[ -f "$efi_cand" ]]; then
    EFI_IMG="${efi_cand#$WORK/iso/}"
    break
  fi
done

if [[ -n "$EFI_IMG" ]]; then
  xorriso -as mkisofs \
    -r -V "LFA-AI-OS-1.0.0" \
    -o "$OUT_ISO" \
    --grub2-mbr "$WORK/boot_hybrid.img" \
    -partition_offset 16 \
    --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$WORK/iso/$EFI_IMG" \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c '/boot.catalog' \
    -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
    -no-emul-boot \
    "$WORK/iso"
else
  # Respaldo usando las opciones de arranque exactas de la ISO original
  xorriso -indev "$BASE_ISO" -report_el_torito as_mkisofs > "$WORK/el_torito.opts" 2>/dev/null || true
  xorriso -as mkisofs \
    -r -V "LFA-AI-OS-1.0.0" \
    -o "$OUT_ISO" \
    -J -joliet-long -l \
    "$WORK/iso"
fi

# Dejar la ISO propiedad del usuario que invocó sudo
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
