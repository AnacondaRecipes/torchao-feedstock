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
    # CUDA_HOME is set by conda-build's compiler('cuda') activation scripts.
else
    # CPU build: pure Python mode, no C++ compilation.
    # C++ CPU kernels can be enabled in a future bump once macOS/Windows coverage
    # is validated.
    export USE_CPP=0
fi

$PYTHON -m pip install . -vv --no-deps --no-build-isolation
