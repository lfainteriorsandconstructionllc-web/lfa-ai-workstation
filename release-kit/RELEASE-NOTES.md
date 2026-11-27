# LFA AI OS 1.0.0 — Release Notes

**LFA AI OS 1.0.0** is a KDE Plasma 6 Linux workstation distribution based on **Kubuntu 26.04.1 LTS**, tuned out of the box for developers and teams running **multiple concurrent cloud AI coding agents, IDEs, MCP servers, browsers, and parallel builds**.

Developed by **LFA Interiors and Construction LLC**.

---

## Highlights

- **Multi-Agent Memory & Anti-Freeze Tuning**
  - Compressed **ZRAM (`zstd`, up to 16 GB, priority 100)** so inactive Electron/IDE/browser memory compresses cleanly in RAM.
  - **`systemd-oomd`** enabled out of the box to prevent hard desktop freezes under extreme memory pressure.
  - High watcher and memory-map limits (`fs.inotify.max_user_watches=1048576`, `fs.inotify.max_user_instances=4096`, `vm.max_map_count=1048576`) for opening multiple agentic workspaces simultaneously.
  - **TCP BBR + FQ** enabled for low-latency cloud API and streaming agent connections.
  - Balanced default worker caps for Gradle (`workers.max=4`) and Cargo (`jobs=6`) in `/etc/skel` so background builds keep the desktop responsive.
- **Signature LFA KDE Plasma 6 Desktop**
  - **LFA Dorado 1.3** (Global Theme using native Plasma 6 widgets only, Plasma Style with native `metadata.json`, Gold Icons 1.2, `LFADorado` color scheme, Aurorae window decoration).
  - **LFA Living Landscapes 0.6.4** (31 dynamic photographic landscapes with real-time Open-Meteo weather, GPU water reflections, animated sky/clouds/rain/snow, WebP-optimized).
- **LFA AI Setup (`lfa-ai-setup`)**
  - Native PyQt6 first-run wizard to install official upstream developer and AI tools with one click (`uv`, Node.js, GitHub CLI, Claude Code, OpenAI Codex CLI, Google Chrome, Docker, Ollama) without bundling third-party proprietary binaries inside the ISO.

## Downloads & Verification

- **ISO (UEFI + BIOS Hybrid):** `LFA-AI-OS-1.0.0-amd64.iso`
- **Checksums:** `SHA256SUMS-ISO.txt`
- **Standalone `.deb` (for existing Ubuntu / Kubuntu 26.04 LTS systems):** `lfa-ai-workstation_1.0.0_all.deb`
- **Source Code:** https://github.com/lfainteriorsandconstructionllc-web/lfa-ai-workstation

## Licenses & Legal

Based on Kubuntu / Ubuntu 26.04 LTS. LFA AI OS is an independent derivative and is not affiliated with or endorsed by Canonical Ltd. LFA packages and scripts are licensed under **GPL-3.0-or-later** (see individual component credits and licenses).

---

# Notas de versión (Español)

**LFA AI OS 1.0.0** es una estación de trabajo Linux con **KDE Plasma 6** basada en **Kubuntu 26.04.1 LTS**, optimizada de fábrica para trabajar con **múltiples agentes de IA en la nube, IDEs, servidores MCP y compilaciones en paralelo** sin congelamientos.

Incluye **ZRAM (`zstd`, hasta 16 GB)**, **`systemd-oomd`**, límites altos de `inotify` y `vm.max_map_count`, **TCP BBR**, la suite visual **LFA Dorado 1.3** + **LFA Living Landscapes 0.6.4** y el asistente gráfico **LFA AI Setup** para instalar tus herramientas oficiales de IA con un clic.
