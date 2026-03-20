#!/bin/bash
set -e

# Настройка терминала
export TERM=xterm

# --- ЦВЕТОВАЯ СХЕМА (ANSI) ---
NC='\033[0m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'

# --- ФУНКЦИИ ЛОГИРОВАНИЯ ---
function log_sep() { echo -e "${GRAY}------------------------------------------------------------${NC}"; }

function log_step() {
    echo -e "\n${MAGENTA}───[ STEP $1 ]──────────────────────────────────────────${NC}"
    echo -e "${WHITE}  🚀 $2${NC}"
    log_sep
}

function log_info() { echo -e "${CYAN}[⚡]${NC} ${WHITE}$1${NC}"; }
function log_ok() { echo -e "${GREEN}[✔]${NC} $1"; }
function log_down() { echo -e "${YELLOW}[📥]${NC} Ожидание: ${WHITE}$1${NC}"; }

# --- ПРИКОЛЬНЫЙ СТАРТ ---
clear
echo -e "${CYAN}"
echo "    ██╗    ██╗ █████╗ ███╗   ██╗██████╗     ██████╗ ██████╗ "
echo "    ██║    ██║██╔══██╗████╗  ██║╚════██╗   ██╔═══██╗╚════██╗"
echo "    ██║ █╗ ██║███████║██╔██╗ ██║ █████╔╝   ██║   ██║ █████╔╝"
echo "    ██║███╗██║██╔══██║██║╚██╗██║██╔═══╝    ██║   ██║██╔═══╝ "
echo "    ╚███╔███╔╝██║  ██║██║ ╚████║███████╗██╗╚██████╔╝███████╗"
echo "     ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝ ╚═════╝ ╚══════╝"
echo -e "          ${MAGENTA}>> SYSTEM DEPLOYMENT INITIATED <<${NC}"
log_sep
log_info "GPU Detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)"
log_info "Disk Space: $(df -h /workspace | awk 'NR==2 {print $4}') available"
log_sep

# --- НАСТРОЙКИ ---
HF_TOKEN="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"
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
ALLNODES_REPO="https://github.com/depersonityhom/dep.git"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# --- МОДЕЛИ ---
CLIP_MODELS=("$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors")
CLIP_VISION_MODELS=("$MY_HF_REPO/clip_vision_h.safetensors")
VAE_MODELS=("$MY_HF_REPO/wan_2.1_vae.safetensors")
CONTROLNET_MODELS=("$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors")
DIFFUSION_MODELS=("$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors")
DETECTION_MODELS=("$MY_HF_REPO/yolov10m.onnx" "$MY_HF_REPO/vitpose_h_wholebody_data.bin" "$MY_HF_REPO/vitpose_h_wholebody_model.onnx")
UPSCALER_MODELS=("$MY_HF_REPO/low.pt" "$MY_HF_REPO/005_colorDN_DFWB_s128w8_SwinIR-M_noise15.pth")
LORAS=("$MY_HF_REPO/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" "$MY_HF_REPO/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" "$MY_HF_REPO/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" "$MY_HF_REPO/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors")

# --- УТИЛИТА ЗАГРУЗКИ ---
function download_files() {
    local dir="$1"; shift; local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local fname=$(basename $url)
        log_down "$fname"
        # МЫ ВЕРНУЛИ АВТОРИЗАЦИЮ ЧЕРЕЗ ХЕДЕР
        wget --header="Authorization: Bearer $HF_TOKEN" --show-progress -c --content-disposition -P "$dir" "$url"
        log_ok "$fname успешно загружен."
    done
}

# --- ВЫПОЛНЕНИЕ ---

log_step "01" "ПОДГОТОВКА ЯДРА COMFYUI"
cd "${WORKSPACE}"
if [[ ! -d "ComfyUI" ]]; then
    log_info "Клонирую чистое ядро..."
    git clone https://github.com/comfyanonymous/ComfyUI.git -q
fi
cd ComfyUI
log_ok "Ядро готово."

log_step "02" "УСТАНОВКА КАСТОМНЫХ НОД"
log_info "Загружаю ноды из 'dep'..."
rm -rf custom_nodes/my_nodes
git clone --depth 1 "${ALLNODES_REPO}" custom_nodes/my_nodes -q

log_info "Инсталляция зависимостей..."
find custom_nodes/my_nodes -name requirements.txt -exec pip install --no-cache-dir -q -r {} \;
log_ok "Все ноды настроены и готовы."

log_step "03" "ЗАГРУЗКА ТЯЖЕЛЫХ ВЕСОВ (WAN 2.2)"
download_files "models/clip" "${CLIP_MODELS[@]}"
download_files "models/clip_vision" "${CLIP_VISION_MODELS[@]}"
download_files "models/vae" "${VAE_MODELS[@]}"
download_files "models/controlnet" "${CONTROLNET_MODELS[@]}"
download_files "models/diffusion_models" "${DIFFUSION_MODELS[@]}"
download_files "models/detection" "${DETECTION_MODELS[@]}"
download_files "models/loras" "${LORAS[@]}"
download_files "models/upscale_models" "${UPSCALER_MODELS[@]}"

log_sep
echo -e "${GREEN}  [SYSTEM READY] Код 0: Ошибок нет.${NC}"
echo -e "${CYAN}  Удачной генерации, Константин! Сервер на порту 18188.${NC}"
log_sep

log_step "04" "ЗАПУСК СЕРВЕРА"
python main.py --listen 0.0.0.0 --port 18188 --enable-cors-header
