#!/bin/bash
set -euxo pipefail

# Prevent setup.py from appending "+git<sha>" to the version — the source
# is a GitHub archive (not a git repo) so get_git_commit_id() returns "".
# Setting VERSION_SUFFIX="" keeps the version as "0.17.0" exactly.
export VERSION_SUFFIX=""

# Disable macOS/ARM experimental cmake-based CPU kernels for now.
# build_macos_arm_auto = (USE_CPP=1 and is_arm64 and is_macos) would otherwise
# trigger cmake-based TORCHAO_BUILD_CPU_AARCH64, which is not yet tested.
export BUILD_TORCHAO_EXPERIMENTAL=0

if [ "${cpu_or_cuda}" = "cuda" ]; then
    # CUDA build: compile C++/CUDA kernels including CUTLASS SM90a+ paths.
    export USE_CPP=1

    # Match pytorch-feedstock's CUDA arch list for ABI alignment with pkgs/main libtorch.
    export TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;9.0;10.0;12.0+PTX"

    # CUDA 12.x requires gcc <14.0 per torch/utils/cpp_extension.py CUDA_GCC_VERSIONS,
    # but pkgs/main only ships gcc 14.3.0 — same gcc that built pytorch 2.11. Bypass
    # the consumer-side check; the libstdc++ ABI is consistent.
    if [[ "${cuda_compiler_version:0:2}" == "12" ]]; then
        export TORCH_DONT_CHECK_COMPILER_ABI=1
        # CUTLASS SM90a/SM100a sources (rowwise_scaled_linear_sparse_cutlass_* and
        # to_sparse_semi_structured_cutlass_sm9x) emit "default arguments are only
        # permitted for function parameters [-fpermissive]" under CUDA 12.9 nvcc.
        # Patch setup.py so get_cutlass_build_flags() returns (False, False) for this
        # build; the main _C extension is unaffected.
        python3 -c "
import pathlib
p = pathlib.Path('setup.py')
txt = p.read_text()
txt = txt.replace(
    'build_for_sm90a, build_for_sm100a = get_cutlass_build_flags()',
    'build_for_sm90a, build_for_sm100a = False, False  # disabled: nvcc 12.x incompatibility'
)
p.write_text(txt)
print('Patched setup.py: disabled CUTLASS SM90a/SM100a for CUDA 12.x')
"
    fi

    # CUDA 13.x: the mxfp8 extension (SM 12.0/Blackwell) uses __cudaLaunch which was
    # removed in CUDA 13.0 (renamed to __cudaLaunchKernel). Remove the mxfp8 sources
    # so setup.py skips that extension; the main _C CUDA extension is unaffected.
    if [[ "${cuda_compiler_version:0:2}" == "13" ]]; then
        rm -f torchao/csrc/cuda/mx_kernels/mxfp8_extension.cpp \
              torchao/csrc/cuda/mx_kernels/mxfp8_cuda.cu \
              torchao/csrc/cuda/mx_kernels/mx_block_rearrange_2d_M_groups.cu \
              torchao/csrc/cuda/mx_kernels/fused_pad_token_groups.cu
        echo "Removed mxfp8 sources: skipping _C_mxfp8 extension for CUDA 13.x"
    fi
else
    # CPU build: pure Python mode, no C++ compilation.
    # C++ CPU kernels can be enabled in a future bump once macOS/Windows coverage
    # is validated.
    export USE_CPP=0
fi

$PYTHON -m pip install . -vv --no-deps --no-build-isolation
