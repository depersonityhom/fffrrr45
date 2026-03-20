#!/bin/bash
set -e
export TERM=xterm

# --- ЦВЕТОВАЯ СХЕМА ---
NC='\033[0m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; 
MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; RED='\033[1;31m'

function log_sep() { echo -e "${GRAY}------------------------------------------------------------${NC}"; }
function log_step() {
    echo -e "\n${MAGENTA}───[ STEP $1 ]──────────────────────────────────────────${NC}"
    echo -e "${WHITE}  🚀 $2${NC}"
    log_sep
}
function log_ok() { echo -e "${GREEN}[✔]${NC} $1"; }

# --- НАСТРОЙКИ ---
# --- НАСТРОЙКИ ---
# Теперь берем токен из переменной окружения Vast.ai
# Если она не задана, используем пустую строку (но загрузка упадет с 401)
HF_TOKEN="${HF_TOKEN}" 

if [[ -z "$HF_TOKEN" ]]; then
    echo -e "${RED}[!] ВНИМАНИЕ: Переменная HF_TOKEN не задана в настройках Vast.ai!${NC}"
fi

WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
ALLNODES_REPO="https://github.com/depersonityhom/dep.git"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# --- УТИЛИТА ЗАГРУЗКИ ---
function download_files() {
    local dir="$1"; shift; local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local fname=$(basename $url)
        echo -e "${YELLOW}[📥] Загрузка: ${WHITE}$fname${NC}"
        # Качаем с новым токеном
        if wget --header="Authorization: Bearer $HF_TOKEN" --show-progress -c --content-disposition -P "$dir" "$url"; then
            log_ok "$fname готов."
        else
            echo -e "${RED}[✘] ОШИБКА: Hugging Face отклонил токен для $fname${NC}"
        fi
    done
}

# --- ПОЕХАЛИ ---

log_step "01" "ЯДРО COMFYUI"
cd "${WORKSPACE}"
if [[ ! -d "ComfyUI" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git -q
fi
cd ComfyUI

log_step "02" "КАСТОМНЫЕ НОДЫ"
rm -rf custom_nodes/my_nodes
git clone --depth 1 "${ALLNODES_REPO}" custom_nodes/my_nodes -q
find custom_nodes/my_nodes -name requirements.txt -exec pip install --no-cache-dir -q -r {} \;
log_ok "Ноды 'dep' установлены."

log_step "03" "ЗАГРУЗКА ВЕСОВ WAN 2.2"
# Сначала самое тяжелое (22ГБ)
download_files "models/clip" "$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
# Остальное
download_files "models/clip_vision" "$MY_HF_REPO/clip_vision_h.safetensors"
download_files "models/vae" "$MY_HF_REPO/wan_2.1_vae.safetensors"
download_files "models/diffusion_models" "$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
download_files "models/controlnet" "$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors"

log_sep
echo -e "${GREEN}  [READY] Система развернута. Удачной работы, Константин!${NC}"
log_sep

log_step "04" "ЗАПУСК СЕРВЕРА"
python3 main.py --listen 0.0.0.0 --port 18188 --enable-cors-header
