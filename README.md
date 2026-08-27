# npc-sim-flux-identity-comfyui

`runpod/worker-comfyui:5.8.6-base-cuda12.8.1` plus two custom ComfyUI node
packages needed for identity-preserving Flux img2img:

- [XLabs-AI/x-flux-comfyui](https://github.com/XLabs-AI/x-flux-comfyui) — Flux IP-Adapter
- [balazik/ComfyUI-PuLID-Flux](https://github.com/balazik/ComfyUI-PuLID-Flux) — PuLID-Flux

Built for [npc-sim](../npc-sim)'s Flux pipeline (see `SPEC.md`, Flux phase).
Custom nodes can't be added to `worker-comfyui` via its Network Volume —
RunPod only volume-mounts model weights, not code — so this repo exists
purely to bake those two node packages into an image; weights (including
the two model files these nodes need themselves) still live on the
Network Volume and get symlinked into place at container start by
`start-with-volume-nodes.sh`, since both nodes hardcode a path under
ComfyUI's own `models_dir` instead of going through
`extra_model_paths.yaml` the way checkpoints/loras/vae do.

## Model files this image expects on the mounted Network Volume

- `models/pulid/pulid_flux_v0.9.1.safetensors` (via `extra_model_paths.yaml`)
- `models/ipadapter/flux-ip-adapter.safetensors` (XLabs-AI, symlinked at start)
- `models/clip_vision/model.safetensors` (OpenAI CLIP ViT-L/14, via `extra_model_paths.yaml`)
- `models/clip/EVA02_CLIP_L_336_psz14_s6B.pt` (symlinked at start into PuLID's eva_clip cache dir)
- `models/insightface/antelopev2/` (unzipped AntelopeV2, symlinked at start)

GitHub Actions builds and pushes to `ghcr.io/abbygor1979/npc-sim-flux-identity-comfyui:latest` on every push to `main`.
