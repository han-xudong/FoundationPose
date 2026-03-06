#!/bin/bash
# FoundationPose - Automated conda environment setup
# Usage:
#   bash setup_conda_env.sh                        # Create env 'foundationpose' and install everything
#   bash setup_conda_env.sh --name myenv           # Use a custom environment name
#   bash setup_conda_env.sh --skip-kaolin          # Skip Kaolin (not needed for model-based setup)
#   bash setup_conda_env.sh --reinstall            # Remove existing env and start fresh
#
# Prerequisites (must be present on the host system):
#   - Anaconda / Miniconda
#   - CUDA 11.8  at /usr/local/cuda-11.8
#   - GCC 11     at /usr/bin/gcc-11  (CUDA 11.8 does not support GCC > 11)

set -e

PROJ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Defaults ----
ENV_NAME="foundationpose"
INSTALL_KAOLIN=1
REINSTALL=0

# ---- Colors ----
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${CYAN}==== $* ====${NC}"; }

# ---- Argument parsing ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)         ENV_NAME="$2"; shift 2 ;;
    --skip-kaolin)  INSTALL_KAOLIN=0; shift ;;
    --reinstall)    REINSTALL=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0 ;;
    *) error "Unknown argument: $1. Use --help for usage." ;;
  esac
done

# ---- Locate conda ----
section "Locating conda"
CONDA_BASE="$(conda info --base 2>/dev/null)" \
  || error "conda not found. Please install Anaconda or Miniconda first."
CONDA_SH="${CONDA_BASE}/etc/profile.d/conda.sh"
[[ -f "${CONDA_SH}" ]] || error "conda.sh not found at ${CONDA_SH}"
info "conda base: ${CONDA_BASE}"

# ---- Check host prerequisites ----
section "Checking prerequisites"

[[ -x /usr/bin/gcc-11 && -x /usr/bin/g++-11 ]] \
  || error "GCC 11 not found at /usr/bin/gcc-11. Install with: sudo apt install gcc-11 g++-11"
info "GCC 11: $(gcc-11 --version | head -1)"

[[ -x /usr/local/cuda-11.8/bin/nvcc ]] \
  || error "CUDA 11.8 not found at /usr/local/cuda-11.8. Please install CUDA 11.8 first."
info "CUDA 11.8: $(/usr/local/cuda-11.8/bin/nvcc --version | grep release)"

# ---- (Re)create conda environment ----
section "Conda environment: ${ENV_NAME}"

if conda env list | grep -qE "^${ENV_NAME}\s"; then
  if [[ $REINSTALL -eq 1 ]]; then
    # Check if the target env is currently active
    ACTIVE_ENV=$(conda info --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('active_prefix_name',''))" 2>/dev/null || echo "")
    if [[ "${ACTIVE_ENV}" == "${ENV_NAME}" ]]; then
      error "Cannot remove '${ENV_NAME}': it is currently active.\n       Please run:\n         conda deactivate\n         bash setup_conda_env.sh --reinstall"
    fi
    warn "Removing existing environment '${ENV_NAME}'..."
    conda env remove -n "${ENV_NAME}" -y
  else
    warn "Environment '${ENV_NAME}' already exists. Use --reinstall to recreate it."
    warn "Continuing with the existing environment..."
  fi
fi

if ! conda env list | grep -qE "^${ENV_NAME}\s"; then
  info "Creating conda environment '${ENV_NAME}' with Python 3.9..."
  conda create -n "${ENV_NAME}" python=3.9 -y
fi

# Helper: run a command inside the target conda env
run_in_env() {
  # source conda in a subshell so activation works in non-interactive bash
  bash -c "source '${CONDA_SH}' && conda activate '${ENV_NAME}' && $*"
}

# ---- Install CUDA 11.8 toolkit into the env ----
section "Installing CUDA 11.8 toolkit into conda env"
info "This ensures 'nvcc 11.8' is used regardless of the system default CUDA."
conda install -n "${ENV_NAME}" -c "nvidia/label/cuda-11.8.0" cuda-toolkit -y

# ---- Install Python dependencies ----
section "Installing Python dependencies (requirements.txt)"
run_in_env "pip install -r '${PROJ_ROOT}/requirements.txt'"

# ---- Detect GPU architecture ----
section "Detecting GPU compute capability"
ARCH=$(run_in_env "python -c \"
import torch, sys
if not torch.cuda.is_available():
    print('GPU not available, defaulting to 8.6', file=sys.stderr)
    print('8.6')
else:
    cap = torch.cuda.get_device_capability()
    name = torch.cuda.get_device_name(0)
    print(f'{cap[0]}.{cap[1]}')
    import sys; print(f'Detected: {name}  =>  sm_{cap[0]}{cap[1]}', file=sys.stderr)
\"" 2>/dev/null) || ARCH="8.6"
# Print the stderr message (device name) separately
run_in_env "python -c \"
import torch, sys
if torch.cuda.is_available():
    cap = torch.cuda.get_device_capability()
    print(f'GPU: {torch.cuda.get_device_name(0)}  =>  TORCH_CUDA_ARCH_LIST={cap[0]}.{cap[1]}')
\"" 2>/dev/null || true
info "TORCH_CUDA_ARCH_LIST=${ARCH}"

# ---- Install NVDiffRast ----
section "Installing NVDiffRast"
run_in_env "
export CUDA_HOME=/usr/local/cuda-11.8
export PATH=/usr/local/cuda-11.8/bin:\$PATH
export CC=/usr/bin/gcc-11
export CXX=/usr/bin/g++-11
export TORCH_CUDA_ARCH_LIST='${ARCH}'
pip install --no-build-isolation --no-cache-dir git+https://github.com/NVlabs/nvdiffrast.git
"

# ---- Install PyTorch3D ----
section "Installing PyTorch3D (pre-built wheel: py39 + cu118 + torch2.0.0)"
run_in_env "
pip install --no-index --no-cache-dir pytorch3d \
  -f https://dl.fbaipublicfiles.com/pytorch3d/packaging/wheels/py39_cu118_pyt200/download.html
"

# ---- Install Kaolin (optional) ----
if [[ $INSTALL_KAOLIN -eq 1 ]]; then
  section "Installing Kaolin (model-free setup)"
  run_in_env "
  pip install --no-cache-dir kaolin==0.15.0 \
    -f https://nvidia-kaolin.s3.us-east-2.amazonaws.com/torch-2.0.0_cu118.html
  " || warn "Kaolin installation failed. Model-free setup will not be available. Continuing..."  # Kaolin downgrades pyzmq (<25) and jupyter-client (<8) which breaks ipykernel 6.x
  # Restore the versions required by ipykernel
  info "Restoring pyzmq>=25 and jupyter-client>=8 (required by ipykernel)..."
  run_in_env "pip install --no-cache-dir 'pyzmq>=25' 'jupyter-client>=8'" \
    || warn "Could not restore pyzmq/jupyter-client. Jupyter may not work."else
  info "Skipping Kaolin (--skip-kaolin)"
fi

# ---- Write conda activation script ----
section "Writing conda activation script"
ACTIVATE_DIR="${CONDA_BASE}/envs/${ENV_NAME}/etc/conda/activate.d"
mkdir -p "${ACTIVATE_DIR}"
TORCH_LIB=$(run_in_env "python -c \"import torch, os; print(os.path.join(os.path.dirname(torch.__file__), 'lib'))\"")
cat > "${ACTIVATE_DIR}/env_vars.sh" << EOF
#!/bin/bash
# Auto-generated by setup_conda_env.sh
export CUDA_HOME=/usr/local/cuda-11.8
export PATH=/usr/local/cuda-11.8/bin:\$PATH
export LD_LIBRARY_PATH=${TORCH_LIB}:/usr/local/cuda-11.8/lib64:\$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="${ARCH}"
export CC=/usr/bin/gcc-11
export CXX=/usr/bin/g++-11
EOF
info "Activation script written to: ${ACTIVATE_DIR}/env_vars.sh"

# ---- Build C++/CUDA extensions ----
section "Building C++/CUDA extensions"
PYBIND11_DIR=$(run_in_env "python -c \"import pybind11; print(pybind11.get_cmake_dir())\"")
info "pybind11 cmake dir: ${PYBIND11_DIR}"

# mycpp
info "Building mycpp..."
run_in_env "
export CUDA_HOME=/usr/local/cuda-11.8
export PATH=/usr/local/cuda-11.8/bin:\$PATH
export CC=/usr/bin/gcc-11
export CXX=/usr/bin/g++-11
cd '${PROJ_ROOT}/mycpp'
rm -rf build && mkdir -p build && cd build
cmake .. \
  -DCMAKE_C_COMPILER=/usr/bin/gcc-11 \
  -DCMAKE_CXX_COMPILER=/usr/bin/g++-11 \
  -Dpybind11_DIR='${PYBIND11_DIR}'
make -j\$(nproc)
"
# Copy .so to project root so Python can find it
SO_FILE=$(find "${PROJ_ROOT}/mycpp/build" -name "mycpp*.so" | head -1)
[[ -n "${SO_FILE}" ]] && cp "${SO_FILE}" "${PROJ_ROOT}/" \
  && info "Copied $(basename ${SO_FILE}) to project root"

# mycuda
info "Building mycuda..."
run_in_env "
export CUDA_HOME=/usr/local/cuda-11.8
export PATH=/usr/local/cuda-11.8/bin:\$PATH
export LD_LIBRARY_PATH=${TORCH_LIB}:/usr/local/cuda-11.8/lib64:\$LD_LIBRARY_PATH
export CC=/usr/bin/gcc-11
export CXX=/usr/bin/g++-11
export TORCH_CUDA_ARCH_LIST='${ARCH}'
cd '${PROJ_ROOT}/bundlesdf/mycuda'
rm -rf build *egg* *.so
pip install --no-build-isolation -e .
"

# ---- Final verification ----
section "Verifying installation"
run_in_env "
export LD_LIBRARY_PATH=${TORCH_LIB}:/usr/local/cuda-11.8/lib64:\$LD_LIBRARY_PATH
cd '${PROJ_ROOT}'
python -c \"
import sys
results = {}
pkgs = {
    'torch':       ('torch',       lambda m: f'{m.__version__} (CUDA {m.version.cuda}, GPU: {m.cuda.get_device_name(0)})'),
    'nvdiffrast':  ('nvdiffrast',  lambda m: m.__version__),
    'pytorch3d':   ('pytorch3d',   lambda m: m.__version__),
    'mycuda/common':    ('common',      lambda m: 'ok'),
    'mycuda/gridenc':   ('gridencoder', lambda m: 'ok'),
    'mycpp':       ('mycpp',       lambda m: 'ok'),
    'open3d':      ('open3d',      lambda m: m.__version__),
    'trimesh':     ('trimesh',     lambda m: m.__version__),
}
all_ok = True
for label, (mod, fmt) in pkgs.items():
    try:
        import importlib; m = importlib.import_module(mod)
        print(f'  [OK] {label:<22} {fmt(m)}')
    except Exception as e:
        print(f'  [FAIL] {label:<20} {e}')
        all_ok = False
print()
print('All checks passed!' if all_ok else 'Some checks FAILED. See above.')
sys.exit(0 if all_ok else 1)
\"
"

echo ""
info "===== Setup complete ====="
info "Activate the environment with:  conda activate ${ENV_NAME}"
info "Then run the demo with:         python run_demo.py"
