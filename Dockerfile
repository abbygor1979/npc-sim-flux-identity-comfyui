FROM runpod/worker-comfyui:5.8.6-base-cuda12.8.1

# Custom nodes for identity-preserving Flux img2img (npc-sim SPEC.md, Flux
# phase). The base worker-comfyui image has no way to add custom nodes via
# its Network Volume (RunPod's own docs: nodes are baked in at build time,
# only *model weights* are volume-mounted) — this image exists only to
# supply those two node packages. Model weights still come from the
# Network Volume (see extra_model_paths.yaml / start-with-volume-nodes.sh
# in this repo), not this image, so it stays small and doesn't need
# rebuilding when a LoRA or checkpoint changes.

WORKDIR /comfyui/custom_nodes

# XLabs-AI/x-flux-comfyui: Flux IP-Adapter (image-prompt conditioning).
# balazik/ComfyUI-PuLID-Flux: PuLID-Flux (face-identity conditioning).
# Both verified to exist and match the weight files already downloaded to
# the Network Volume (pulid_flux_v0.9.1.safetensors, flux-ip-adapter.safetensors)
# before writing this Dockerfile — see each repo's README for the exact
# pretrained-weight filenames this Dockerfile assumes.
RUN git clone --depth 1 https://github.com/XLabs-AI/x-flux-comfyui.git && \
    git clone --depth 1 https://github.com/balazik/ComfyUI-PuLID-Flux.git

# The base image (runpod-workers/worker-comfyui) creates a venv at
# /opt/venv and puts it on PATH — but never sets VIRTUAL_ENV, which is what
# `uv pip install`'s own active-venv detection actually keys on. Without an
# explicit target, `uv` doesn't recognise /opt/venv as active and installs
# into some other environment ComfyUI's own runtime (started via
# /opt/venv's python, per that image's own start.sh) never sees — confirmed
# live twice: once with no flags (isightface not found), once again with
# --system --break-system-packages (targets the OS's system Python instead
# of /opt/venv — same wrong destination, different one). `--python` names
# the interpreter directly and removes the ambiguity entirely.
RUN uv pip install --python /opt/venv/bin/python -r x-flux-comfyui/requirements.txt && \
    uv pip install --python /opt/venv/bin/python -r ComfyUI-PuLID-Flux/requirements.txt

# XLabs' own installer creates its models/xlabs/* folders and does a couple
# of environment checks; run it the way the README documents rather than
# only relying on the package import succeeding.
RUN cd x-flux-comfyui && /opt/venv/bin/python setup.py

WORKDIR /comfyui

# Adds a `pulid:` model folder (-> Network Volume's models/pulid/) on top
# of the base image's own checkpoints/clip/vae/unet/loras/etc. mapping —
# see that file for why this one entry is the only addition: PuLID's own
# node code falls back to ComfyUI's normal folder_paths resolution, so it
# picks up the extra_model_paths.yaml entry the same way the built-in
# folders already do. XLabs' IP-Adapter and PuLID's InsightFace/EVA-CLIP
# weights do NOT go through folder_paths/extra_model_paths at all — both
# hardcode a path under ComfyUI's own models_dir, which is why those three
# are symlinked in from the volume at container start instead (see
# start-with-volume-nodes.sh), not listed here.
COPY extra_model_paths.yaml ./

WORKDIR /
COPY start-with-volume-nodes.sh /start-with-volume-nodes.sh
RUN chmod +x /start-with-volume-nodes.sh

CMD ["/start-with-volume-nodes.sh"]
