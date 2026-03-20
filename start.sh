#!/bin/bash
set -e
# В этом образе обычно используется системный python или conda, подхватываем его
# source /venv/main/bin/activate # Если в логах будет ошибка, закомментируй эту строку

# --- НАСТРОЙКИ ---
GH_TOKEN="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"
HF_TOKEN="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"
MY_HF_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# --- ЦВЕТА И ЛОГИ ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO] $(date +%T) - $1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }

# --- ФУНКЦИЯ ЗАГРУЗКИ ---
function provisioning_get_files() {
    local dir="$1"
    shift
    local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local filename=$(basename "${url%%?*}")
        if [[ -f "${dir}/${filename}" ]] && [[ $(stat -c%s "${dir}/${filename}") -gt 1000000 ]]; then
            echo -e "  ✅ $filename на месте."
            continue
        fi
        echo -e "  📥 Загрузка: ${GREEN}$filename${NC}"
        wget --header="Authorization: Bearer $HF_TOKEN" -q --show-progress -c --content-disposition -P "$dir" "$url"
    done
}

# --- ПРОЦЕСС ---
cd /workspace/ComfyUI

log_info "Шаг 1: Обновление ядра под Wan 2.2..."
# Образ может быть старым, обновляем ключевые пакеты для работы видео
pip install --upgrade pip -q
pip install transformers accelerate diffusers -q

log_info "Шаг 2: Добавление твоих приватных нод..."
# Мы не удаляем всю папку, чтобы не убить Manager, а клонируем твои ноды рядом
# Если папка fffrrr45 уже есть, просто обновляем
if [ -d "custom_nodes/fffrrr45" ]; then
    cd custom_nodes/fffrrr45 && git pull && cd ../..
else
    git clone --depth 1 "https://${GH_TOKEN}@github.com/depersonityhom/fffrrr45.git" custom_nodes/fffrrr45 -q
fi

# Установка зависимостей только для твоих нод
log_info "Установка зависимостей для твоих нод..."
find custom_nodes/fffrrr45 -type f -name requirements.txt -exec pip install --no-cache-dir -r {} \; -q

log_info "Шаг 3: Проверка и загрузка моделей из твоего HF..."
# Используем те же пути, что и раньше
provisioning_get_files "models/clip" "$MY_HF_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
provisioning_get_files "models/clip_vision" "$MY_HF_REPO/clip_vision_h.safetensors"
provisioning_get_files "models/vae" "$MY_HF_REPO/wan_2.1_vae.safetensors"
provisioning_get_files "models/controlnet" "$MY_HF_REPO/Wan21_Uni3C_controlnet_fp16.safetensors"
provisioning_get_files "models/diffusion_models" "$MY_HF_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
# ... добавь сюда остальные файлы из прошлого списка по желанию

log_success "Все системы готовы."

# --- ШАГ 4: ЗАПУСК ---
# Используем порт из твоего темплейта (18188) или стандартный
python main.py --listen 0.0.0.0 --port 8188
