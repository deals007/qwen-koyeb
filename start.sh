#!/bin/bash

# A start script for running ComfyUI with the Qwen‑Image‑2512 model on Koyeb.
#
# This script downloads the required model checkpoints from the
# Hugging Face `Comfy-Org/Qwen-Image_ComfyUI` repository and places them
# in the appropriate directories under `/ComfyUI/models/`.  It then runs
# the ComfyUI server, listening on the port defined by the `PORT` environment
# variable (defaulting to 8188).  You can customise which diffusion model
# variant is downloaded by setting `DIFFUSION_MODEL_PATH` in the
# environment; optionally specify `LORA_PATH` to download the Lightning
# LoRA for accelerated 4‑step inference.

set -euo pipefail

# Determine the port to listen on.  Koyeb automatically provides the
# `PORT` environment variable.  If it is not set, default to 8188.
PORT=${PORT:-8188}

# Repository where the model files are hosted on Hugging Face.  See the
# ComfyUI documentation for details【838579163341816†L197-L233】.
REPO_ID="Comfy-Org/Qwen-Image_ComfyUI"

# File paths within the repository.  These can be overridden using
# environment variables if you prefer alternate variants (for example,
# using the bf16 diffusion model or enabling the Lightning LoRA).  The
# defaults correspond to the recommended fp8 diffusion model and no LoRA.
TEXT_ENCODER_PATH="${TEXT_ENCODER_PATH:-split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors}"
DIFFUSION_MODEL_PATH="${DIFFUSION_MODEL_PATH:-split_files/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors}"
VAE_PATH="${VAE_PATH:-split_files/vae/qwen_image_vae.safetensors}"
# Leave LORA_PATH empty to skip downloading a LoRA.  Set this to
# `split_files/loras/Qwen-Image-Lightning-4steps-V1.0.safetensors` to
# download the Lightning LoRA for 4‑step generation.
LORA_PATH="${LORA_PATH:-}"

# Use huggingface‑hub via Python to download a file.  This helper
# function sets environment variables for the Python snippet so that it
# knows which file and directory to download.
download_model() {
  local hf_filename="$1"
  local model_dir="$2"
  # Skip if no filename was provided
  if [ -z "$hf_filename" ]; then
    return
  fi
  local dest="/ComfyUI/models/${model_dir}/$(basename "$hf_filename")"
  if [ -f "$dest" ]; then
    echo "Model file $dest already exists; skipping download."
    return
  fi
  echo "Downloading $dest from $REPO_ID ..."
  # Export variables so the Python snippet can read them
  export HF_FILENAME="$hf_filename"
  export HF_MODEL_DIR="$model_dir"
  python3 - <<'PY'
import os
from huggingface_hub import hf_hub_download
import pathlib

# Retrieve parameters from environment variables
repo_id = os.environ["REPO_ID"]
filename = os.environ["HF_FILENAME"]
model_dir = os.environ["HF_MODEL_DIR"]
token = os.environ.get("HF_TOKEN")  # optional – if the repo requires authentication

# Ensure the destination directory exists
path = pathlib.Path("/ComfyUI/models/") / model_dir
path.mkdir(parents=True, exist_ok=True)

# Perform the download.  We specify `local_dir` so that the file is
# placed directly in the destination rather than in the cache.  Setting
# `local_dir_use_symlinks=False` avoids creating symlinks, which may not
# survive across deployments.
hf_hub_download(
    repo_id=repo_id,
    filename=filename,
    cache_dir=str(path),
    local_dir=str(path),
    local_dir_use_symlinks=False,
    token=token,
)
PY
}

# Export the repository ID for the Python helper
export REPO_ID

# Download the text encoder, diffusion model, optional LoRA, and VAE.
download_model "$TEXT_ENCODER_PATH" "text_encoders"
download_model "$DIFFUSION_MODEL_PATH" "diffusion_models"
download_model "$LORA_PATH" "loras"
download_model "$VAE_PATH" "vae"

# Optionally download the Qwen‑Image workflow file into /workflows if
# requested.  Providing a workflow file makes it easy to load the
# appropriate nodes in ComfyUI, but it is not required.  Users can
# download the workflow manually from the ComfyUI templates repository.
if [ -n "${DOWNLOAD_WORKFLOW:-}" ]; then
  WORKFLOW_URL="https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/templates/image_qwen_Image_2512.json"
  mkdir -p /workflows
  if [ ! -f /workflows/qwen-image-2512.json ]; then
    echo "Downloading Qwen‑Image‑2512 workflow template ..."
    # Use curl with silent and location flags.  We ignore errors to
    # avoid failing the container start if the download fails.
    curl -L -f -s "$WORKFLOW_URL" -o /workflows/qwen-image-2512.json || true
  fi
fi

# Launch ComfyUI.  We use --listen to bind to all interfaces and the
# computed PORT.  ComfyUI will serve its interface at this port.
cd /ComfyUI
exec python3 main.py --listen 0.0.0.0 --port "$PORT"