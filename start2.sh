#!/bin/bash
set -e
export TERM=xterm
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# --- ЦВЕТА ---
NC='\033[0m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; 
MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; RED='\033[1;31m'

# --- НАСТРОЙКИ ---
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
VENV_PATH="${WORKSPACE}/venv"
MY_REPO_URL="https://huggingface.co/depersonity/wf_local/resolve/main"

# Твой тестовый репозиторий
DEP_NODES_REPO="https://github.com/depersonityhom/dep_test_repo.git"
EXTRA_NODES=("https://github.com/PozzettiAndrea/ComfyUI-SAM3")

exec 3>&2
exec 2>/dev/null

# --- ФУНКЦИИ ---
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
        wget --header="Authorization: Bearer $HF_TOKEN" -q --show-progress=off -nc --content-disposition -P "$dir" "$url"
        echo -e " ${GREEN}[OK]${NC}"
    fi
}

# --- ПРОЦЕСС ---

log_step "01" "ПОДГОТОВКА ОКРУЖЕНИЯ"
if [[ ! -d "$VENV_PATH" ]]; then
    status_msg "Инициализация виртуальной среды"
    python3 -m venv "$VENV_PATH"
    status_ok
fi
source "$VENV_PATH/bin/activate"

log_step "02" "РАЗВЕРТЫВАНИЕ ЯДРА"
if [[ ! -d "${COMFYUI_DIR}" ]]; then
    status_msg "Загрузка базовых компонентов"
    git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}" -q
    status_ok
fi
cd "${COMFYUI_DIR}"

status_msg "Обновление зависимостей ComfyUI"
pip install --upgrade pip -q
pip install -r requirements.txt -q
status_ok

log_step "03" "СИНХРОНИЗАЦИЯ ТЕСТОВОГО КОНТЕНТА"
nodes_dir="${COMFYUI_DIR}/custom_nodes"
workflow_dir="${COMFYUI_DIR}/user/default/workflows"
temp_dep="/tmp/dep_test_repo"

mkdir -p "$workflow_dir"

status_msg "Клонирование репозитория $DEP_NODES_REPO"
rm -rf "$temp_dep"
git clone --depth 1 "$DEP_NODES_REPO" "$temp_dep" -q
status_ok

status_msg "Распределение файлов (ноды и воркфлоу)"
# 1. Копируем все папки (ноды) в custom_nodes
find "$temp_dep" -maxdepth 1 -mindepth 1 -type d ! -name ".git" -exec cp -r {} "$nodes_dir/" \;

# 2. Копируем все JSON файлы (воркфлоу) в папку воркфлоу
find "$temp_dep" -maxdepth 1 -name "*.json" -exec cp {} "$workflow_dir/" \;

# 3. Если в корне репо есть requirements.txt, ставим его
if [[ -f "$temp_dep/requirements.txt" ]]; then
    pip install -q --no-cache-dir -r "$temp_dep/requirements.txt"
fi
status_ok

status_msg "Установка дополнительных расширений"
for repo in "${EXTRA_NODES[@]}"; do
    name="${repo##*/}"
    [[ ! -d "${nodes_dir}/${name}" ]] && git clone --depth 1 "${repo}" "${nodes_dir}/${name}" -q || true
done
status_ok

status_msg "Конфигурация библиотек внутри нод"
find "${nodes_dir}" -maxdepth 2 -name requirements.txt -exec pip install -q --no-cache-dir -r {} \;
status_ok

log_step "04" "ПРОВЕРКА РЕСУРСОВ (WAN 2.1)"
download_resource "models/clip" "$MY_REPO_URL/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "Текстовый энкодер"
download_resource "models/clip_vision" "$MY_REPO_URL/clip_vision_h.safetensors" "Зрительный энкодер"
download_resource "models/vae" "$MY_REPO_URL/wan_2.1_vae.safetensors" "Видеотехнология (VAE)"
download_resource "models/diffusion_models" "$MY_REPO_URL/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" "Основная модель генерации"
download_resource "models/controlnet" "$MY_REPO_URL/Wan21_Uni3C_controlnet_fp16.safetensors" "Модуль управления"

log_step "05" "ЗАПУСК"
echo -e "${GREEN}✨ Все ресурсы из репозитория адаптированы и загружены!${NC}"
echo -e "${CYAN}📁 Воркфлоу ищи в меню Load -> user/default/workflows${NC}"
echo -e "${GRAY}------------------------------------------------------------${NC}"

exec 2>&3
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
