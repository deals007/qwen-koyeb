#!/usr/bin/env bash
set -euo pipefail

COMFYUI_DIR="/opt/ComfyUI"
PORT="${PORT:-8188}"

# ---- Qwen-Image-2511 model files ----
TEXT_ENCODER_NAME="qwen_2.5_vl_7b_fp8_scaled.safetensors"
TEXT_ENCODER_URL="https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"

DIFFUSION_NAME="qwen_image_edit_2511_bf16.safetensors"
DIFFUSION_URL="https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_bf16.safetensors"

VAE_NAME="qwen_image_vae.safetensors"
VAE_URL="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

LORA_NAME="Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
LORA_URL="https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"

# ---- ComfyUI model directories (these are the expected locations) ----
TEXT_DIR="${COMFYUI_DIR}/models/text_encoders"
DIFF_DIR="${COMFYUI_DIR}/models/diffusion_models"
VAE_DIR="${COMFYUI_DIR}/models/vae"
LORA_DIR="${COMFYUI_DIR}/models/loras"

mkdir -p "${TEXT_DIR}" "${DIFF_DIR}" "${VAE_DIR}" "${LORA_DIR}"

# Robust download helper (handles HF_TOKEN + avoids tiny HTML "downloads")
download_file () {
  local out_path="$1"
  local url="$2"
  local min_bytes="$3"

  # If file exists and looks OK, skip
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

cd "${COMFYUI_DIR}"

# Start downloads in background so Koyeb can see the port quickly.
# Min sizes are sanity checks (tune if you want).
download_file "${TEXT_DIR}/${TEXT_ENCODER_NAME}" "${TEXT_ENCODER_URL}" 1000000000 &   # ~9.38GB real
download_file "${DIFF_DIR}/${DIFFUSION_NAME}"     "${DIFFUSION_URL}"     5000000000 &   # ~20GB real
download_file "${VAE_DIR}/${VAE_NAME}"            "${VAE_URL}"           200000000 &    # VAE is large
download_file "${LORA_DIR}/${LORA_NAME}"          "${LORA_URL}"          5000000 &      # LoRA smaller

# Start ComfyUI immediately (health check passes)
exec python3 main.py \
  --listen 0.0.0.0 \
  --port "${PORT}" \
  --disable-auto-launch
