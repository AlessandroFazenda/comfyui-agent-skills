#!/bin/bash
# Provisions ComfyUI + MiniMax H3 (ref2va/fl2va turbo int8) + SeedVR2 on a Vast.ai instance.
# Tested on an RTX 3090 (driver 560 / CUDA 12.6): ~7 min, ~56 GB downloaded.
# On that driver (CUDA 12.6) the int8_convrot video VAE failed (comfy_kitchen kernel); fp16 worked.
# Usage: bash provision_h3.sh   (idempotent: can be rerun; skips whatever already exists)
set -uo pipefail
W=${W:-/workspace}; mkdir -p "$W"; C=$W/ComfyUI; LOG=$W/provision.log
exec > >(tee -a "$LOG") 2>&1
t0=$(date +%s); echo "[prov] start $(date -u)"
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv,noheader
PY=/venv/main/bin/python; [ -x "$PY" ] || PY=$(command -v python3)  # vastai/pytorch images use /venv/main
echo "[prov] python: $PY ($($PY -V 2>&1))"
command -v ffmpeg >/dev/null || { apt-get update -qq && apt-get install -y -qq ffmpeg >/dev/null; }

# 1. ComfyUI (latest; H3 needs >= 0.40)
if [ -d "$C/.git" ]; then git -C "$C" pull -q; else git clone -q --depth 1 https://github.com/comfyanonymous/ComfyUI "$C"; fi
$PY -m pip install -q -r "$C/requirements.txt"
$PY -m pip install -q -U "huggingface_hub[hf_xet]"
echo "[prov] ComfyUI $(git -C "$C" describe --tags --always 2>/dev/null)  torch $($PY -c 'import torch;print(torch.__version__, torch.version.cuda)')"

# 2. Models (repo | file name | folder under models/ | required)
cat > $W/models.txt <<'M'
MATLOWAI/minimax-h3-fused-turbo-int8-convrot|minimax_h3_fused_refdelta_r1024_turbo8_mystic07_int8_convrot.safetensors|diffusion_models|1
Comfy-Org/MiniMax-H3|qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors|text_encoders|1
Comfy-Org/MiniMax-H3|minimax_h3_audio_vae_fp32.safetensors|vae|1
Comfy-Org/MiniMax-H3|minimax_h3_video_vae_int8_convrot.safetensors|vae|0
Comfy-Org/MiniMax-H3|minimax_h3_video_vae_fp16.safetensors|vae|0
Comfy-Org/SeedVR2|seedvr2_7b_int8_convrot.safetensors|diffusion_models|0
Comfy-Org/SeedVR2|seedvr2_ema_vae_fp16.safetensors|vae|0
M
HF_XET_HIGH_PERFORMANCE=1 $PY - "$C" "$W/models.txt" <<'P'
import os, sys, shutil, time
from huggingface_hub import list_repo_files, hf_hub_download
C, listing = sys.argv[1], sys.argv[2]
cache, missing = {}, []
for line in open(listing):
    repo, name, folder, required = line.strip().split("|")
    dest = os.path.join(C, "models", folder, name)
    if os.path.exists(dest):
        print(f"[prov] ok (already exists) {name}"); continue
    if repo not in cache:
        try: cache[repo] = list_repo_files(repo)
        except Exception as e: cache[repo] = []; print(f"[prov] ERROR listing {repo}: {e}")
    found = [f for f in cache[repo] if f.split("/")[-1] == name]
    if not found:
        print(f"[prov] {'MISSING' if required == '1' else 'warning: not found'} {name} in {repo}")
        if required == "1": missing.append(name)
        continue
    t = time.time()
    p = hf_hub_download(repo, found[0], local_dir=os.path.join(os.path.dirname(C), "hf_tmp"))
    os.makedirs(os.path.dirname(dest), exist_ok=True); shutil.move(p, dest)
    print(f"[prov] downloaded {name} ({os.path.getsize(dest)/1e9:.1f} GB in {time.time()-t:.0f}s)")
if missing: print("[prov] FAILED, missing:", missing); sys.exit(1)
P
rc=$?; rm -rf $W/hf_tmp
[ $rc -ne 0 ] && { echo "[prov] ERROR in models"; exit 1; }

# 3. Start ComfyUI on localhost only (access through an SSH tunnel)
pkill -f "ComfyUI/main.py" 2>/dev/null; sleep 1
nohup $PY "$C/main.py" --listen 127.0.0.1 --port 8188 > $W/comfy.log 2>&1 &
for i in $(seq 1 120); do curl -sf http://127.0.0.1:8188/system_stats >/dev/null && break; sleep 2; done
curl -sf http://127.0.0.1:8188/object_info/MiniMaxH3ReferenceToVideo | grep -q MiniMaxH3ReferenceToVideo \
  && echo "[prov] ComfyUI up with H3 nodes" || { echo "[prov] ERROR: ComfyUI without the H3 node"; tail -30 $W/comfy.log; exit 1; }
df -h $W | tail -1
echo "[prov] READY in $(( ($(date +%s)-t0)/60 )) min"
