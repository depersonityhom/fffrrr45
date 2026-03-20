#!/bin/bash
set -e
source /venv/main/bin/activate

# --- ЦВЕТА ДЛЯ ЛОГОВ ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${BLUE}[INFO] $(date +%T) - $1${NC}"
}

function log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# --- НАСТРОЙКИ ---
GH_TOKEN="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"
HF_TOKEN="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"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# --- ФУНКЦИЯ ЗАГРУЗКИ С ИНДИКАТОРОМ ---
function provisioning_get_files() {
    local dir="$1"
    shift
    local files=("$@")
    
    mkdir -p "$dir"
    log_info "Проверка файлов в директории: $dir"

    for url in "${files[@]}"; do
        local filename=$(basename "${url%%?*}")
        
        if [[ -f "${dir}/${filename}" ]] && [[ $(stat -c%s "${dir}/${filename}") -gt 1000000 ]]; then
            echo -e "  ✅ $filename уже на месте. Пропускаю."
            continue
        fi

        echo -e "  📥 Начинаю загрузку: ${GREEN}$filename${NC}"
        
        # --show-progress выводит полосу загрузки
        # -q выключает лишний мусор, оставляя только прогресс-бар
        wget --header="Authorization: Bearer $HF_TOKEN" \
             -q --show-progress \
             -c --content-disposition \
             -P "$dir" "$url"
             
        log_success "Файл $filename успешно загружен!"
    done
}

# --- ОСНОВНОЙ ПРОЦЕСС ---
clear
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}    ЗАПУСК АВТОНОМНОЙ УСТАНОВКИ COMFYUI          ${NC}"
echo -e "${BLUE}==================================================${NC}"

log_info "Шаг 1: Проверка и клонирование ComfyUI..."
if [[ ! -d "/workspace/ComfyUI" ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi
cd /workspace/ComfyUI

log_info "Шаг 2: Установка базовых библиотек (Requirements)..."
pip install --no-cache-dir -r requirements.txt -q

log_info "Шаг 3: Обновление твоих приватных нод..."
rm -rf custom_nodes
git clone --depth 1 "https://${GH_TOKEN}@github.com/depersonityhom/fffrrr45.git" custom_nodes -q
log_success "Ноды обновлены."

log_info "Шаг 4: Загрузка тяжелых моделей (Wan 2.2)..."
# Тут вызываем загрузку для каждой категории (Clip, Vae, Diffusion и т.д.)
# Пример для Diffusion:
provisioning_get_files "models/diffusion_models" "https://huggingface.co/depersonity/wf_local/resolve/main/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"

log_info "Все готово! Запускаю сервер..."
python main.py --listen 0.0.0.0 --port 8188
