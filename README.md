# Qwen‑Image‑2512 on Koyeb

This repository contains a lightweight setup to run the **Qwen‑Image‑2512** model
with [ComfyUI](https://github.com/comfyanonymous/ComfyUI) on a Koyeb GPU
instance.  It provides a `Dockerfile` to build a container that installs
ComfyUI with GPU support and a `start.sh` script that downloads the required
model checkpoints from Hugging Face and launches ComfyUI.

## Prerequisites

- **Koyeb account:** You need an account on Koyeb with access to GPU
  instances.
- **GitHub repository:** Fork or push this repository to your own GitHub
  account so that Koyeb can build and deploy it.
- **Hugging Face access token (optional):** The Qwen‑Image model files live in
  the `Comfy-Org/Qwen-Image_ComfyUI` repository.  If the model is
  restricted, set the `HF_TOKEN` environment variable to a Hugging Face
  access token in your Koyeb service so the start script can authenticate
  when downloading the files.

## Repository structure

| File/Folder      | Purpose                                                                                                      |
|------------------|--------------------------------------------------------------------------------------------------------------|
| `Dockerfile`     | Defines the container image.  It clones ComfyUI, installs dependencies, copies the start script, and uses it as the entry point. |
| `start.sh`       | Bash script executed on container startup.  It downloads the Qwen‑Image model components using `huggingface‑hub` and runs the ComfyUI server. |
| `workflows/`     | Empty directory where you can place workflow JSON files.  You can download the Qwen‑Image‑2512 workflow template here or let the start script fetch it by setting `DOWNLOAD_WORKFLOW=1`. |
| `README.md`      | This documentation file.                                                                                    |

## Model components

According to the ComfyUI documentation, the Qwen‑Image‑2512 model consists of several
files stored under specific subdirectories【838579163341816†L197-L233】:

- **Text encoder:** `qwen_2.5_vl_7b_fp8_scaled.safetensors`
- **Diffusion models:** `qwen_image_2512_fp8_e4m3fn.safetensors` (recommended) and
  `qwen_image_2512_bf16.safetensors` (better quality but requires more VRAM)
- **VAE:** `qwen_image_vae.safetensors`
- **LoRA (optional):** `Qwen-Image-Lightning-4steps-V1.0.safetensors` for accelerated 4‑step inference

The `start.sh` script downloads these files into the proper subdirectories under
`/ComfyUI/models/`, replicating the structure described in the documentation【838579163341816†L197-L233】.  You can override which diffusion model or LoRA to download using environment variables (see below).

## Configuration via environment variables

The following environment variables can be set in your Koyeb service to
customise the deployment:

| Variable              | Description                                                                                               | Default |
|-----------------------|-----------------------------------------------------------------------------------------------------------|---------|
| `PORT`                | Port on which ComfyUI listens.  Koyeb automatically sets this, but you may override it if needed.         | `8188` |
| `HF_TOKEN`            | Hugging Face access token used to authenticate downloads of model files.                                  | unset   |
| `TEXT_ENCODER_PATH`   | Path to the text encoder file within the model repository.                                                 | `split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors` |
| `DIFFUSION_MODEL_PATH`| Path to the diffusion model file.  Set to `split_files/diffusion_models/qwen_image_2512_bf16.safetensors` to use the bf16 variant. | `split_files/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors` |
| `VAE_PATH`            | Path to the VAE file.                                                                                      | `split_files/vae/qwen_image_vae.safetensors` |
| `LORA_PATH`           | Path to the LoRA file.  Set to `split_files/loras/Qwen-Image-Lightning-4steps-V1.0.safetensors` to enable Lightning LoRA. Leave empty to disable. | unset |
| `DOWNLOAD_WORKFLOW`   | If set to any value, the start script attempts to download the Qwen‑Image‑2512 workflow JSON into `/workflows/qwen-image-2512.json`. | unset |

## Deployment instructions

1. **Fork and push**: Fork this repository or copy it into your own GitHub account.
2. **Create a new service** on Koyeb: In the Koyeb dashboard, click **Deploy** and choose **GitHub** as the source.  Select your repository and choose a GPU‑capable instance type.
3. **Configure environment variables:** In the service settings:
   - Set `HF_TOKEN` with your Hugging Face access token if required.
   - Optionally set `DIFFUSION_MODEL_PATH`, `LORA_PATH`, or other variables to customise the model variant.
   - Koyeb automatically sets the `PORT` variable; no action is needed.
4. **Deploy:** Koyeb will build the Docker image, download the model files at runtime using `start.sh`, and start ComfyUI.
5. **Access the UI:** After the deployment succeeds, open the service URL provided by Koyeb to access the ComfyUI web interface.  You can load the Qwen‑Image‑2512 workflow by dragging the JSON file into the interface or by downloading it via ComfyUI’s workflow templates.

## Notes

- This setup follows the official ComfyUI recommendation for storing model files【838579163341816†L197-L233】.
- Downloading the model checkpoints may take several minutes on the first run.  Subsequent deployments reuse the cached files if they are present.
- If the Hugging Face repository is gated, you must provide a valid `HF_TOKEN` with permission to download the files.
- The LoRA component is optional.  Without it, ComfyUI performs 50‑step generation.  With the Lightning LoRA enabled, you can experiment with 4‑step generation for faster results.

## Credits

This repository is based on the ComfyUI Qwen‑Image‑2512 workflow and the Koyeb GPU deployment tutorials.  For more information about the model and its capabilities, see the ComfyUI documentation【838579163341816†L197-L233】.