PROJ_ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# ---- Environment settings for RTX 4080 / CUDA 11.8 + GCC 11 ----
export CUDA_HOME=/usr/local/cuda-11.8
export PATH=/usr/local/cuda-11.8/bin:$PATH
export LD_LIBRARY_PATH=$(python -c "import torch; import os; print(os.path.dirname(torch.__file__))")/lib:/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="8.9"
export CC=/usr/bin/gcc-11
export CXX=/usr/bin/g++-11
PYBIND11_DIR=$(python -c 'import pybind11; print(pybind11.get_cmake_dir())')
# -----------------------------------------------------------------

# Install mycpp
cd ${PROJ_ROOT}/mycpp/ && \
rm -rf build && mkdir -p build && cd build && \
cmake .. -DCMAKE_C_COMPILER=/usr/bin/gcc-11 -DCMAKE_CXX_COMPILER=/usr/bin/g++-11 -Dpybind11_DIR=${PYBIND11_DIR} && \
make -j$(nproc)

# Install mycuda
cd ${PROJ_ROOT}/bundlesdf/mycuda && \
rm -rf build *egg* *.so && \
pip install --no-build-isolation -e .

cd ${PROJ_ROOT}
