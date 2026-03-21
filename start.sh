#!/bin/bash
set -e

# --- НАСТРОЙКИ ОКРУЖЕНИЯ ---
WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
VENV_PATH="${WORKSPACE}/venv"

# Создаем и активируем venv
if [[ ! -d "$VENV_PATH" ]]; then
    python3 -m venv "$VENV_PATH"
fi
source "$VENV_PATH/bin/activate"

# --- ТВОИ МОДЕЛИ И НОДЫ ---
MY_REPO_URL="https://huggingface.co/depersonity/wf_local/resolve/main"
# Твой обновленный репозиторий с набором нод
DEP_NODES_REPO="https://github.com/depersonityhom/dep.git"

EXTRA_NODES=(
    "https://github.com/PozzettiAndrea/ComfyUI-SAM3"
)

# Списки моделей (Wan 2.1)
CLIP_MODELS=("$MY_REPO_URL/umt5_xxl_fp8_e4m3fn_scaled.safetensors")
CLIP_VISION_MODELS=("$MY_REPO_URL/clip_vision_h.safetensors")
VAE_MODELS=("$MY_REPO_URL/wan_2.1_vae.safetensors")
DIFFUSION_MODELS=("$MY_REPO_URL/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors")
CONTROLNET_MODELS=("$MY_REPO_URL/Wan21_Uni3C_controlnet_fp16.safetensors")

# --- ФУНКЦИИ ---

function log_step() {
    echo -e "\n=================================================="
    echo -e "🚀 $1"
    echo -e "=================================================="
}

function provisioning_start() {
    log_step "STEP 1: Clone/Verify ComfyUI"
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
    fi
    cd "${COMFYUI_DIR}"

    log_step "STEP 2: Install base requirements"
    pip install --upgrade pip
    pip install --no-cache-dir -r requirements.txt

    log_step "STEP 3: Install custom nodes from 'dep' repo"
    local nodes_dir="${COMFYUI_DIR}/custom_nodes"
    local temp_dep="/tmp/dep_repo"
    
    # Чистим старое
    rm -rf "$temp_dep"
    
    # Клонируем твой репо во временную папку
    git clone --depth 1 "$DEP_NODES_REPO" "$temp_dep"
    
    # Копируем каждую подпапку (ноду) отдельно в custom_nodes
    # Исключаем .git и README
    cp -r "$temp_dep"/* "$nodes_dir/" 2>/dev/null || true
    rm -rf "$nodes_dir/README.md" "$nodes_dir/LICENSE"

    # Дополнительные ноды (SAM3 и др.)
    for repo in "${EXTRA_NODES[@]}"; do
        local name="${repo##*/}"
        if [[ ! -d "${nodes_dir}/${name}" ]]; then
            git clone --depth 1 "${repo}" "${nodes_dir}/${name}" || true
        fi
    done

    # Установка зависимостей для всего, что упало в custom_nodes
    log_step "STEP 3.1: Installing nodes requirements"
    find "${nodes_dir}" -maxdepth 2 -name requirements.txt -exec pip install --no-cache-dir -r {} \;

    log_step "STEP 4: Download models"
    provisioning_get_files "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"

    log_step "PROVISIONING COMPLETE"
}

function provisioning_get_files() {
    local dir="$1"
    shift
    local files=("$@")
    mkdir -p "$dir"
    for url in "${files[@]}"; do
        local fname=$(basename "$url")
        if [[ -f "$dir/$fname" ]]; then
            echo "Skipping: $fname exists."
            continue
        fi
        echo "Downloading $fname..."
        wget --header="Authorization: Bearer $HF_TOKEN" -nc --content-disposition -P "$dir" "$url" || true
    done
}

# --- ЗАПУСК ---
provisioning_start

cd "${COMFYUI_DIR}"
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
