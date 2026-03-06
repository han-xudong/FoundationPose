#!/bin/bash
# FoundationPose - Google Drive data download script
# Usage:
#   bash download_data.sh              # Download weights + demo_data (default)
#   bash download_data.sh --all        # Download everything (incl. training data and ref_views)
#   bash download_data.sh --weights    # Download model weights only
#   bash download_data.sh --demo       # Download demo data only
#   bash download_data.sh --ref-views  # Download preprocessed reference views (model-free setup)
#   bash download_data.sh --train      # Download large-scale training data (~tens of GB)

set -e

PROJ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Google Drive folder IDs ----
# Weights (refiner: 2023-10-28-18-33-37, scorer: 2024-01-11-20-02-45)
WEIGHTS_ID="1DFezOAD0oD1BblsXVxqDsl8fj0qzB82i"
# Demo data (mustard0, etc.)
DEMO_ID="1pRyFmxYXmAnpku7nGRioZaKrVJtIsroP"
# Preprocessed reference views (required for model-free setup)
REF_VIEWS_ID="1PXXCOJqHXwQTbwPwPbGDN9_vLVe0XpFS"
# Large-scale training data (optional, very large)
TRAIN_DATA_ID="1s4pB6p4ApfWMiMjmTXOFco8dHbNXikp-"

# ---- Colored output helpers ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---- Check / install gdown ----
check_gdown() {
  if ! command -v gdown &>/dev/null; then
    warn "gdown not found, installing..."
    pip install -q gdown || error "Failed to install gdown. Please run manually: pip install gdown"
    info "gdown installed: $(gdown --version)"
  else
    info "gdown found: $(gdown --version)"
  fi
}

# ---- Download a Google Drive folder ----
# $1: folder ID   $2: destination path   $3: description
download_folder() {
  local folder_id="$1"
  local dest="$2"
  local desc="$3"

  info "Downloading ${desc} -> ${dest}"
  mkdir -p "${dest}"

  gdown --folder "https://drive.google.com/drive/folders/${folder_id}" \
        --output "${dest}" \
        --remaining-ok \
    || warn "${desc} may be incomplete (large Google Drive folders sometimes require multiple retries)"

  info "${desc} download complete"
}

# ---- Argument parsing ----
DO_WEIGHTS=0
DO_DEMO=0
DO_REF_VIEWS=0
DO_TRAIN=0

if [[ $# -eq 0 ]]; then
  DO_WEIGHTS=1
  DO_DEMO=1
fi

for arg in "$@"; do
  case "$arg" in
    --all)       DO_WEIGHTS=1; DO_DEMO=1; DO_REF_VIEWS=1; DO_TRAIN=1 ;;
    --weights)   DO_WEIGHTS=1 ;;
    --demo)      DO_DEMO=1 ;;
    --ref-views) DO_REF_VIEWS=1 ;;
    --train)     DO_TRAIN=1 ;;
    -h|--help)
      sed -n '2,8p' "$0"   # print usage from script header
      exit 0 ;;
    *) error "Unknown argument: $arg. Use --help for usage." ;;
  esac
done

# ---- Main ----
check_gdown

if [[ $DO_WEIGHTS -eq 1 ]]; then
  if [[ -d "${PROJ_ROOT}/weights/2023-10-28-18-33-37" && \
        -d "${PROJ_ROOT}/weights/2024-01-11-20-02-45" ]]; then
    warn "weights/ already exists, skipping (remove the directory to re-download)"
  else
    download_folder "${WEIGHTS_ID}" "${PROJ_ROOT}/weights" "Model weights (refiner + scorer)"
  fi
fi

if [[ $DO_DEMO -eq 1 ]]; then
  if [[ -d "${PROJ_ROOT}/demo_data/mustard0" ]]; then
    warn "demo_data/ already exists, skipping (remove the directory to re-download)"
  else
    download_folder "${DEMO_ID}" "${PROJ_ROOT}/demo_data" "Demo data"
  fi
fi

if [[ $DO_REF_VIEWS -eq 1 ]]; then
  REF_DEST="${PROJ_ROOT}/ref_views"
  if [[ -d "${REF_DEST}" ]]; then
    warn "ref_views/ already exists, skipping"
  else
    download_folder "${REF_VIEWS_ID}" "${REF_DEST}" "Preprocessed reference views (model-free)"
  fi
  info "Reference views path: ${REF_DEST}"
  info "Pass this to model-free runs: --ref_view_dir ${REF_DEST}"
fi

if [[ $DO_TRAIN -eq 1 ]]; then
  warn "Training data is very large (tens of GB). Make sure you have enough disk space."
  read -r -p "Confirm download of training data? [y/N] " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    download_folder "${TRAIN_DATA_ID}" "${PROJ_ROOT}/training_data" "Large-scale training data"
  else
    info "Skipped training data download"
  fi
fi

echo ""
info "===== All downloads complete ====="
info "Project root: ${PROJ_ROOT}"
[[ $DO_WEIGHTS -eq 1 ]]   && info "  weights/         -> Model weights"
[[ $DO_DEMO -eq 1 ]]      && info "  demo_data/       -> Demo scene data"
[[ $DO_REF_VIEWS -eq 1 ]] && info "  ref_views/       -> Reference views (model-free)"
[[ $DO_TRAIN -eq 1 ]]     && info "  training_data/   -> Training data"
echo ""
info "You can now run: python run_demo.py"
