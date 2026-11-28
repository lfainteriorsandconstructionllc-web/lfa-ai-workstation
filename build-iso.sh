#!/usr/bin/env bash
# Construye LFA-AI-OS-1.0.0-amd64.iso (híbrida UEFI + BIOS) con branding completo
# de arranque a escritorio (GRUB + Plymouth + SDDM + Plasma + LFA Living Landscapes + LFA AI Assistant)
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

TARGET_SQFS="$WORK/iso/casper/filesystem.squashfs"
if [[ ! -f "$TARGET_SQFS" ]]; then
  TARGET_SQFS="$(find "$WORK/iso/casper" -maxdepth 1 -name '*.squashfs' -printf '%s %p\n' | sort -nr | head -n1 | awk '{print $2}')"
fi
echo "    Capa squashfs detectada: $(basename "$TARGET_SQFS")"

echo "==> 3/7 Desempaquetando sistema de archivos raíz..."
unsquashfs -q -d "$WORK/squashfs" "$TARGET_SQFS"

echo "==> 4/7 Instalando LFA AI OS completo dentro del chroot (paquete, Plymouth, SDDM, Plasma defaults)..."
cp "$DEB_PKG" "$WORK/squashfs/tmp/lfa-ai-workstation.deb"

RESOLV_BAK=""
if [[ -e "$WORK/squashfs/etc/resolv.conf" || -L "$WORK/squashfs/etc/resolv.conf" ]]; then
  mv "$WORK/squashfs/etc/resolv.conf" "$WORK/squashfs/etc/resolv.conf.lfabak"
  RESOLV_BAK=1
fi
cat > "$WORK/squashfs/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

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

  # 1. Identidad completa del sistema (conserva ID=ubuntu para 100% compatibilidad de paquetes/drivers)
  sed -i '\''s/^PRETTY_NAME=.*/PRETTY_NAME="LFA AI OS 1.0 (KDE Plasma 6)"/'\'' /etc/os-release || true
  if [[ -f /etc/lsb-release ]]; then
    sed -i '\''s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="LFA AI OS 1.0"/'\'' /etc/lsb-release || true
  fi
  echo "LFA AI OS 1.0 \\n \\l" > /etc/issue || true

  # 1b. Reemplazar la pantalla Live "Probar / Instalar Kubuntu" (kubuntu-installer-prompt) por LFA AI OS 1.0
  if [[ -f /usr/bin/lfa-installer-prompt ]]; then
    cp /usr/bin/lfa-installer-prompt /usr/bin/kubuntu-installer-prompt
    chmod 0755 /usr/bin/kubuntu-installer-prompt
  fi
  if [[ -f /usr/libexec/start-kubuntu-live-env ]]; then
    sed -i '\''s/kwin_wayland --xwayland --no-lockscreen kubuntu-installer-prompt/kwin_wayland --xwayland --no-lockscreen --exit-with-session=kubuntu-installer-prompt/'\'' /usr/libexec/start-kubuntu-live-env || true
  fi

  # Reemplazar TODOS los gráficos, diapositivas (01..09) y textos de Calamares por LFA AI OS 1.0
  LFA_BANNER="/usr/share/lfa-ai-os/graphics/lfa-banner.jpg"
  LFA_GRUB_BG="/usr/share/lfa-ai-os/graphics/lfa-grub-bg.png"
  LFA_LOCK_BG="/usr/share/lfa-ai-os/graphics/lfa-lockscreen-bg.jpg"
  for cdir in /etc/calamares/branding/* /usr/share/calamares/branding/*; do
    if [[ -d "$cdir" ]]; then
      if [[ -f "$cdir/branding.desc" ]]; then
        sed -i -E '\''s/Kubuntu/LFA AI OS/g; s/KDE Plasma/LFA AI OS/g'\'' "$cdir/branding.desc" || true
      fi
      for img in "$cdir"/*logo*.png "$cdir"/*icon*.png "$cdir"/*logo*.svg; do
        [[ -f "$img" ]] && cp /usr/share/icons/LFA/apps/512/lfa-logo.png "$img" || true
      done
      for wimg in "$cdir"/*welcome*.png "$cdir"/*banner*.png "$cdir"/*background*.jpg "$cdir"/*background*.png; do
        [[ -f "$wimg" ]] && cp "$LFA_BANNER" "$wimg" || true
      done
      # Reemplazar TODAS las diapositivas numeradas (01-welcome-to-kubuntu.png .. 09-open-source-software.png)
      idx=0
      for slide in "$cdir"/0*.png "$cdir"/0*.jpg "$cdir"/slide*.png "$cdir"/slide*.jpg; do
        if [[ -f "$slide" ]]; then
          case $((idx % 3)) in
            0) cp "$LFA_BANNER" "$slide" ;;
            1) cp "$LFA_GRUB_BG" "$slide" ;;
            2) cp "$LFA_LOCK_BG" "$slide" ;;
          esac
          idx=$((idx + 1))
        fi
      done
      # Reemplazar show.qml con presentación limpia de LFA AI OS 1.0 (cero referencias a Kubuntu/KDE)
      if [[ -f "$cdir/show.qml" ]]; then
        cat > "$cdir/show.qml" <<'\''QML_EOF'\''
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation
    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }
    Slide {
        Image { anchors.fill: parent; source: "01-welcome-to-kubuntu.png"; fillMode: Image.PreserveAspectCrop }
    }
    Slide {
        Image { anchors.fill: parent; source: "02-kubuntu-lts.png"; fillMode: Image.PreserveAspectCrop }
    }
    Slide {
        Image { anchors.fill: parent; source: "03-kde.png"; fillMode: Image.PreserveAspectCrop }
    }
}
QML_EOF
      fi
    fi
  done

  # Dejar un único acceso directo de instalación (Calamares) renombrado a LFA AI OS 1.0 y eliminar duplicados/promos
  rm -f /etc/skel/Desktop/*kubuntu* /etc/skel/Desktop/*kfocus* /etc/skel/Desktop/*calamares* /etc/skel/Desktop/*ubiquity* /etc/skel/Desktop/a_welcome.desktop 2>/dev/null || true
  rm -f /usr/share/applications/org.kubuntu.*.desktop /usr/share/applications/ubiquity*.desktop /usr/share/kde4/apps/khelpcenter/plugins/kubuntu/a_welcome.desktop 2>/dev/null || true
  rm -f /etc/xdg/autostart/*welcome* /etc/xdg/autostart/*kubuntu* /etc/xdg/autostart/org.kde.plasma-welcome.desktop 2>/dev/null || true

  for dfile in /usr/share/applications/*calamares*.desktop /usr/share/kubuntu-default-settings/*calamares*.desktop; do
    if [[ -f "$dfile" ]]; then
      sed -i -E '\''s/Kubuntu/LFA AI OS 1.0/g'\'' "$dfile" || true
      sed -i -E '\''s/^Name=.*/Name=Install LFA AI OS 1.0/'\'' "$dfile" || true
      sed -i -E '\''s/^Name\[es\]=.*/Name[es]=Instalar LFA AI OS 1.0/'\'' "$dfile" || true
      sed -i -E '\''s/^Icon=.*/Icon=lfa-logo/'\'' "$dfile" || true
    fi
  done

  # 1c. Unificar TODOS los gráficos del sistema (wallpapers, splash screens, SDDM, pantalla de bloqueo) a LFA AI OS
  LFA_BG="/usr/share/sddm/themes/LFA-Dorado-SDDM/background.jpg"
  for wpdir in /usr/share/wallpapers/Kubuntu /usr/share/wallpapers/KubuntuBlack /usr/share/wallpapers/KubuntuLight /usr/share/wallpapers/Next; do
    if [[ -d "$wpdir/contents/images" ]]; then
      find "$wpdir/contents/images" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -exec cp "$LFA_BG" {} \; || true
    fi
    if [[ -d "$wpdir/contents/images_dark" ]]; then
      find "$wpdir/contents/images_dark" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -exec cp "$LFA_BG" {} \; || true
    fi
  done

  # Reemplazar splash screen de Kubuntu y Breeze (KDE) con el splash dorado LFA AI OS
  for lnf in /usr/share/plasma/look-and-feel/org.kubuntu.desktop /usr/share/plasma/look-and-feel/org.kubuntulight.desktop /usr/share/plasma/look-and-feel/org.kde.breeze.desktop /usr/share/plasma/look-and-feel/org.kde.breezedark.desktop; do
    if [[ -d "$lnf" ]]; then
      rm -rf "$lnf/contents/splash"
      cp -a /usr/share/plasma/look-and-feel/org.lfa.dorado/contents/splash "$lnf/contents/splash"
    fi
  done

  # Reemplazar fondos de SDDM de respaldo (kubuntu / breeze) y alternativa sddm-ubuntu-theme
  for sdir in /usr/share/sddm/themes/kubuntu /usr/share/sddm/themes/kubuntu-light /usr/share/sddm/themes/breeze; do
    if [[ -d "$sdir" ]]; then
      find "$sdir" -maxdepth 2 -type f \( -name "*background*.jpg" -o -name "*background*.png" -o -name "*logo*.png" \) -exec cp "$LFA_BG" {} \; || true
    fi
  done
  if update-alternatives --list sddm-ubuntu-theme >/dev/null 2>&1; then
    update-alternatives --install /usr/share/sddm/themes/ubuntu-theme sddm-ubuntu-theme /usr/share/sddm/themes/LFA-Dorado-SDDM 200 || true
    update-alternatives --set sddm-ubuntu-theme /usr/share/sddm/themes/LFA-Dorado-SDDM || true
  fi

  # Usar el layout LFA AI OS como layout nativo por defecto de Plasma y Kubuntu (evita flash de Kubuntu en el primer inicio)
  cp /usr/share/plasma/look-and-feel/org.lfa.dorado/contents/layouts/org.kde.plasma.desktop-layout.js \
     /usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js || true
  if [[ -d /usr/share/kubuntu-default-settings ]]; then
    cp /usr/share/plasma/look-and-feel/org.lfa.dorado/contents/layouts/org.kde.plasma.desktop-layout.js \
       /usr/share/kubuntu-default-settings/layout.js || true
  fi

  # 2. Sobrescribir defaults de Kubuntu (los que ganaban en Live Boot sobre /etc/skel)
  KDEF="/usr/share/kubuntu-default-settings/kf5-settings"
  mkdir -p "$KDEF" /etc/skel/.config
  cp /usr/share/color-schemes/LFADorado.colors "$KDEF/CalaTheme.colors" || true
  cp /usr/share/color-schemes/LFADorado.colors "$KDEF/calamaresrc" || true
  for dir in "$KDEF" /etc/skel/.config; do
    cat > "$dir/kdeglobals" <<EOF
[General]
ColorScheme=LFADorado

[Icons]
Theme=LFA

[KDE]
LookAndFeelPackage=org.lfa.dorado
widgetStyle=Breeze
EOF

    cat > "$dir/plasmarc" <<EOF
[Theme]
name=LFA-Plasma
EOF

    cat > "$dir/ksplashrc" <<EOF
[KSplash]
Engine=KSplashQML
Theme=org.lfa.dorado
EOF

    cat > "$dir/kscreenlockerrc" <<EOF
[Daemon]
Autolock=true
Timeout=15

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/sddm/themes/LFA-Dorado-SDDM/background.jpg
PreviewImage=file:///usr/share/sddm/themes/LFA-Dorado-SDDM/background.jpg
EOF

    cat > "$dir/plasma-welcomerc" <<EOF
[General]
LastSeenVersion=99.0.0
LiveEnvironment=false
EOF

    cat > "$dir/kwinrc" <<EOF
[org.kde.kdecoration2]
ButtonsOnLeft=XIA
ButtonsOnRight=
library=org.kde.kwin.aurorae
theme=__aurorae__svg__LFA
EOF
  done

  cat > "$KDEF/kcm-about-distrorc" <<EOF
[General]
LogoPath=/usr/share/icons/hicolor/256x256/apps/lfa-ai-assistant.png
Website=https://lfabuild.com
Variant=LFA AI OS 1.0 (Multi-Agent AI Workstation)
EOF

  # 3. Activar Plymouth LFA AI OS y unificar kubuntu-logo / kubuntu-text a LFA AI OS
  if [[ -f /usr/share/plymouth/themes/lfa/lfa.plymouth ]]; then
    mkdir -p /etc/plymouth
    cat > /etc/plymouth/plymouthd.conf <<EOF
[Daemon]
Theme=lfa
ShowDelay=0
DeviceTimeout=8
UseSimpledrm=1
EOF
    if [[ -d /usr/share/plymouth/themes/kubuntu-logo ]]; then
      cp /usr/share/plymouth/themes/lfa/lfa.plymouth /usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.plymouth || true
    fi
    if [[ -d /usr/share/plymouth/themes/kubuntu-text ]]; then
      cat > /usr/share/plymouth/themes/kubuntu-text/kubuntu-text.plymouth <<EOF
[Plymouth Theme]
Name=LFA AI OS Text
Description=LFA AI OS Text Mode
ModuleName=ubuntu-text

[ubuntu-text]
title=LFA AI OS 1.0
black=0x14181d
white=0xd1b57b
brown=0xd1b57b
blue=0xd1b57b
EOF
    fi
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/lfa/lfa.plymouth 200
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/lfa/lfa.plymouth
    update-initramfs -u -k all || true
  fi

  apt-get autoremove -y -qq
  apt-get clean
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
'

# 4b. Inyectar tema Plymouth LFA AI OS en el segmento zstd de casper/initrd
# Conserva intactos microcode/firmware (segmentos 1-3) y todos los hooks Live USB de casper!
echo "    Actualizando Plymouth a LFA AI OS dentro de casper/initrd (conservando hooks de casper)..."
INITRD_FILE="$WORK/iso/casper/initrd"
ZSTD_START="$(python3 -c '
import sys
d = open(sys.argv[1], "rb").read()
pos = 0
last_trailer = -1
while True:
    p = d.find(b"TRAILER!!!", pos)
    if p == -1:
        break
    last_trailer = p
    pos = p + 10
end = last_trailer + 10
while end < len(d) and d[end] == 0:
    end += 1
if d[end:end+4] != b"\x28\xb5\x2f\xfd":
    sys.exit(1)
print(end)
' "$INITRD_FILE")"

if [[ -n "$ZSTD_START" ]]; then
  INITRD_MAIN="$WORK/initrd-main"
  rm -rf "$INITRD_MAIN"
  mkdir -p "$INITRD_MAIN"

  head -c "$ZSTD_START" "$INITRD_FILE" > "$WORK/initrd.prefix"
  tail -c +$((ZSTD_START + 1)) "$INITRD_FILE" | zstd -dc | (cd "$INITRD_MAIN" && cpio -id --quiet)

  mkdir -p \
    "$INITRD_MAIN/etc/plymouth" \
    "$INITRD_MAIN/usr/share/plymouth/themes/lfa" \
    "$INITRD_MAIN/usr/share/plymouth/themes/kubuntu-logo" \
    "$INITRD_MAIN/usr/share/plymouth/themes/kubuntu-text"

  cp -a "$WORK/squashfs/usr/share/plymouth/themes/lfa/." "$INITRD_MAIN/usr/share/plymouth/themes/lfa/"
  ln -sf /usr/share/plymouth/themes/lfa/lfa.plymouth "$INITRD_MAIN/usr/share/plymouth/themes/default.plymouth"
  cp "$WORK/squashfs/usr/share/plymouth/themes/lfa/lfa.plymouth" "$INITRD_MAIN/usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.plymouth"
  cp "$WORK/squashfs/usr/share/plymouth/themes/kubuntu-text/kubuntu-text.plymouth" "$INITRD_MAIN/usr/share/plymouth/themes/kubuntu-text/kubuntu-text.plymouth"
  cat > "$INITRD_MAIN/etc/plymouth/plymouthd.conf" <<'EOF'
[Daemon]
Theme=lfa
ShowDelay=0
DeviceTimeout=8
UseSimpledrm=1
EOF
  cp "$INITRD_MAIN/etc/plymouth/plymouthd.conf" "$INITRD_MAIN/usr/share/plymouth/plymouthd.defaults"

  (
    cd "$INITRD_MAIN"
    find . -mindepth 1 -printf '%P\n' | cpio -H newc -o --quiet | zstd -q -T0 -10
  ) > "$WORK/initrd.main.zst"

  cat "$WORK/initrd.prefix" "$WORK/initrd.main.zst" > "$INITRD_FILE"
  rm -rf "$INITRD_MAIN" "$WORK/initrd.prefix" "$WORK/initrd.main.zst"

  # Verificar que casper y el tema LFA están intactos en el initrd resultante
  if lsinitramfs "$INITRD_FILE" | grep -q "^scripts/casper$" && lsinitramfs "$INITRD_FILE" | grep -q "themes/lfa/lfa.plymouth$"; then
    echo "    ✓ casper/initrd verificado: hooks de casper + Plymouth LFA AI OS activos."
  else
    echo "ERROR: Falló la verificación de casper/initrd."
    exit 1
  fi
fi

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

echo "==> 6/7 Actualizando menú GRUB Live (fondo gráfico LFA AI OS, colores y títulos), md5sum.txt y metadatos..."
cp "$ROOT/release-kit/graphics/lfa-grub-bg.png" "$WORK/iso/boot/grub/lfa-grub-bg.png"
for gcfg in "$WORK/iso/boot/grub/grub.cfg" "$WORK/iso/boot/grub/loopback.cfg"; do
  if [[ -f "$gcfg" ]]; then
    sed -i 's/^set menu_color_normal=.*/set menu_color_normal=light-gray\/black/' "$gcfg"
    sed -i 's/^set menu_color_highlight=.*/set menu_color_highlight=black\/yellow/' "$gcfg"
    sed -i 's/Try or Install Kubuntu/Iniciar o Instalar LFA AI OS 1.0/g' "$gcfg"
    sed -i 's/Kubuntu (safe graphics)/LFA AI OS 1.0 (gráficos seguros)/g' "$gcfg"
    sed -i 's/Kubuntu/LFA AI OS 1.0/g' "$gcfg"
    sed -i '/OEM install (for manufacturers)/,/^[[:space:]]*}/d' "$gcfg"
    if ! grep -q "lfa-grub-bg.png" "$gcfg"; then
      sed -i '/^loadfont unicode/a \
insmod all_video\
insmod gfxterm\
insmod png\
set gfxmode=auto\
terminal_output gfxterm\
background_image /boot/grub/lfa-grub-bg.png' "$gcfg"
    fi
  fi
done

if [[ -f "$WORK/iso/.disk/info" ]]; then
  echo "LFA AI OS 1.0.0 - amd64 ($(date +%Y%m%d))" > "$WORK/iso/.disk/info"
fi

(
  cd "$WORK/iso"
  find . -type f ! -name md5sum.txt ! -path './isolinux/*' -print0 | xargs -0 md5sum > md5sum.txt
)

echo "==> 7/7 Generando ISO híbrida UEFI + BIOS exacta con xorriso (-iso-level 3)..."
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
