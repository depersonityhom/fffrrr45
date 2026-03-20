#!/bin/bash
# Заставляем вывод быть мгновенным (unbuffered)
exec > >(stdbuf -oL tee -a /workspace/setup_log.txt) 2>&1
set -e

# --- ЦВЕТА ---
NC='\033[0m'; RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'

function log_header() {
    echo -e "\n${MAGENTA}==================================================${NC}"
    echo -e "${WHITE}  🚀 $1${NC}"
    echo -e "${MAGENTA}==================================================${NC}"
}
function log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
function log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

# --- ПРОВЕРКА ЖЕЛЕЗА (чтобы сразу видеть, на чем стоим) ---
clear
echo -e "${CYAN}Инициализация системы...${NC}"
log_info "Проверка диска:"
df -h /workspace | grep /workspace || echo "Не удалось определить место"
log_info "Проверка GPU:"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || echo "GPU не найден!"

# --- НАСТРОЙКИ ---
GH_TOKEN="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"
HF_TOKEN="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"
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"
ALLNODES_REPO="https://${GH_TOKEN}@github.com/depersonityhom/fffrrr45.git"

# --- МОДЕЛИ (Короткие списки для теста) ---
CLIP_MODELS=("$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors")
CLIP_VISION_MODELS=("$MY_HF_REPO/clip_vision_h.safetensors")
VAE_MODELS=("$MY_HF_REPO/wan_2.1_vae.safetensors")
CONTROLNET_MODELS=("$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors")
DIFFUSION_MODELS=("$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors")
DETECTION_MODELS=("$MY_HF_REPO/yolov10m.onnx" "$MY_HF_REPO/vitpose_h_wholebody_data.bin" "$MY_HF_REPO/vitpose_h_wholebody_model.onnx")
UPSCALER_MODELS=("$MY_HF_REPO/low.pt" "$MY_HF_REPO/005_colorDN_DFWB_s128w8_SwinIR-M_noise15.pth")
LORAS=("$MY_HF_REPO/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" "$MY_HF_REPO/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" "$MY_HF_REPO/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" "$MY_HF_REPO/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors")

# --- ФУНКЦИЯ ЗАГРУЗКИ ---
function provisioning_get_files() {
    local dir="$1"; shift; local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local fname=$(basename $url)
        echo -e "${YELLOW}[DOWNLOADING]${NC} ${WHITE}$fname${NC}"
        # Важно: убрали -q, чтобы видеть прогресс загрузки в логах Vast
        wget --header="Authorization: Bearer $HF_TOKEN" --show-progress -c --content-disposition -P "$dir" "$url"
        log_success "$fname готов."
    done
}

# --- ПРОЦЕСС ---
log_header "ШАГ 1: ЯДРО"
cd "${WORKSPACE}"
if [[ -d "ComfyUI" ]]; then
    log_info "ComfyUI уже тут. Обновляю..."
    cd ComfyUI && git pull
else
    log_info "Клонирую чистое ядро..."
    git clone https://github.com/comfyanonymous/ComfyUI.git -q
    cd ComfyUI
fi

log_header "ШАГ 2: ТВОИ НОДЫ"
rm -rf custom_nodes/my_nodes
log_info "Клонирую fffrrr45..."
git clone --depth 1 "${ALLNODES_REPO}" custom_nodes/my_nodes -q
log_info "Ставлю зависимости (это может занять время)..."
find custom_nodes/my_nodes -name requirements.txt -exec pip install --no-cache-dir -r {} \;

log_header "ШАГ 3: ВЕСА (WAN 2.2)"
provisioning_get_files "models/clip" "${CLIP_MODELS[@]}"
provisioning_get_files "models/clip_vision" "${CLIP_VISION_MODELS[@]}"
provisioning_get_files "models/vae" "${VAE_MODELS[@]}"
provisioning_get_files "models/controlnet" "${CONTROLNET_MODELS[@]}"
provisioning_get_files "models/diffusion_models" "${DIFFUSION_MODELS[@]}"
provisioning_get_files "models/detection" "${DETECTION_MODELS[@]}"
provisioning_get_files "models/loras" "${LORAS[@]}"
provisioning_get_files "models/upscale_models" "${UPSCALER_MODELS[@]}"

log_header "ЗАПУСК СЕРВЕРА"
python main.py --listen 0.0.0.0 --port 18188 --enable-cors-header
