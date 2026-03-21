#!/bin/bash
set -e

# --- НАСТРОЙКИ ОКРУЖЕНИЯ ---
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
VENV_PATH="${WORKSPACE}/venv"

# Создаем и активируем venv сразу
if [[ ! -d "$VENV_PATH" ]]; then
    python3 -m venv "$VENV_PATH"
fi
source "$VENV_PATH/bin/activate"

# --- ТВОИ МОДЕЛИ И НОДЫ ---
MY_REPO="https://huggingface.co/depersonity/wf_local/resolve/main"

# Твой основной репозиторий с нодами (заменит стандартный)
ALLNODES_REPO="https://github.com/depersonityhom/dep.git"
ALLNODES_BRANCH="main"

EXTRA_NODES=(
    "https://github.com/PozzettiAndrea/ComfyUI-SAM3"
)

CLIP_MODELS=(
    "$MY_REPO/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

CLIP_VISION_MODELS=(
    "$MY_REPO/clip_vision_h.safetensors"
)

VAE_MODELS=(
    "$MY_REPO/wan_2.1_vae.safetensors"
)

DIFFUSION_MODELS=(
    "$MY_REPO/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"
)

CONTROLNET_MODELS=(
    "$MY_REPO/Wan21_Uni3C_controlnet_fp16.safetensors"
)

# --- ФУНКЦИИ (Твоя оригинальная логика) ---

function log_step() {
    echo -e "\n=================================================="
    echo -e "🚀 $1"
    echo -e "=================================================="
}

function provisioning_start() {
    log_step "STEP 1: Clone/Verify ComfyUI"
    provisioning_clone_comfyui

    log_step "STEP 2: Install base requirements"
    provisioning_install_base_reqs

    log_step "STEP 3: Install custom nodes"
    provisioning_get_nodes

    log_step "STEP 4: Download models (Wan 2.1)"
    provisioning_get_files "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"

    log_step "PROVISIONING COMPLETE"
}

function provisioning_clone_comfyui() {
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
    fi
    cd "${COMFYUI_DIR}"
}

function provisioning_install_base_reqs() {
    pip install --upgrade pip
    pip install --no-cache-dir -r requirements.txt
}

function provisioning_get_nodes() {
    local nodes_dir="${COMFYUI_DIR}/custom_nodes"
    
    # Очистка и установка твоего основного репо 'dep'
    rm -rf "${nodes_dir}/my_nodes"
    git clone --depth 1 --branch "${ALLNODES_BRANCH}" "${ALLNODES_REPO}" "${nodes_dir}/my_nodes"

    # Дополнительные ноды
    for repo in "${EXTRA_NODES[@]}"; do
        local name="${repo##*/}"
        if [[ ! -d "${nodes_dir}/${name}" ]]; then
            git clone --depth 1 "${repo}" "${nodes_dir}/${name}" || true
        fi
    done

    # Установка зависимостей для всех нод
    find "${nodes_dir}" -maxdepth 2 -name requirements.txt -exec pip install --no-cache-dir -r {} \;
}

function provisioning_get_files() {
    local dir="$1"
    shift
    local files=("$@")
    mkdir -p "$dir"

    for url in "${files[@]}"; do
        local fname=$(basename "$url")
        if [[ -f "$dir/$fname" ]]; then
            echo "Skipping: $fname already exists."
            continue
        fi

        echo "Downloading $fname to $dir"
        # Используем wget с заголовком авторизации для Hugging Face
        wget --header="Authorization: Bearer $HF_TOKEN" -nc --content-disposition -P "$dir" "$url" || true
    done
}

# --- ЗАПУСК ---
provisioning_start

cd "${COMFYUI_DIR}"
# Запуск через venv python
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
