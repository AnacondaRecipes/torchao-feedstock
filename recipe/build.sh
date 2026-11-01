#!/bin/bash
set -euxo pipefail

# Prevent setup.py from appending "+git<sha>" to the version — the source
# is a GitHub archive (not a git repo) so get_git_commit_id() returns "".
# Setting VERSION_SUFFIX="" keeps the version as "${PKG_VERSION}" exactly.
export VERSION_SUFFIX=""

# CUTLASS comes from the conda package, not the git submodule: skip setup.py's
# check_submodules() (USE_SYSTEM_LIBS has no other effect in setup.py).
export USE_SYSTEM_LIBS=1

# Disable macOS/ARM experimental cmake-based CPU kernels for now.
# build_macos_arm_auto = (USE_CPP=1 and is_arm64 and is_macos) would otherwise
# trigger cmake-based TORCHAO_BUILD_CPU_AARCH64, which is not yet tested.
export BUILD_TORCHAO_EXPERIMENTAL=0

if [ "${gpu_variant}" = "cuda" ]; then
    # CUDA build: compile the CUDA extensions. In torchao 0.18 these are
    # _C_cutlass_90a (SM90a CUTLASS kernels) and _C_mxfp8 (SM100 kernels); setup.py
    # enables them from the nvcc version (SM90a: CUDA >=12.6, SM100a: CUDA >=12.8).
    export USE_CPP=1

    # setup.py hardcodes -I third_party/cutlass/{include,tools/util/include}; the
    # conda cutlass package installs both header trees under $PREFIX/include.
    mkdir -p third_party/cutlass/tools/util
    ln -s "${PREFIX}/include" third_party/cutlass/include
    ln -s "${PREFIX}/include" third_party/cutlass/tools/util/include

    # Unused by torchao 0.18 (both extensions pass their own -gencode); kept so a future
    # extension without one doesn't build only for the CI GPU. Matches pytorch-feedstock.
    if [[ "${target_platform}" == "linux-aarch64" ]]; then
        export TORCH_CUDA_ARCH_LIST="8.0;9.0;10.0;11.0;12.0;12.1+PTX"
    else
        export TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;9.0;10.0;12.0+PTX"
    fi

    # CUDA 12.x requires gcc <14.0 per torch/utils/cpp_extension.py CUDA_GCC_VERSIONS,
    # but the CUDA 12.9 pytorch on pkgs/main is built with gcc 14 too. Bypass the
    # consumer-side check; the libstdc++ ABI is consistent.
    if [[ "${cuda_compiler_version:0:2}" == "12" ]]; then
        export TORCH_DONT_CHECK_COMPILER_ABI=1
    fi
else
    # CPU build: pure Python mode, no C++ compilation.
    export USE_CPP=0
fi

$PYTHON -m pip install . -vv --no-deps --no-build-isolation

# setup.py's find_packages() also picks up upstream's top-level `test` suite;
# don't ship it as a generic `test` package in site-packages.
rm -rf "${SP_DIR}/test"
