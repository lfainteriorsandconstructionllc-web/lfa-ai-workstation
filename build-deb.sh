#!/usr/bin/env bash
# Construye dist/lfa-ai-workstation_1.0.0_all.deb de forma reproducible
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APPLFA="$(dirname "$ROOT")"

DORADO_13="$APPLFA/LFA-Dorado-KDE-Store/actualizacion-1.3/archivos"
DORADO_PKG="$APPLFA/LFA-Dorado-KDE-Store/paquetes"
LANDSCAPES_ZIP="$APPLFA/LFA-Clima-Dinamico/kde-store-0.6.4/LFA-Living-Landscapes-KDE-0.6.4.zip"

STAGE="$ROOT/build/pkg"
OUT_DIR="$ROOT/dist"
OUT_DEB="$OUT_DIR/lfa-ai-workstation_1.0.0_all.deb"

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$OUT_DIR"

echo "==> 1/6 Copiando archivos de sistema y /etc/skel..."
cp -a "$ROOT/system/." "$STAGE/"
find "$STAGE" -name "__pycache__" -type d -exec rm -rf {} +

echo "==> 2/6 Integrando LFA Dorado 1.3 (Global, Plasma, Íconos, Colores, Bordes)..."
mkdir -p \
  "$STAGE/usr/share/plasma/look-and-feel" \
  "$STAGE/usr/share/plasma/desktoptheme" \
  "$STAGE/usr/share/plasma/wallpapers/org.lfa.weatherlandscape" \
  "$STAGE/usr/share/icons" \
  "$STAGE/usr/share/color-schemes" \
  "$STAGE/usr/share/aurorae/themes" \
  "$STAGE/usr/share/plymouth/themes" \
  "$STAGE/usr/share/sddm/themes"

tar -xzf "$DORADO_13/LFA-Dorado-tema-global-1.3.tar.gz" -C "$STAGE/usr/share/plasma/look-and-feel"
tar -xzf "$DORADO_13/LFA-Dorado-tema-plasma-1.3.tar.gz" -C "$STAGE/usr/share/plasma/desktoptheme"
tar -xzf "$DORADO_13/LFA-Dorado-iconos-1.2.tar.gz" -C "$STAGE/usr/share/icons"
tar -xzf "$DORADO_PKG/LFA-Dorado-bordes-de-ventana.tar.gz" -C "$STAGE/usr/share/aurorae/themes"
cp "$DORADO_PKG/LFADorado.colors" "$STAGE/usr/share/color-schemes/LFADorado.colors"

echo "==> 3/6 Integrando arranque LFA AI OS (Plymouth + SDDM con emblemas AI OS)..."
tar -xzf "$DORADO_PKG/LFA-Dorado-plymouth.tar.gz" -C "$STAGE/usr/share/plymouth/themes"
# Actualizar watermark de Plymouth con el nuevo emblema LFA + AI OS (sin Interiors and Construction)
cp "$APPLFA/LFA-Dorado-KDE-Store/actualizacion-1.3/fuentes/org.lfa.dorado/contents/splash/images/lfa-emblema.png" \
   "$STAGE/usr/share/plymouth/themes/lfa/watermark.png"

tar -xzf "$DORADO_PKG/LFA-Dorado-SDDM.tar.gz" -C "$STAGE/usr/share/sddm/themes"
# Actualizar fondo de SDDM con el banner limpio LFA AI OS
cp "$ROOT/release-kit/graphics/00-banner-lfa-ai-os.jpg" "$STAGE/usr/share/sddm/themes/LFA-Dorado-SDDM/background.jpg"
cp "$ROOT/release-kit/graphics/00-banner-lfa-ai-os.jpg" "$STAGE/usr/share/sddm/themes/LFA-Dorado-SDDM/fondo-lfa.jpg"

echo "==> 4/6 Integrando LFA Living Landscapes 0.6.4 (WebP)..."
unzip -q "$LANDSCAPES_ZIP" -d "$STAGE/usr/share/plasma/wallpapers/org.lfa.weatherlandscape"

echo "==> 5/6 Configurando metadatos DEBIAN y permisos..."
cp "$ROOT/debian/control" "$STAGE/DEBIAN/control"
cp "$ROOT/debian/postinst" "$STAGE/DEBIAN/postinst"
cp "$ROOT/debian/prerm" "$STAGE/DEBIAN/prerm"

chmod 0755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm"
chmod 0755 "$STAGE/usr/bin/lfa-ai-setup" "$STAGE/usr/bin/lfa-ai-assistant" "$STAGE/usr/bin/lfa-apply-theme"
chmod 0644 "$STAGE/etc/systemd/zram-generator.conf"
chmod 0644 "$STAGE/etc/sysctl.d/99-lfa-ai-workstation.conf"
chmod 0644 "$STAGE/etc/sddm.conf.d/lfa-ai-os.conf"
chmod 0644 "$STAGE/usr/share/applications/lfa-ai-setup.desktop" "$STAGE/usr/share/applications/lfa-ai-assistant.desktop"
chmod 0644 "$STAGE/etc/xdg/autostart/lfa-first-boot-theme.desktop"
chmod 0755 "$STAGE/etc/skel/Desktop/lfa-ai-assistant.desktop"
chmod 0644 "$STAGE/etc/skel/.config/autostart/lfa-ai-setup.desktop"
chmod 0644 "$STAGE/etc/skel/.gradle/gradle.properties" "$STAGE/etc/skel/.cargo/config.toml"

INSTALLED_SIZE=$(du -sk "$STAGE" | awk '{print $1}')
echo "Installed-Size: $INSTALLED_SIZE" >> "$STAGE/DEBIAN/control"

echo "==> 6/6 Empaquetando .deb con dpkg-deb..."
dpkg-deb --root-owner-group --build "$STAGE" "$OUT_DEB"

echo ""
echo "✓ Paquete creado: $OUT_DEB ($(du -h "$OUT_DEB" | awk '{print $1}'))"
dpkg-deb --info "$OUT_DEB"
