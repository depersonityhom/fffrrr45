#!/bin/bash
set -e
export TERM=xterm
# Убираем спам SSH от Vast.ai
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# --- ЦВЕТОВАЯ ПАЛИТРА ---
NC='\033[0m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; 
MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; RED='\033[1;31m'

# --- НАСТРОЙКИ ---
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
VENV_PATH="${WORKSPACE}/venv"
MY_REPO_URL="https://huggingface.co/depersonity/wf_local/resolve/main"
DEP_NODES_REPO="https://github.com/depersonityhom/dep.git"
EXTRA_NODES=("https://github.com/PozzettiAndrea/ComfyUI-SAM3")

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
function log_step() {
    echo -e "\n${MAGENTA}───[ STEP $1 ]──────────────────────────────────────────${NC}"
    echo -e "${WHITE}  🚀 $2${NC}"
}

function status_msg() {
    echo -ne "${CYAN}[⚙️]${NC} $1..."
}

function status_ok() {
    echo -e " ${GREEN}[DONE]${NC}"
}

function download_resource() {
    local dir="$1"
    local url="$2"
    local desc="$3"
    local fname=$(basename "$url")
    mkdir -p "$dir"
    
    if [[ -f "$dir/$fname" ]]; then
        echo -e "${GRAY}[✔] $desc${NC}"
    else
        echo -ne "${YELLOW}[📥]${NC} $desc..."
        # Подавляем stderr у wget, чтобы не лезли ошибки портов
        wget --header="Authorization: Bearer $HF_TOKEN" -q --show-progress=off -nc --content-disposition -P "$dir" "$url" 2>/dev/null
        echo -e " ${GREEN}[OK]${NC}"
    fi
}

# --- ОСНОВНОЙ ПРОЦЕСС ---

log_step "01" "ПОДГОТОВКА ОКРУЖЕНИЯ"
if [[ ! -d "$VENV_PATH" ]]; then
    status_msg "Инициализация виртуального окружения"
    python3 -m venv "$VENV_PATH" &>/dev/null
    status_ok
fi
source "$VENV_PATH/bin/activate"

log_step "02" "РАЗВЕРТЫВАНИЕ ЯДРА"
if [[ ! -d "${COMFYUI_DIR}" ]]; then
    status_msg "Установка базовых компонентов"
    # Перенаправляем весь мусор в /dev/null
    git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}" -q 2>/dev/null
    status_ok
fi
cd "${COMFYUI_DIR}"

status_msg "Обновление системных зависимостей"
pip install --upgrade pip -q 2>/dev/null
pip install -r requirements.txt -q 2>/dev/null
status_ok

log_step "03" "НАСТРОЙКА РАСШИРЕНИЙ"
nodes_dir="${COMFYUI_DIR}/custom_nodes"
temp_dep="/tmp/dep_repo"

status_msg "Синхронизация кастомных компонентов"
rm -rf "$temp_dep"
git clone --depth 1 "$DEP_NODES_REPO" "$temp_dep" -q 2>/dev/null
cp -r "$temp_dep"/* "$nodes_dir/" 2>/dev/null || true
rm -f "$nodes_dir/README.md" "$nodes_dir/LICENSE"

for repo in "${EXTRA_NODES[@]}"; do
    name="${repo##*/}"
    [[ ! -d "${nodes_dir}/${name}" ]] && git clone --depth 1 "${repo}" "${nodes_dir}/${name}" -q 2>/dev/null || true
done
status_ok

status_msg "Конфигурация библиотек"
find "${nodes_dir}" -maxdepth 2 -name requirements.txt -exec pip install -q --no-cache-dir -r {} \; 2>/dev/null
status_ok

log_step "04" "ПРОВЕРКА РЕСУРСОВ (WAN 2.1)"
download_resource "models/clip" "$MY_REPO_URL/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "Текстовый энкодер (CLIP)"
download_resource "models/clip_vision" "$MY_REPO_URL/clip_vision_h.safetensors" "Зрительный энкодер (Vision)"
download_resource "models/vae" "$MY_REPO_URL/wan_2.1_vae.safetensors" "Декодер видео (VAE)"
download_resource "models/diffusion_models" "$MY_REPO_URL/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" "Основная модель генерации"
download_resource "models/controlnet" "$MY_REPO_URL/Wan21_Uni3C_controlnet_fp16.safetensors" "Модуль управления (ControlNet)"

log_step "05" "ЗАПУСК"
echo -e "${GREEN}✨ Все системы в норме. Сервер готов к работе.${NC}"
echo -e "${GRAY}------------------------------------------------------------${NC}"
# Оставляем stderr только для самого ComfyUI, чтобы видеть, если он упадет при старте
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
