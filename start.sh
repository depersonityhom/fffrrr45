#!/bin/bash
set -e
export TERM=xterm

# --- ЦВЕТА ---
NC='\033[0m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; 
MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; RED='\033[1;31m'

function log_step() {
    echo -e "\n${MAGENTA}───[ STEP $1 ]──────────────────────────────────────────${NC}"
    echo -e "${WHITE}  🚀 $2${NC}"
}

# --- НАСТРОЙКИ ---
HF_TOKEN="${HF_TOKEN}" 
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

ALL_MODELS=(
    "models/clip|$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    "models/clip_vision|$MY_HF_REPO/clip_vision_h.safetensors"
    "models/vae|$MY_HF_REPO/wan_2.1_vae.safetensors"
    "models/diffusion_models|$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
    "models/controlnet|$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors"
)

TOTAL_MODELS=${#ALL_MODELS[@]}
CURRENT_INDEX=0

function download_compact() {
    for entry in "${ALL_MODELS[@]}"; do
        IFS="|" read -r target_dir url <<< "$entry"
        ((CURRENT_INDEX++))
        local fname=$(basename "$url")
        mkdir -p "$target_dir"
        echo -ne "${YELLOW}[📥] ($CURRENT_INDEX/$TOTAL_MODELS)${NC} Загрузка: ${WHITE}$fname${NC}..."
        if curl -L -s -H "Authorization: Bearer $HF_TOKEN" -o "$target_dir/$fname" "$url"; then
            echo -e " ${GREEN}[DONE]${NC}"
        else
            echo -e " ${RED}[FAILED]${NC}"
        fi
    done
}

# --- ПРОЦЕСС ---

log_step "01" "ПОДГОТОВКА ЯДРА И ЗАВИСИМОСТЕЙ"
cd "${WORKSPACE}"

# Если папка есть, но она битая/чужая — лучше её пересоздать
# Если хочешь сохранить данные, убери 'rm -rf ComfyUI'
if [[ -d "ComfyUI" && ! -f "ComfyUI/main.py" ]]; then
    rm -rf ComfyUI
fi

if [[ ! -d "ComfyUI" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi

cd ComfyUI

# КРИТИЧЕСКИЙ ШАГ: Установка зависимостей самого ComfyUI (включая alembic)
echo -e "${CYAN}Установка базовых зависимостей ComfyUI...${NC}"
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

log_step "02" "УСТАНОВКА КАСТОМНЫХ НОД"
# Твои ноды
rm -rf custom_nodes/my_nodes
git clone --depth 1 https://github.com/depersonityhom/dep.git custom_nodes/my_nodes -q
# Установка зависимостей для всех нод
find custom_nodes/my_nodes -name requirements.txt -exec python3 -m pip install --no-cache-dir -r {} \;

log_step "03" "ЗАГРУЗКА ВЕСОВ"
download_compact

log_step "04" "ЗАПУСК СЕРВЕРА"
echo -e "${GREEN}Все готово. Запуск...${NC}"
# Добавляем --force-fp16 или другие флаги если нужно, но база:
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
