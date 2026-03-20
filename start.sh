#!/bin/bash
set -e
source /venv/main/bin/activate

# --- ТВОИ ПРИВАТНЫЕ ДАННЫЕ ---
GH_TOKEN="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"
HF_TOKEN="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"

MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"
ALLNODES_REPO="https://${GH_TOKEN}@github.com/depersonityhom/depersonity_wf.git"
ALLNODES_BRANCH="main"
# -----------------------------

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR="${WORKSPACE}/ComfyUI"

# Списки моделей из твоего личного HF
CLIP_MODELS=("$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors")
CLIP_VISION_MODELS=("$MY_HF_REPO/clip_vision_h.safetensors")
VAE_MODELS=("$MY_HF_REPO/wan_2.1_vae.safetensors")
CONTROLNET_MODELS=("$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors")
DIFFUSION_MODELS=("$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors")

DETECTION_MODELS=(
    "$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
    "$MY_HF_REPO/yolov10m.onnx"
    "$MY_HF_REPO/vitpose_h_wholebody_data.bin"
    "$MY_HF_REPO/vitpose_h_wholebody_model.onnx"
)

UPSCALER_MODELS=(
    "$MY_HF_REPO/low.pt"
    "$MY_HF_REPO/005_colorDN_DFWB_s128w8_SwinIR-M_noise15.pth"
)

LORAS=(
    "$MY_HF_REPO/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors"
    "$MY_HF_REPO/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
    "$MY_HF_REPO/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors"
    "$MY_HF_REPO/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors"
)

# Переиспользуем функции из оригинала с небольшими правками
function provisioning_get_files() {
    local dir="$1"
    shift
    local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local filename=$(basename "${url%%?*}")
        # Докачка (-c) вместо простого пропуска (-nc)
        wget --header="Authorization: Bearer $HF_TOKEN" -c --content-disposition -P "$dir" "$url" || true
    done
}

# Далее все функции из твоего оригинала (provisioning_start и т.д.)
# Только замени в provisioning_get_nodes клонирование на использование ${ALLNODES_REPO}
