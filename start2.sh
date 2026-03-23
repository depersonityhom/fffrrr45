#!/bin/bash
set -e
export TERM=xterm
# Глушим лишние вопросы от Git
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# --- ЦВЕТА ---
NC='\033[0m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; 
MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'

# --- НАСТРОЙКИ ---
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
VENV_PATH="${WORKSPACE}/venv"
MY_REPO_URL="https://huggingface.co/depersonity/wf_local/resolve/main"

# Твой обновленный репозиторий
DEP_NODES_REPO="https://github.com/depersonityhom/dep_test_repo.git"
EXTRA_NODES=("https://github.com/PozzettiAndrea/ComfyUI-SAM3")

# Режим тишины для системного мусора Vast.ai
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
    status_msg "Создание venv"
    python3 -m venv "$VENV_PATH"
    status_ok
fi
source "$VENV_PATH/bin/activate"

log_step "02" "РАЗВЕРТЫВАНИЕ ЯДРА"
if [[ ! -d "${COMFYUI_DIR}" ]]; then
    status_msg "Клонирование ComfyUI"
    git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}" -q
    status_ok
fi
cd "${COMFYUI_DIR}"

status_msg "Установка зависимостей ядра"
pip install --upgrade pip -q
pip install -r requirements.txt -q
status_ok

log_step "03" "СИНХРОНИЗАЦИЯ ТВОИХ НОД (DEPERSONITY)"
nodes_dir="${COMFYUI_DIR}/custom_nodes"
workflow_dir="${COMFYUI_DIR}/user/default/workflows"
temp_repo="/tmp/dep_test_repo"
bundle_dir="${nodes_dir}/Depersonity"

mkdir -p "$workflow_dir"

status_msg "Загрузка обновлений из GitHub"
rm -rf "$temp_repo"
git clone --depth 1 "$DEP_NODES_REPO" "$temp_repo" -q
status_ok

status_msg "Установка в custom_nodes/Depersonity"
rm -rf "$bundle_dir"
mkdir -p "$nodes_dir"
cp -rf "$temp_repo" "$bundle_dir" 2>/dev/null || true

# Копируем JSON в workflows для удобства запуска
find "$temp_repo" -maxdepth 1 -name "*.json" -exec cp {} "$workflow_dir/" \; 2>/dev/null || true

# Установка зависимостей всех включенных нод
while IFS= read -r -d '' req; do
    pip install -q --no-cache-dir -r "$req" || true
done < <(find "$bundle_dir" -type f -name "requirements.txt" -print0)

# Удаляем следы git из custom_nodes, чтобы не было конфликтов
rm -rf "$bundle_dir/.git"
status_ok

log_step "04" "ДОПОЛНИТЕЛЬНЫЕ РАСШИРЕНИЯ"
for repo in "${EXTRA_NODES[@]}"; do
    name="${repo##*/}"
    if [[ ! -d "${nodes_dir}/${name}" ]]; then
        status_msg "Установка $name"
        git clone --depth 1 "${repo}" "${nodes_dir}/${name}" -q
        [[ -f "${nodes_dir}/${name}/requirements.txt" ]] && pip install -q --no-cache-dir -r "${nodes_dir}/${name}/requirements.txt"
        status_ok
    fi
done

log_step "05" "ПРОВЕРКА МОДЕЛЕЙ (WAN 2.1)"
download_resource "models/clip" "$MY_REPO_URL/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "CLIP (Text)"
download_resource "models/clip_vision" "$MY_REPO_URL/clip_vision_h.safetensors" "CLIP Vision"
download_resource "models/vae" "$MY_REPO_URL/wan_2.1_vae.safetensors" "VAE"
download_resource "models/diffusion_models" "$MY_REPO_URL/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" "Main Model"
download_resource "models/controlnet" "$MY_REPO_URL/Wan21_Uni3C_controlnet_fp16.safetensors" "ControlNet"

log_step "06" "СТАРТ"
echo -e "${GREEN}✨ Все файлы из репозитория успешно перенесены в custom_nodes.${NC}"
echo -e "${GRAY}------------------------------------------------------------${NC}"

# Возвращаем ошибки в консоль
exec 2>&3
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
