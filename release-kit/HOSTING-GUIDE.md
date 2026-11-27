# Guía de servidores gratuitos para alojar la ISO (~5 GB)

GitHub Releases tiene un límite estricto de **2 GB por archivo** (por eso el `.deb` de 42 MB sí vive en GitHub Releases, pero la ISO de ~4.8 GB necesita un hosting para archivos grandes). Estos son los **3 mejores servidores gratuitos** para alojar y distribuir `LFA-AI-OS-1.0.0-amd64.iso`:

---

## 1. SourceForge (RECOMENDADO como espejo principal para DistroWatch)
- **Límite:** Sin límite práctico de tamaño, ancho de banda gratuito e ilimitado sobre CDN global (Akamai).
- **Paso 1:** Crea un proyecto gratuito en https://sourceforge.net/create (por ejemplo `lfa-ai-os`, licencia `GPLv3`).
- **Paso 2:** Sube la ISO y el `SHA256SUMS-ISO.txt` desde terminal (mucho más rápido y estable que el navegador):
  ```bash
  rsync -avP -e ssh \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/dist/LFA-AI-OS-1.0.0-amd64.iso \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/dist/SHA256SUMS-ISO.txt \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/release-kit/RELEASE-NOTES.md \
    TU_USUARIO_SF@frs.sourceforge.net:/home/frs/project/lfa-ai-os/1.0.0/
  ```
- **Gráficos:** Sube el banner y capturas de `release-kit/graphics/` en la pestaña *Admin → Screenshots* de SourceForge.

---

## 2. Internet Archive (`archive.org`) — Espejo permanente gratuito + Torrent automático
- **Límite:** Gratis, permanente, soporta archivos de 5+ GB y genera automáticamente un archivo `.torrent` para descargas P2P.
- **Subida por CLI (`internetarchive`):**
  ```bash
  uv tool install internetarchive
  ia configure   # Inicia sesión con tu cuenta gratuita de archive.org
  ia upload lfa-ai-os-1.0.0 \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/dist/LFA-AI-OS-1.0.0-amd64.iso \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/dist/SHA256SUMS-ISO.txt \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/release-kit/RELEASE-NOTES.md \
    --metadata="title:LFA AI OS 1.0.0 (KDE Plasma 6 Multi-Agent AI Workstation)" \
    --metadata="mediatype:software" \
    --metadata="creator:LFA Interiors and Construction LLC" \
    --metadata="licenseurl:https://www.gnu.org/licenses/gpl-3.0.html"
  ```

---

## 3. Hugging Face (`huggingface.co`) — Espejo adicional ideal para comunidad IA
- **Límite:** Gratis para repositorios públicos (soporta archivos individuales hasta 50 GB con descarga directa de alta velocidad).
- **Subida por CLI:**
  ```bash
  uv tool install huggingface_hub
  hf auth login
  hf repo create lfa-ai-os --repo-type dataset
  hf upload TU_USUARIO_HF/lfa-ai-os \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/dist/LFA-AI-OS-1.0.0-amd64.iso \
    1.0.0/LFA-AI-OS-1.0.0-amd64.iso --repo-type dataset
  hf upload TU_USUARIO_HF/lfa-ai-os \
    /home/lfaiac/Desktop/APPLFA/LFA-AI-Workstation/dist/SHA256SUMS-ISO.txt \
    1.0.0/SHA256SUMS-ISO.txt --repo-type dataset
  ```

---

## 4. DistroWatch (Directorio / Lista de espera)
- DistroWatch **no aloja ISOs**, pero enlaza tu descarga de SourceForge / Internet Archive.
- Una vez subida la ISO a SourceForge, copia el enlace directo de descarga en `release-kit/DISTROWATCH-SUBMISSION.md` y envíalo a DistroWatch.
