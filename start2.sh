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

log_step "03" "СИНХРОНИЗАЦИЯ REPO -> CUSTOM_NODES"
nodes_dir="${COMFYUI_DIR}/custom_nodes"
workflow_dir="${COMFYUI_DIR}/user/default/workflows"
temp_repo="/tmp/dep_test_repo"

mkdir -p "$nodes_dir"
mkdir -p "$workflow_dir"

status_msg "Получение данных из $DEP_NODES_REPO"
rm -rf "$temp_repo"
git clone --depth 1 "$DEP_NODES_REPO" "$temp_repo" -q
status_ok

status_msg "Прямое копирование содержимого"
# Копируем всё из корня репо прямо в custom_nodes
cp -rf "$temp_repo"/* "$nodes_dir/" 2>/dev/null || true

# Если в репозитории были JSON-воркфлоу, дублируем их в папку воркфлоу для удобства
find "$temp_repo" -maxdepth 1 -name "*.json" -exec cp {} "$workflow_dir/" \; 2>/dev/null || true

# Установка requirements из корня твоего репо, если он есть
if [[ -f "$temp_repo/requirements.txt" ]]; then
    pip install -q --no-cache-dir -r "$temp_repo/requirements.txt"
fi

# Чистим временные данные git, чтобы не засорять ComfyUI
rm -rf "$nodes_dir/.git"
status_ok

log_step "04" "УСТАНОВКА ДОП. РАСШИРЕНИЙ"
for repo in "${EXTRA_NODES[@]}"; do
    name="${repo##*/}"
    if [[ ! -d "${nodes_dir}/${name}" ]]; then
        status_msg "Загрузка $name"
        git clone --depth 1 "${repo}" "${nodes_dir}/${name}" -q
        [[ -f "${nodes_dir}/${name}/requirements.txt" ]] && pip install -q --no-cache-dir -r "${nodes_dir}/${name}/requirements.txt"
        status_ok
    fi
done

log_step "05" "ПРОВЕРКА РЕСУРСОВ (WAN 2.1)"
download_resource "models/clip" "$MY_REPO_URL/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "Текстовый энкодер"
download_resource "models/clip_vision" "$MY_REPO_URL/clip_vision_h.safetensors" "Зрительный энкодер"
download_resource "models/vae" "$MY_REPO_URL/wan_2.1_vae.safetensors" "Видеотехнология (VAE)"
download_resource "models/diffusion_models" "$MY_REPO_URL/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" "Основная модель генерации"
download_resource "models/controlnet" "$MY_REPO_URL/Wan21_Uni3C_controlnet_fp16.safetensors" "Модуль управления"

log_step "06" "ЗАПУСК"
echo -e "${GREEN}✨ Репозиторий развернут напрямую в custom_nodes.${NC}"
echo -e "${CYAN}🚀 Все изменения из GitHub применены. Погнали!${NC}"
echo -e "${GRAY}------------------------------------------------------------${NC}"

exec 2>&3
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
