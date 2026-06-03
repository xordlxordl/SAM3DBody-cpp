#!/bin/bash
# Docker entrypoint — no WSL2/anaconda workarounds needed inside the container.
#
# Usage (via docker run):
#   <image>            → webcam index 0
#   <image> /dev/video1
#   <image> video.mp4
#   <image> image.jpg

ONNX="${ONNX_DIR:-/app/onnx}"

if [ ! -f "${ONNX}/pipeline.gguf" ]; then
    echo "ERROR: model files not found in ${ONNX}"
    echo "Mount the onnx/ directory: -v ./onnx:/app/onnx:ro"
    exit 1
fi

exec /app/build/fast_sam_3dbody_run \
    --onnx-dir "${ONNX}" \
    --gguf     "${ONNX}/pipeline.gguf" \
    --yolo     "${ONNX}/yolo.onnx" \
    --from     "${1:-0}" \
    "${@:2}"
