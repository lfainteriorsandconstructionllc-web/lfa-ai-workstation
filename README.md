# LFA AI Workstation

Paquete reproducible (`.deb`) y guía de creación de ISO para transformar **Kubuntu / Ubuntu 26.04 LTS** en una estación de trabajo **KDE Plasma 6** optimizada para trabajar con **múltiples agentes de IA en la nube simultáneamente** (Antigravity, Claude Code, OpenAI Codex, servidores MCP, Chrome y compilaciones en paralelo).

## Qué incluye

1. **Optimización multi-agente del sistema**:
   - **ZRAM (`zstd`, hasta 16 GB, prioridad 100)** vía `/etc/systemd/zram-generator.conf`: comprime procesos Electron/IDE inactivos en RAM sin congelar el escritorio.
   - **Protección contra congelamientos (`systemd-oomd`)** activada automáticamente.
   - **Ajustes de kernel (`/etc/sysctl.d/99-lfa-ai-workstation.conf`)**:
     - `fs.inotify.max_user_watches = 1048576` y `max_user_instances = 4096` (múltiples workspaces, watchers y servidores MCP sin errores `ENOSPC`/`EMFILE`).
     - `vm.max_map_count = 1048576`, `vm.swappiness = 80`, `vm.page-cluster = 0`.
     - Red `TCP BBR` + `fq` para menor latencia con APIs y agentes en la nube.
   - **Perfil limpio `/etc/skel/`**: límites equilibrados para Gradle (`workers.max=4`) y Cargo (`jobs=6`) para que las compilaciones en segundo plano no traben la interfaz ni tus chats de IA.

2. **Suite visual oficial de LFA (Plasma 6)**:
   - **LFA Dorado 1.3** (Tema global nativo Plasma 6, estilo Plasma con `metadata.json`, íconos 1.2, colores `LFADorado`, bordes de ventana Aurorae).
   - **LFA Living Landscapes 0.6.4** (31 paisajes dinámicos con clima en tiempo real, optimizado en WebP).

3. **Asistente gráfico de primer inicio (`lfa-ai-setup`)**:
   - Interfaz nativa en **PyQt6** que permite instalar con un clic desde sus fuentes oficiales las herramientas elegidas por el usuario (`uv`, Node.js, GitHub CLI, Claude Code, Codex CLI, Google Chrome, Docker, Ollama) sin redistribuir binarios privativos de terceros dentro del paquete ni de la ISO.

## Instalación sobre Kubuntu / Ubuntu 26.04 LTS

Descarga el `.deb` desde [Releases](https://github.com/lfainteriorsandconstructionllc-web/lfa-ai-workstation/releases) e instálalo:

```bash
sudo apt install ./lfa-ai-workstation_1.0.0_all.deb
```

Luego ejecuta `lfa-ai-setup` desde el menú de aplicaciones (o `lfa-apply-theme` en terminal) para aplicar el tema a tu usuario actual e instalar las herramientas que desees.

## Cómo generar la ISO propia (LFA AI OS)

Ver la guía paso a paso en [GUIA-ISO-CUBIC.md](GUIA-ISO-CUBIC.md).

## Compilar el `.deb` desde código fuente

```bash
./build-deb.sh
```

## Licencias

- Scripts, empaquetado y `lfa-ai-setup`: **GPL-3.0-or-later**.
- Componentes visuales LFA Dorado y LFA Living Landscapes: ver licencias y créditos individuales (GPL-3.0-or-later / AGPL-3.0-or-later / LGPL-3.0).
- Software de terceros instalado opcionalmente por `lfa-ai-setup` conserva sus propias licencias y se descarga directamente desde sus proveedores oficiales.
