#!/bin/bash
set -euxo pipefail

# Prevent setup.py from appending "+git<sha>" to the version — the source
# is a GitHub archive (not a git repo) so get_git_commit_id() returns "".
# Setting VERSION_SUFFIX="" keeps the version as "0.16.0" exactly.
export VERSION_SUFFIX=""

# Disable macOS/ARM experimental cmake-based CPU kernels for now.
# build_macos_arm_auto = (USE_CPP=1 and is_arm64 and is_macos) would otherwise
# trigger cmake-based TORCHAO_BUILD_CPU_AARCH64, which is not yet tested.
export BUILD_TORCHAO_EXPERIMENTAL=0

if [ "${cuda_compiler_version}" != "none" ]; then
    # CUDA build: compile C++/CUDA kernels.
    export USE_CPP=1

    # Match pytorch-feedstock's 2.10 CUDA arch lists for ABI alignment with pkgs/main
    # libtorch 2.10.0 (sm_70 kept for CUDA 12.x per pytorch/pytorch#157517; dropped in 13).
    if [[ "${cuda_compiler_version:0:2}" == "12" ]]; then
        export TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;9.0;10.0;12.0+PTX"
    else
        export TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;9.0;10.0;12.0+PTX"
    fi

    # CUDA 12.x requires gcc <14.0 per torch/utils/cpp_extension.py CUDA_GCC_VERSIONS,
    # but pkgs/main only ships gcc 14.3.0 — same gcc that built pytorch 2.10. Bypass
    # the consumer-side check; the libstdc++ ABI is consistent.
    if [[ "${cuda_compiler_version:0:2}" == "12" ]]; then
        export TORCH_DONT_CHECK_COMPILER_ABI=1
    fi

    # CUTLASS SM90a/SM100a sources (rowwise_scaled_linear_sparse_cutlass_* and
    # to_sparse_semi_structured_cutlass_sm9x) emit "default arguments are only
    # permitted for function parameters [-fpermissive]" under both CUDA 12.9 and
    # 13.x nvcc. Disable them for all CUDA builds; the main _C extension is unaffected.
    python3 -c "
import pathlib
p = pathlib.Path('setup.py')
txt = p.read_text()
txt = txt.replace(
    'build_for_sm90a, build_for_sm100a = get_cutlass_build_flags()',
    'build_for_sm90a, build_for_sm100a = False, False  # disabled: nvcc incompatibility'
)
p.write_text(txt)
print('Patched setup.py: disabled CUTLASS SM90a/SM100a')
"

    # NOTE: the mxfp8-source removal workaround used at 0.17.0 is not needed here —
    # 0.16.0's mx_kernels do not use __cudaLaunch (removed in CUDA 13.0).
else
    # CPU build: pure Python mode, no C++ compilation.
    export USE_CPP=0
fi

$PYTHON -m pip install . -vv --no-deps --no-build-isolation
