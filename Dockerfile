# =============================================================================
# SAM3DBody-cpp
#
# Base: CUDA 12.8 + cuDNN 9 on Ubuntu 22.04
#
# Build:
#   docker build --build-arg CUDA_ARCH=89 -t sam3dbody .
#   # CUDA_ARCH: 89=RTX 40xx  86=RTX 30xx  75=RTX 20xx
#
# Run (webcam):
#   docker run --gpus all --rm \
#     -v ./onnx:/app/onnx:ro \
#     --device /dev/video0 \
#     -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
#     sam3dbody
#
# Or use docker-compose:
#   docker compose up
# =============================================================================

FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

ARG CUDA_ARCH=89
ARG OPENCV_VERSION=4.8.0

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV ONNX_DIR=/app/onnx

# -----------------------------------------------------------------------------
# 1. System dependencies
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential cmake git wget unzip ca-certificates \
    # OpenCV build deps
    libgtk-3-dev \
    libavcodec-dev libavformat-dev libswscale-dev libavutil-dev \
    libtbb-dev libjpeg-dev libpng-dev libtiff-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libv4l-dev v4l-utils \
    # OpenGL / GLEW (for fast_sam_3dbody_render)
    libglew-dev libgl1-mesa-dev libglu1-mesa-dev \
    libxrandr-dev libx11-dev \
    # QR sync tool (optional)
    libqrencode-dev \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. OpenCV from source  (4.7+ needed for aruco API)
# -----------------------------------------------------------------------------
RUN wget -q https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip \
         -O /tmp/opencv.zip && \
    wget -q https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip \
         -O /tmp/opencv_contrib.zip && \
    unzip -q /tmp/opencv.zip         -d /tmp && \
    unzip -q /tmp/opencv_contrib.zip -d /tmp && \
    cmake -S /tmp/opencv-${OPENCV_VERSION} \
          -B /tmp/opencv-build \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib-${OPENCV_VERSION}/modules \
          -DBUILD_TESTS=OFF \
          -DBUILD_PERF_TESTS=OFF \
          -DBUILD_EXAMPLES=OFF \
          -DBUILD_DOCS=OFF \
          -DWITH_CUDA=OFF \
          -DWITH_GSTREAMER=ON \
          -DWITH_V4L=ON \
          -DWITH_FFMPEG=ON && \
    cmake --build /tmp/opencv-build --parallel $(nproc) && \
    cmake --install /tmp/opencv-build && \
    ldconfig && \
    rm -rf /tmp/opencv*

# -----------------------------------------------------------------------------
# 3. Build SAM3DBody-cpp
# -----------------------------------------------------------------------------
WORKDIR /app
COPY . .

RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} && \
    cmake --build build --parallel $(nproc)

# -----------------------------------------------------------------------------
# 4. Entrypoint
# -----------------------------------------------------------------------------
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["0"]
