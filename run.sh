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

# ── WSL2 webcam auto-attach (usbipd) ─────────────────────────────────────────
# When FROM is a webcam (integer index or /dev/videoX) and the device doesn't
# exist yet, try to attach it from Windows via usbipd.
_is_webcam_src() {
    local s="$1"
    [[ "$s" =~ ^[0-9]+$ ]] || [[ "$s" == /dev/video* ]]
}

_attach_webcam() {
    local dev="/dev/video0"
    [[ "$FROM" == /dev/video* ]] && dev="$FROM"

    if [ -e "$dev" ]; then
        return 0
    fi

    # usbipd.exe is accessible from WSL2 when usbipd-win is installed on Windows
    if ! command -v usbipd.exe &>/dev/null; then
        echo "[run.sh] No webcam device found ($dev)."
        echo "         Install usbipd-win on Windows and run as Admin:"
        echo "           usbipd bind --busid <BUSID>"
        echo "         Then retry ./run.sh   (auto-attach will handle the rest)"
        exit 1
    fi

    echo "[run.sh] $dev not found — scanning for webcam via usbipd..."
    local busid
    busid=$(usbipd.exe list 2>/dev/null \
        | grep -i "webcam\|cam\|camera\|video\|c920\|c922\|c930\|brio\|StreamCam" \
        | grep -i "shared\|Not shared" \
        | head -1 \
        | awk '{print $1}')

    if [ -z "$busid" ]; then
        echo "[run.sh] No webcam found in usbipd list."
        echo "         Check Windows: usbipd list"
        echo "         Then bind (Admin PowerShell): usbipd bind --busid <BUSID>"
        exit 1
    fi

    echo "[run.sh] Found webcam at BUSID $busid — attaching to WSL2..."
    if ! usbipd.exe attach --wsl --busid "$busid" 2>&1; then
        echo "[run.sh] attach failed. If bind hasn't been done yet, run in"
        echo "         Windows PowerShell (Admin): usbipd bind --busid $busid"
        exit 1
    fi

    # Wait for the kernel to create the device node (up to 5 s)
    local i=0
    while [ ! -e "$dev" ] && [ $i -lt 10 ]; do
        sleep 0.5; (( i++ ))
    done

    if [ ! -e "$dev" ]; then
        echo "[run.sh] Device $dev still not available after attach."
        exit 1
    fi

    echo "[run.sh] $dev ready."
}

if _is_webcam_src "$FROM"; then
    _attach_webcam
fi

exec ./build/fast_sam_3dbody_run \
    --onnx-dir ./onnx \
    --gguf    ./onnx/pipeline.gguf \
    --yolo    ./onnx/yolo.onnx \
    --from    "$FROM" \
    "${@:2}"
