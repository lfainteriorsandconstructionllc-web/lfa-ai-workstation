# Installation Guide — LFA AI OS 1.0.0

## Minimum & Recommended Hardware
- **CPU:** 64-bit x86_64 (4+ cores recommended for multi-agent workflows)
- **RAM:** 8 GB minimum (16–32 GB recommended for multiple simultaneous IDEs/agents)
- **Storage:** 25 GB minimum (NVMe SSD recommended)
- **Boot:** UEFI or Legacy BIOS

## 1. Verify the ISO Checksum
Before flashing to USB, verify the integrity of the downloaded file:

```bash
sha256sum -c SHA256SUMS-ISO.txt
```

It must print `LFA-AI-OS-1.0.0-amd64.iso: OK`.

## 2. Create a Bootable USB Drive
- **Recommended (easiest):** Copy `LFA-AI-OS-1.0.0-amd64.iso` onto a **Ventoy** USB drive, or flash it using **Balena Etcher** / **Rufus** (DD mode on Windows).
- **From Linux terminal:**
  ```bash
  sudo dd if=LFA-AI-OS-1.0.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
  ```
  *(Replace `/dev/sdX` with your actual USB device — double-check with `lsblk`!)*

## 3. Boot & Install
1. Boot from the USB drive (F12 / F2 / Esc depending on your computer).
2. Test the desktop in Live mode or click **Install** to install to disk.
3. On first login, **LFA AI Workstation Setup** (`lfa-ai-setup`) opens automatically so you can install `uv`, Node.js, GitHub CLI, Claude Code, Codex CLI, Google Chrome, Docker, or Ollama directly from their official sources.

## Alternative: Install on Existing Kubuntu / Ubuntu 26.04 LTS
If you already run Kubuntu or Ubuntu 26.04 LTS, you do not need to format:
```bash
sudo apt install ./lfa-ai-workstation_1.0.0_all.deb
lfa-ai-setup
```
