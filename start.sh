#!/bin/bash
set -e

# --- ЦВЕТА ДЛЯ ЛОГОВ ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}    СКРИПТ ЗАПУЩЕН (VAST.AI COMFY MODE)         ${NC}"
echo -e "${BLUE}==================================================${NC}"

# --- ПЕРЕМЕННЫЕ ---
GH_TOKEN="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"
HF_TOKEN="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"
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# Репозиторий с твоими нодами
ALLNODES_REPO="https://${GH_TOKEN}@github.com/depersonityhom/fffrrr45.git"

# --- СПИСКИ МОДЕЛЕЙ ---
CLIP_MODELS=("$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors")
CLIP_VISION_MODELS=("$MY_HF_REPO/clip_vision_h.safetensors")
VAE_MODELS=("$MY_HF_REPO/wan_2.1_vae.safetensors")
CONTROLNET_MODELS=("$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors")
DIFFUSION_MODELS=("$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors")

DETECTION_MODELS=(
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

# --- ФУНКЦИИ ---
function log_step() {
    echo -e "\n\033[0;34m==================================================\033[0m"
    echo -e "\033[0;32m$1\033[0m"
    echo -e "\033[0;34m==================================================\033[0m"
}

function provisioning_get_files() {
    if [[ $# -lt 2 ]]; then return; fi
    local dir="$1"
    shift
    local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local filename=$(basename "${url%%?*}")
        echo -e "📥 Загрузка $filename..."
        wget --header="Authorization: Bearer $HF_TOKEN" -q --show-progress -c --content-disposition -P "$dir" "$url" || true
    done
}

# --- ОСНОВНОЙ ПРОЦЕСС ---

log_step "STEP 1: Проверка ядра ComfyUI"
if [[ ! -d "${COMFYUI_DIR}" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
fi
cd "${COMFYUI_DIR}"

log_step "STEP 2: Обновление библиотек для Wan 2.2"
# Обновляем самое важное, чтобы новые модели не выдавали ошибку
pip install --no-cache-dir transformers accelerate diffusers --upgrade -q
pip install --no-cache-dir -r requirements.txt -q

log_step "STEP 3: Установка твоих нод"
# Удаляем только ТВОЮ папку нод, если она была, а не всё подряд
rm -rf custom_nodes/my_nodes
git clone --depth 1 "${ALLNODES_REPO}" custom_nodes/my_nodes -q

echo "Установка зависимостей для твоих нод..."
find custom_nodes/my_nodes -type f -name requirements.txt -exec pip install --no-cache-dir -r {} \; -q

log_step "STEP 4: Загрузка всех моделей"
provisioning_get_files "models/clip" "${CLIP_MODELS[@]}"
provisioning_get_files "models/clip_vision" "${CLIP_VISION_MODELS[@]}"
provisioning_get_files "models/vae" "${VAE_MODELS[@]}"
provisioning_get_files "models/controlnet" "${CONTROLNET_MODELS[@]}"
provisioning_get_files "models/diffusion_models" "${DIFFUSION_MODELS[@]}"
provisioning_get_files "models/detection" "${DETECTION_MODELS[@]}"
provisioning_get_files "models/loras" "${LORAS[@]}"
provisioning_get_files "models/upscale_models" "${UPSCALER_MODELS[@]}"

log_step "PROVISIONING COMPLETE"

# Запуск на порту 18188 как в темплейте
echo -e "${GREEN}Запускаю сервер на порту 18188...${NC}"
python main.py --listen 0.0.0.0 --port 18188 --enable-cors-header
