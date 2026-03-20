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
function log_info() { echo -e "${CYAN}[⚡]${NC} ${WHITE}$1${NC}"; }

# --- НАСТРОЙКИ ---
HF_TOKEN="${HF_TOKEN}" 
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
ALLNODES_REPO="https://github.com/depersonityhom/dep.git"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# --- СПИСОК МОДЕЛЕЙ (папка|ссылка) ---
ALL_MODELS=(
    "models/clip|$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    "models/clip_vision|$MY_HF_REPO/clip_vision_h.safetensors"
    "models/vae|$MY_HF_REPO/wan_2.1_vae.safetensors"
    "models/diffusion_models|$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
    "models/controlnet|$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors"
)

# --- УТИЛИТА ЗАГРУЗКИ (КОМПАКТНАЯ) ---
function download_compact() {
    local total=${#ALL_MODELS[@]}
    local current=0
    for entry in "${ALL_MODELS[@]}"; do
        IFS="|" read -r target_dir url <<< "$entry"
        ((current++))
        local fname=$(basename "$url")
        mkdir -p "$target_dir"
        echo -ne "${YELLOW}[📥] ($current/$total)${NC} Загрузка: ${WHITE}$fname${NC}..."
        # Качаем через curl (тихо)
        if curl -L -s -H "Authorization: Bearer $HF_TOKEN" -o "$target_dir/$fname" "$url"; then
            echo -e " ${GREEN}[DONE]${NC}"
        else
            echo -e " ${RED}[FAILED]${NC}"
        fi
    done
}

# --- ВЫПОЛНЕНИЕ ---

log_step "01" "ЯДРО И СИСТЕМНЫЕ ПАКЕТЫ"
cd "${WORKSPACE}"
if [[ ! -d "ComfyUI" ]]; then
    log_info "Клонирую ядро ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git -q
fi
cd ComfyUI

# ФИКС: Не трогаем pip, просто ставим alembic с игнором системных ограничений
log_info "Установка alembic и зависимостей..."
python3 -m pip install --no-cache-dir -q -r requirements.txt --break-system-packages || true
python3 -m pip install --no-cache-dir -q alembic --break-system-packages || true
log_ok "Система готова к работе."

log_step "02" "КАСТОМНЫЕ НОДЫ"
rm -rf custom_nodes/my_nodes
git clone --depth 1 "${ALLNODES_REPO}" custom_nodes/my_nodes -q
# Ставим зависимости нод с флагом --break-system-packages, чтобы pip не ругался
find custom_nodes/my_nodes -name requirements.txt -exec python3 -m pip install --no-cache-dir -q --break-system-packages -r {} \; || true
log_ok "Ноды 'dep' на месте."

log_step "03" "ЗАГРУЗКА ВЕСОВ (ОСНОВНОЙ ЭТАП)"
download_compact
log_ok "Все веса загружены."

log_sep
echo -e "${GREEN}  [READY] Система развернута. 5090 на взлете!${NC}"
log_sep

log_step "04" "ЗАПУСК СЕРВЕРА"
export PYTHONPATH="${PYTHONPATH}:${COMFYUI_DIR}/custom_nodes/my_nodes"
cd "${COMFYUI_DIR}"
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
