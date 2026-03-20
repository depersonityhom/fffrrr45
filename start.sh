#!/bin/bash
set -e

# 1. Исправляем терминал, чтобы clear и цвета не ломали скрипт
export TERM=xterm

# --- ЦВЕТА ---
NC='\033[0m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'

function log_header() {
    echo -e "\n${MAGENTA}==================================================${NC}"
    echo -e "${WHITE}  🚀 $1${NC}"
    echo -e "${MAGENTA}==================================================${NC}"
}
function log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
function log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

# --- НАСТРОЙКИ ---
GH_TOKEN="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"
HF_TOKEN="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"
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"

# Склад моделей
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# Твой НОВЫЙ приватный репозиторий с нодами (используем токен в ссылке)
ALLNODES_REPO="https://${GH_TOKEN}@github.com/depersonityhom/depersonity_wf.git"

# --- МОДЕЛИ (WAN 2.2) ---
CLIP_MODELS=("$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors")
CLIP_VISION_MODELS=("$MY_HF_REPO/clip_vision_h.safetensors")
VAE_MODELS=("$MY_HF_REPO/wan_2.1_vae.safetensors")
CONTROLNET_MODELS=("$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors")
DIFFUSION_MODELS=("$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors")
DETECTION_MODELS=("$MY_HF_REPO/yolov10m.onnx" "$MY_HF_REPO/vitpose_h_wholebody_data.bin" "$MY_HF_REPO/vitpose_h_wholebody_model.onnx")
UPSCALER_MODELS=("$MY_HF_REPO/low.pt" "$MY_HF_REPO/005_colorDN_DFWB_s128w8_SwinIR-M_noise15.pth")
LORAS=("$MY_HF_REPO/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" "$MY_HF_REPO/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" "$MY_HF_REPO/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" "$MY_HF_REPO/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors")

# --- УТИЛИТА ЗАГРУЗКИ ---
function provisioning_get_files() {
    local dir="$1"; shift; local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local fname=$(basename $url)
        echo -e "${YELLOW}[DOWNLOADING]${NC} ${WHITE}$fname${NC}"
        wget --header="Authorization: Bearer $HF_TOKEN" -q --show-progress -c --content-disposition -P "$dir" "$url"
        log_success "$fname готов."
    done
}

# --- ПОЕХАЛИ ---

log_header "ШАГ 1: ПОДГОТОВКА ЯДРА COMFYUI"
cd "${WORKSPACE}"
if [[ ! -d "ComfyUI" ]]; then
    log_info "Клонирую ядро..."
    git clone https://github.com/comfyanonymous/ComfyUI.git -q
fi
cd ComfyUI
log_success "Ядро на месте."

log_header "ШАГ 2: ПРИВАТНЫЕ НОДЫ (DEPERSONITY_WF)"
log_info "Клонирую приватный репозиторий через токен..."
rm -rf custom_nodes/my_nodes
git clone --depth 1 "${ALLNODES_REPO}" custom_nodes/my_nodes -q

log_info "Установка зависимостей (pip)..."
find custom_nodes/my_nodes -name requirements.txt -exec pip install --no-cache-dir -r {} \; -q
log_success "Ноды установлены."

log_header "ШАГ 3: ЗАГРУЗКА ВЕСОВ"
provisioning_get_files "models/clip" "${CLIP_MODELS[@]}"
provisioning_get_files "models/clip_vision" "${CLIP_VISION_MODELS[@]}"
provisioning_get_files "models/vae" "${VAE_MODELS[@]}"
provisioning_get_files "models/controlnet" "${CONTROLNET_MODELS[@]}"
provisioning_get_files "models/diffusion_models" "${DIFFUSION_MODELS[@]}"
provisioning_get_files "models/detection" "${DETECTION_MODELS[@]}"
provisioning_get_files "models/loras" "${LORAS[@]}"
provisioning_get_files "models/upscale_models" "${UPSCALER_MODELS[@]}"

log_header "ФИНАЛ: ЗАПУСК"
echo -e "${GREEN}>>> ЗАПУСКАЮ COMFYUI НА ПОРТУ 18188 <<<${NC}"
python main.py --listen 0.0.0.0 --port 18188 --enable-cors-header
