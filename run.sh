#!/bin/bash
# Quick-run: webcam (default) or any source passed as argument.
# Usage:
#   ./run.sh                    # webcam index 0
#   ./run.sh /dev/video1        # specific webcam
#   ./run.sh video.mp4          # video file
#   ./run.sh image.jpg          # single image

THISDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$THISDIR"

source scripts/run_env.sh

FROM="${1:-0}"

exec ./build/fast_sam_3dbody_run \
    --onnx-dir ./onnx \
    --gguf    ./onnx/pipeline.gguf \
    --yolo    ./onnx/yolo.onnx \
    --from    "$FROM" \
    "${@:2}"
