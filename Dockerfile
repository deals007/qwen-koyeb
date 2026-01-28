FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

SHELL ["/bin/bash", "-lc"]

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    COMFYUI_DIR=/opt/ComfyUI

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    python3 python3-pip python3-venv \
    libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_DIR}

WORKDIR ${COMFYUI_DIR}

# Torch CUDA 12.1 wheels
RUN python3 -m pip install --upgrade pip wheel setuptools \
 && python3 -m pip install --index-url https://download.pytorch.org/whl/cu121 \
      torch torchvision torchaudio \
 && python3 -m pip install -r requirements.txt

# Optional but useful
RUN mkdir -p ${COMFYUI_DIR}/custom_nodes \
 && git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
      ${COMFYUI_DIR}/custom_nodes/ComfyUI-Manager

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188
CMD ["/start.sh"]
