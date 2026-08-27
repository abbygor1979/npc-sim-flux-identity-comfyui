#!/bin/bash
set -e

# XLabs' IP-Adapter and PuLID's InsightFace/EVA-CLIP weights are read from
# paths hardcoded under ComfyUI's own models_dir (x-flux-comfyui/nodes.py,
# ComfyUI-PuLID-Flux/pulidflux.py) — they do NOT go through
# folder_paths/extra_model_paths.yaml the way checkpoints/loras/pulid do.
# So the actual files live once on the Network Volume (cheap to update,
# doesn't require rebuilding this image) and get symlinked into the
# hardcoded locations here, at container start, before ComfyUI itself
# imports those nodes.
mkdir -p /comfyui/models/xlabs/ipadapters
mkdir -p /comfyui/models/insightface/models/antelopev2
mkdir -p ~/.cache/clip

link() {
  if [ -e "$1" ]; then
    ln -sf "$1" "$2"
  else
    echo "start-with-volume-nodes.sh: missing $1 (identity features needing it will fail, not the whole worker)" >&2
  fi
}

link /runpod-volume/models/ipadapter/flux-ip-adapter.safetensors /comfyui/models/xlabs/ipadapters/flux-ip-adapter.safetensors
link /runpod-volume/models/clip_vision/model.safetensors /comfyui/models/clip_vision/model.safetensors
link /runpod-volume/models/clip/EVA02_CLIP_L_336_psz14_s6B.pt ~/.cache/clip/EVA02_CLIP_L_336_psz14_s6B.pt

if [ -d /runpod-volume/models/insightface/antelopev2 ]; then
  rmdir /comfyui/models/insightface/models/antelopev2 2>/dev/null || true
  ln -sfn /runpod-volume/models/insightface/antelopev2 /comfyui/models/insightface/models/antelopev2
else
  echo "start-with-volume-nodes.sh: missing /runpod-volume/models/insightface/antelopev2 (PuLID face analysis will fail, not the whole worker)" >&2
fi

# Diagnostic, 2026-08-27: insightface installs cleanly into /opt/venv at
# build time (confirmed in the build log) but PuLID-Flux still fails to
# import it at container start — this checks what python/PATH actually look
# like in the running container itself, not at build time, to find out why.
echo "start-with-volume-nodes.sh: PATH=$PATH" >&2
echo "start-with-volume-nodes.sh: which python -> $(which python)" >&2
python -c "import sys; print('start-with-volume-nodes.sh: sys.executable ->', sys.executable, file=sys.stderr)" || true
python -c "import insightface; print('start-with-volume-nodes.sh: insightface OK ->', insightface.__file__, file=sys.stderr)" \
  || echo "start-with-volume-nodes.sh: insightface import FAILED under $(which python)" >&2

exec /start.sh
