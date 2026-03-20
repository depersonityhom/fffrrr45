#!/bin/bash
set -e
source /venv/main/bin/activate

# --- ЦВЕТА ДЛЯ ЛОГОВ ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

function log_info() { echo -e "${BLUE}[INFO] $(date +%T) - $1${NC}"; }
function log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }

# --- НАСТРОЙКИ ---
GH_TOKEN="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"
HF_TOKEN="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"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# --- ФУНКЦИЯ ЗАГРУЗКИ ---
function provisioning_get_files() {
    local dir="$1"
    shift
    local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local filename=$(basename "${url%%?*}")
        if [[ -f "${dir}/${filename}" ]] && [[ $(stat -c%s "${dir}/${filename}") -gt 1000000 ]]; then
            echo -e "  ✅ $filename уже на месте. Пропускаю."
            continue
        fi
        echo -e "  📥 Загрузка: ${GREEN}$filename${NC}"
        wget --header="Authorization: Bearer $HF_TOKEN" -q --show-progress -c --content-disposition -P "$dir" "$url"
    done
}

# --- ОСНОВНОЙ ПРОЦЕСС ---
clear
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}    ЗАПУСК АВТОНОМНОЙ УСТАНОВКИ COMFYUI          ${NC}"
echo -e "${BLUE}==================================================${NC}"

log_info "Шаг 1: Проверка ядра ComfyUI..."
if [[ ! -d "/workspace/ComfyUI" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
else
    cd /workspace/ComfyUI && git pull
fi
cd /workspace/ComfyUI

log_info "Шаг 2: Установка/обновление зависимостей..."
pip install --no-cache-dir -r requirements.txt -q

log_info "Шаг 3: Обновление кастомных нод и их зависимостей..."
rm -rf custom_nodes
git clone --depth 1 "https://${GH_TOKEN}@github.com/depersonityhom/fffrrr45.git" custom_nodes -q
# Авто-установка зависимостей для каждой подпапки в custom_nodes
find custom_nodes -type f -name requirements.txt -exec pip install --no-cache-dir -r {} \; -q
log_success "Ноды и их зависимости готовы."

log_info "Шаг 4: Загрузка моделей из твоего HF..."

# Раскладываем всё по полочкам
provisioning_get_files "models/clip" "$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
provisioning_get_files "models/clip_vision" "$MY_HF_REPO/clip_vision_h.safetensors"
provisioning_get_files "models/vae" "$MY_HF_REPO/wan_2.1_vae.safetensors"
provisioning_get_files "models/controlnet" "$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors"
provisioning_get_files "models/diffusion_models" "$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"

provisioning_get_files "models/detection" \
    "$MY_HF_REPO/yolov10m.onnx" \
    "$MY_HF_REPO/vitpose_h_wholebody_data.bin" \
    "$MY_HF_REPO/vitpose_h_wholebody_model.onnx"

provisioning_get_files "models/upscale_models" \
    "$MY_HF_REPO/low.pt" \
    "$MY_HF_REPO/005_colorDN_DFWB_s128w8_SwinIR-M_noise15.pth"

provisioning_get_files "models/loras" \
    "$MY_HF_REPO/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
    "$MY_HF_REPO/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
    "$MY_HF_REPO/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" \
    "$MY_HF_REPO/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors"

log_success "Все модели проверены/загружены."

log_info "Запуск сервера..."
python main.py --listen 0.0.0.0 --port 8188
