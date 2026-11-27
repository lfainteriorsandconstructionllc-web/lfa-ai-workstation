# Guía para generar tu ISO instalable propia con Cubic (LFA AI OS)

Esta guía crea una **ISO Live + instalador completamente limpia** basada en **Kubuntu 26.04 LTS**, con todas las optimizaciones multi-agente de IA y la suite visual LFA preinstaladas, **sin copiar nada de tu `/home` personal ni credenciales privadas**.

---

## Requisitos previos

1. Descarga la ISO oficial de **Kubuntu 26.04 LTS** (`kubuntu-26.04.1-desktop-amd64.iso`).
2. Instala **Cubic**:
   ```bash
   sudo add-apt-repository universe
   sudo add-apt-repository ppa:cubic-wizard/release
   sudo apt update
   sudo apt install cubic
   ```
3. Ten listo el paquete `lfa-ai-workstation_1.0.0_all.deb` (generado con `./build-deb.sh` o descargado desde GitHub Releases).

---

## Pasos dentro de Cubic (~15 minutos)

1. Abre **Cubic**, elige una carpeta de proyecto vacía (por ejemplo `~/cubic-lfa-ai-os`) y selecciona la ISO de **Kubuntu 26.04 LTS**.
2. En la pantalla de metadatos de la ISO, cambia el nombre/volumen a tu propia marca (por ejemplo **LFA AI OS 1.0**, *no* uses la marca registrada "Ubuntu" en el nombre comercial).
3. Cuando Cubic abra la **terminal `chroot`**, arrastra el archivo `lfa-ai-workstation_1.0.0_all.deb` dentro de la ventana de Cubic (Cubic lo copiará al directorio actual del `chroot`).
4. Ejecuta en la terminal `chroot` de Cubic:
   ```bash
   apt-get update
   apt-get install -y ./lfa-ai-workstation_1.0.0_all.deb
   rm -f ./lfa-ai-workstation_1.0.0_all.deb
   apt-get autoremove -y
   apt-get clean
   ```
5. *(Opcional)* Si quieres que todos los usuarios nuevos arranquen con **LFA Dorado** ya aplicado desde el primer segundo, añade en `/etc/skel/.config/kdeglobals` las claves `LookAndFeelPackage=org.lfa.dorado` y `ColorScheme=LFADorado`.
6. Haz clic en **Next** → elige el kernel y compresión (`zstd` recomendado para arranque rápido) → **Generate**.

---

## Verificación antes de distribuir

Prueba siempre la ISO resultante en una máquina virtual (**QEMU/KVM** o **VirtualBox**) antes de publicarla:
1. Comprueba que arranca en modo Live y se instala correctamente.
2. Al iniciar sesión por primera vez, verifica que se abre automáticamente **LFA AI Workstation Setup** (`lfa-ai-setup`).
3. En Konsole, verifica:
   ```bash
   swapon --show          # Debe mostrar /dev/zram0 con prioridad 100
   sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances net.ipv4.tcp_congestion_control
   systemctl is-active systemd-oomd
   ```
