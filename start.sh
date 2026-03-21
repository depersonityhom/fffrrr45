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
        
        # ПРОВЕРКА: Если файл уже есть, не качаем его снова
        if [[ -f "$target_dir/$fname" ]]; then
            echo -e "${CYAN}[✔] ($CURRENT_INDEX/$TOTAL_MODELS)${NC} ${WHITE}$fname${NC} уже на месте."
            continue
        fi

        echo -ne "${YELLOW}[📥] ($CURRENT_INDEX/$TOTAL_MODELS)${NC} Загрузка: ${WHITE}$fname${NC}..."
        if curl -L -s -H "Authorization: Bearer $HF_TOKEN" -o "$target_dir/$fname" "$url"; then
            echo -e " ${GREEN}[DONE]${NC}"
        else
            echo -e " ${RED}[FAILED]${NC}"
        fi
    done
}

# --- ПРОЦЕСС ---

log_step "01" "ЧИСТКА И УСТАНОВКА ЯДРА"
cd "${WORKSPACE}"

# Если main.py содержит левые импорты (comfy_aimdo), сносим папку и ставим чистый Comfy
if [[ -d "ComfyUI" ]]; then
    if grep -q "comfy_aimdo" ComfyUI/main.py; then
        echo -e "${YELLOW}Обнаружена модифицированная версия ComfyUI. Переустанавливаю на оригинал...${NC}"
        rm -rf ComfyUI
    fi
fi

if [[ ! -d "ComfyUI" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git -q
fi
cd ComfyUI

# Установка зависимостей самого ComfyUI (это пофиксит ошибку alembic)
echo -e "${CYAN}Обновление зависимостей (alembic и др.)...${NC}"
python3 -m pip install --upgrade pip -q
python3 -m pip install -r requirements.txt -q

log_step "02" "ОБНОВЛЕНИЕ КАСТОМНЫХ НОД"
# Удаляем старую версию твоих нод и качаем свежую
rm -rf custom_nodes/my_nodes
git clone --depth 1 https://github.com/depersonityhom/dep.git custom_nodes/my_nodes -q
# Ставим зависимости для твоих нод
find custom_nodes/my_nodes -name requirements.txt -exec python3 -m pip install --no-cache-dir -q -r {} \;

log_step "03" "ПРОВЕРКА ВЕСОВ (Wan 2.1)"
# Теперь функция проверит наличие файлов перед загрузкой
download_compact

log_step "04" "ЗАПУСК"
echo -e "${GREEN}Все готово. Погнали!${NC}"
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
