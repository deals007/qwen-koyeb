# Use the official Python base image
FROM python:3.12

# Install git so we can clone ComfyUI
RUN apt-get update \
    && apt-get install -y git \
    && rm -rf /var/lib/apt/lists/*

# Clone the ComfyUI repository into /ComfyUI.  Using a fixed path makes it
# easier to locate model directories later on.
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /ComfyUI

# Set the working directory inside the container to the ComfyUI repo
WORKDIR /ComfyUI

# Upgrade pip, install GPU‑enabled PyTorch and other dependencies defined by
# ComfyUI.  We also install huggingface‑hub so we can download model
# checkpoints at runtime.
RUN pip install --upgrade pip \
    && pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121 \
    && pip install -r requirements.txt \
    && pip install huggingface-hub

# Copy the start script into the container.  This script will download the
# Qwen‑Image model files and start the ComfyUI server.  We also copy the
# workflows folder to make it possible to include workflow templates in the
# repository (optional).
COPY start.sh /start.sh
COPY workflows /workflows

# Make sure the start script is executable
RUN chmod +x /start.sh

# Expose the default ComfyUI port.  Koyeb will provide PORT as an
# environment variable and expects the process to listen on that port.  If
# PORT is not set, ComfyUI will use the default 8188.
EXPOSE 8188

# Run the start script on container startup
ENTRYPOINT ["/start.sh"]