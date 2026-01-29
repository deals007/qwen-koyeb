#!/usr/bin/env bash
set -euo pipefail

COMFYUI_DIR="/opt/ComfyUI"
PORT="${PORT:-8188}"

# Toggle optional face pipeline nodes (Impact Pack)
# Set ENABLE_FACE_PIPELINE=1 in Koyeb env vars if you want it.
ENABLE_FACE_PIPELINE="${ENABLE_FACE_PIPELINE:-0}"

# ---- Qwen-Image-Edit-2511 model files ----
TEXT_ENCODER_NAME="qwen_2.5_vl_7b_fp8_scaled.safetensors"
TEXT_ENCODER_URL="https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"

DIFFUSION_NAME="qwen_image_edit_2511_bf16.safetensors"
DIFFUSION_URL="https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_bf16.safetensors"

VAE_NAME="qwen_image_vae.safetensors"
VAE_URL="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

LORA_NAME="Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
LORA_URL="https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"

# ---- ComfyUI model directories ----
TEXT_DIR="${COMFYUI_DIR}/models/text_encoders"
DIFF_DIR="${COMFYUI_DIR}/models/diffusion_models"
VAE_DIR="${COMFYUI_DIR}/models/vae"
LORA_DIR="${COMFYUI_DIR}/models/loras"

mkdir -p "${TEXT_DIR}" "${DIFF_DIR}" "${VAE_DIR}" "${LORA_DIR}"

# ---- Workflow directories ----
WORKFLOWS_DIR="${COMFYUI_DIR}/user/default/workflows"
mkdir -p "${WORKFLOWS_DIR}"

# ---- Custom nodes ----
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"
mkdir -p "${CUSTOM_NODES_DIR}"

# Robust download helper (HF_TOKEN supported + avoids tiny HTML "downloads")
download_file () {
  local out_path="$1"
  local url="$2"
  local min_bytes="$3"

  if [ -f "${out_path}" ]; then
    local existing_bytes
    existing_bytes=$(stat -c%s "${out_path}" 2>/dev/null || echo 0)
    if [ "${existing_bytes}" -ge "${min_bytes}" ]; then
      echo "OK: ${out_path} already present (${existing_bytes} bytes)"
      return 0
    fi
    echo "WARN: ${out_path} too small (${existing_bytes} bytes) -> re-download"
    rm -f "${out_path}"
  fi

  local auth_header=()
  if [ -n "${HF_TOKEN:-}" ]; then
    auth_header=(-H "Authorization: Bearer ${HF_TOKEN}")
  fi

  echo "Downloading -> ${out_path}"
  rm -f "${out_path}.partial"

  curl -fL \
    --retry 12 --retry-delay 5 --connect-timeout 30 \
    -H "User-Agent: Mozilla/5.0" \
    -H "Accept: application/octet-stream" \
    "${auth_header[@]}" \
    -o "${out_path}.partial" \
    "${url}"

  local bytes
  bytes=$(stat -c%s "${out_path}.partial" 2>/dev/null || echo 0)
  echo "Downloaded bytes: ${bytes} (${out_path})"

  if [ "${bytes}" -lt "${min_bytes}" ]; then
    echo "ERROR: ${out_path} download too small (likely HTML/403/429). First 300 bytes:"
    head -c 300 "${out_path}.partial" || true
    return 1
  fi

  mv "${out_path}.partial" "${out_path}"
  echo "Done: ${out_path}"
}

ensure_repo () {
  local url="$1"
  local dir="$2"

  if [ ! -d "${dir}/.git" ]; then
    echo "Cloning ${url} -> ${dir}"
    git clone --depth 1 "${url}" "${dir}"
  else
    echo "Updating ${dir}"
    git -C "${dir}" pull --rebase || true
  fi
}

install_reqs () {
  local req="$1"
  if [ -f "${req}" ]; then
    echo "Installing requirements: ${req}"
    python3 -m pip install -r "${req}" || true
  fi
}

download_workflow () {
  local url="$1"
  local out="$2"
  if [ ! -f "${out}" ]; then
    echo "Downloading workflow -> ${out}"
    curl -fL --retry 8 --retry-delay 3 -o "${out}" "${url}"
  else
    echo "Workflow exists: ${out}"
  fi
}

cd "${COMFYUI_DIR}"

# -----------------------------
# 1) Install custom nodes you want
# -----------------------------
ensure_repo "https://github.com/kijai/ComfyUI-KJNodes" "${CUSTOM_NODES_DIR}/ComfyUI-KJNodes"
install_reqs "${CUSTOM_NODES_DIR}/ComfyUI-KJNodes/requirements.txt"

ensure_repo "https://github.com/rgthree/rgthree-comfy" "${CUSTOM_NODES_DIR}/rgthree-comfy"
install_reqs "${CUSTOM_NODES_DIR}/rgthree-comfy/requirements.txt"

# Optional: Face-detail pipeline nodes
if [ "${ENABLE_FACE_PIPELINE}" = "1" ]; then
  ensure_repo "https://github.com/ltdrdata/ComfyUI-Impact-Pack" "${CUSTOM_NODES_DIR}/ComfyUI-Impact-Pack"
  install_reqs "${CUSTOM_NODES_DIR}/ComfyUI-Impact-Pack/requirements.txt"

  ensure_repo "https://github.com/ltdrdata/ComfyUI-Impact-Subpack" "${CUSTOM_NODES_DIR}/ComfyUI-Impact-Subpack"
  install_reqs "${CUSTOM_NODES_DIR}/ComfyUI-Impact-Subpack/requirements.txt"
fi

# -----------------------------
# 2) Download workflows (auto)
# -----------------------------
# Official Qwen-Image-Edit-2511 template workflow (from docs.comfy.org)
QWEN_2511_TEMPLATE_URL="https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/templates/image_qwen_image_edit_2511.json"
download_workflow "${QWEN_2511_TEMPLATE_URL}" "${WORKFLOWS_DIR}/qwen-2511.json"

# Your requested AxiomGraph inpainting workflow
AXIOM_INPAINT_URL="https://raw.githubusercontent.com/axiomgraph/ComfyUIWorkflow/main/Qwen%20Image%20Edit%202511%20Inpainting%203.0.json"
download_workflow "${AXIOM_INPAINT_URL}" "${WORKFLOWS_DIR}/qwen-2511-inpaint.json"

# -----------------------------
# 3) Download models (background so port comes up fast)
# -----------------------------
download_file "${TEXT_DIR}/${TEXT_ENCODER_NAME}" "${TEXT_ENCODER_URL}" 1000000000 &   # big
download_file "${DIFF_DIR}/${DIFFUSION_NAME}"     "${DIFFUSION_URL}"     5000000000 &   # very big
download_file "${VAE_DIR}/${VAE_NAME}"            "${VAE_URL}"           200000000 &    # large
download_file "${LORA_DIR}/${LORA_NAME}"          "${LORA_URL}"          5000000 &      # smaller

# -----------------------------
# 4) Start ComfyUI
# -----------------------------
exec python3 main.py \
  --listen 0.0.0.0 \
  --port "${PORT}" \
  --disable-auto-launch
