#!/bin/bash

THISDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$THISDIR"
cd ..

mkdir -p build
cd build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.8/bin/nvcc \
    -DCUDAToolkit_ROOT=/usr/local/cuda-12.8 \
    -DCMAKE_CUDA_ARCHITECTURES=89
make -j$(nproc)

exit 0
