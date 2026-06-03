#!/bin/bash
# Environment setup for SAM3DBody-cpp on WSL2 with CUDA 12.8 + cuDNN 9 (via pip).
#
# Source this file before running any binary:
#   source scripts/run_env.sh
#   ./build/fast_sam_3dbody_run --onnx-dir ./onnx ...
#
# Or use exec_run.sh which sources this automatically.

# cuDNN 9 installed via: pip install nvidia-cudnn-cu12==9.*
CUDNN_LIB="/home/dave/anaconda3/lib/python3.11/site-packages/nvidia/cudnn/lib"

export LD_LIBRARY_PATH="${CUDNN_LIB}:/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Preload system glib 2.72 to override anaconda3's glib 2.69.
# Needed because OpenCV videoio has RUNPATH pointing to anaconda3/lib,
# which loads an older libglib that is missing g_log_set_debug_enabled.
export LD_PRELOAD="/lib/x86_64-linux-gnu/libglib-2.0.so.0 /lib/x86_64-linux-gnu/libgobject-2.0.so.0${LD_PRELOAD:+ $LD_PRELOAD}"
