#!/bin/bash
set -e
export TERM=xterm

# --- ЦВЕТОВАЯ СХЕМА ---
NC='\033[0m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; 
MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; RED='\033[1;31m'

function log_step() {
    echo -e "\n${MAGENTA}───[ STEP $1 ]──────────────────────────────────────────${NC}"
    echo -e "${WHITE}  🚀 $2${NC}"
}

# --- НАСТРОЙКИ ---
# Принудительно проверяем переменную из Vast.ai
HF_TOKEN="${HF_TOKEN}" 

WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# Список моделей (папка|ссылка)
ALL_MODELS=(
    "models/clip|$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    "models/clip_vision|$MY_HF_REPO/clip_vision_h.safetensors"
    "models/vae|$MY_HF_REPO/wan_2.1_vae.safetensors"
    "models/diffusion_models|$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
    "models/controlnet|$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors"
)

# --- УТИЛИТА ЗАГРУЗКИ (УЛУЧШЕННАЯ) ---
function download_compact() {
    local total=${#ALL_MODELS[@]}
    local current=0
    
    if [[ -z "$HF_TOKEN" ]]; then
        echo -e "${RED}[✘] ОШИБКА: HF_TOKEN пустой! Проверь Docker Options в Vast.ai.${NC}"
        # Для теста попробуем продолжить, вдруг репо публичный
    else
        echo -e "${GREEN}[✔] Токен обнаружен (начинается на ${HF_TOKEN:0:7}...)${NC}"
    fi

    for entry in "${ALL_MODELS[@]}"; do
        IFS="|" read -r target_dir url <<< "$entry"
        ((current++))
        local fname=$(basename "$url")
        mkdir -p "$target_dir"
        
        if [[ -f "$target_dir/$fname" ]]; then
            echo -e "${CYAN}[⚡] ($current/$total)${NC} ${WHITE}$fname${NC} уже на диске, пропускаю."
            continue
        fi

        echo -ne "${YELLOW}[📥] ($current/$total)${NC} Загрузка: ${WHITE}$fname${NC}..."
        
        # -f заставит curl выдать ошибку, если токен не подошел
        if curl -L -f -H "Authorization: Bearer $HF_TOKEN" -o "$target_dir/$fname" "$url" --progress-bar; then
            echo -e " ${GREEN}[DONE]${NC}"
        else
            echo -e "\n${RED}[✘] ОШИБКА при загрузке $fname. Возможно, 401 Unauthorized.${NC}"
        fi
    done
}

# --- ПОЕХАЛИ ---

log_step "01" "ПОДГОТОВКА СИСТЕМЫ"
cd "${WORKSPACE}"
if [[ ! -d "ComfyUI" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git -q
fi
cd ComfyUI

# Ставим alembic (игнорируем ошибки pip)
python3 -m pip install --no-cache-dir -q alembic --break-system-packages || true

log_step "02" "НОДЫ"
if [[ ! -d "custom_nodes/my_nodes" ]]; then
    git clone --depth 1 https://github.com/depersonityhom/dep.git custom_nodes/my_nodes -q
fi

log_step "03" "МОДЕЛИ"
download_compact

log_step "04" "СТАРТ"
export PYTHONPATH="${PYTHONPATH}:${COMFYUI_DIR}/custom_nodes/my_nodes"
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
