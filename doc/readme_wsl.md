# SAM3DBody-cpp — WSL2 및 Docker 실행 가이드

이 문서는 **Windows WSL2** 환경과 **Docker** 환경에서 SAM3DBody-cpp를 빌드하고 실행하는 방법을 설명합니다.

검증 환경:
- Windows 11 + WSL2 (Ubuntu 22.04)
- NVIDIA GeForce RTX 4070 Ti (sm_89), 드라이버 591.86
- CUDA Toolkit 12.8 (`/usr/local/cuda-12.8`)
- cuDNN 9 (pip 설치)

---

## 목차

1. [WSL2 환경 설정](#1-wsl2-환경-설정)
2. [빌드](#2-빌드)
3. [WSL2에서 실행](#3-wsl2에서-실행)
4. [Docker로 빌드 및 실행](#4-docker로-빌드-및-실행)
5. [자주 발생하는 에러](#5-자주-발생하는-에러)

---

## 1. WSL2 환경 설정

### 1-1. CUDA Toolkit 12.8 설치

ORT 1.20.1 GPU 패키지는 **CUDA 12** 런타임이 필요합니다.  
시스템에 CUDA 12.x가 없으면 12.8을 설치합니다.

```bash
# NVIDIA 공식 저장소 추가 (Ubuntu 22.04 기준)
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get install -y cuda-toolkit-12-8
```

설치 후 확인:
```bash
/usr/local/cuda-12.8/bin/nvcc --version
```

### 1-2. cuDNN 9 설치 (pip 방식)

```bash
pip install "nvidia-cudnn-cu12==9.*"
```

> **주의**: PyTorch가 설치된 환경이라면 `nvidia-cudnn-cu12==8.9.2.26`이 이미 있을 수 있습니다.  
> 9.x 설치 시 PyTorch와 버전 충돌 경고가 나오지만 SAM3DBody-cpp 실행에는 문제없습니다.

설치된 libcudnn.so.9 경로 확인:
```bash
find ~/.local /home -name "libcudnn.so.9" 2>/dev/null
# 예: /home/dave/anaconda3/lib/python3.11/site-packages/nvidia/cudnn/lib/libcudnn.so.9
```

### 1-3. 기타 시스템 패키지

```bash
sudo apt-get install -y \
    build-essential cmake git \
    libopencv-dev \
    libglew-dev libgl1-mesa-dev \
    libx11-dev libqrencode-dev
```

> OpenCV는 4.7 이상이 필요합니다 (aruco API 변경).  
> Ubuntu 22.04 기본 패키지는 4.5이므로, 이미 최신 OpenCV가 `/usr/local`에 설치되어 있다면 그것을 사용합니다.

### 1-4. 모델 파일 준비

HuggingFace에서 모델 zip을 다운로드한 뒤 `onnx/` 폴더에 압축 해제합니다:

```
onnx/
├── backbone.onnx + backbone.onnx.data   (~4.8 GB, BF16, GPU 전용)
├── decoder.onnx
├── pipeline.gguf
├── yolo.onnx
├── body_model.lbs
├── keypoint_mapping.bin
└── correctives.bin
```

> `backbone.onnx`는 BFloat16 모델로 **CUDA GPU 필수**입니다.  
> CPU 전용 실행이 필요하면 `backbone_fp32.onnx`를 별도 다운로드 후 `--backbone backbone_fp32.onnx --cuda -1` 옵션을 사용하세요.

---

## 2. 빌드

```bash
cd SAM3DBody-cpp
bash scripts/build.sh
```

`scripts/build.sh` 내용:
```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.8/bin/nvcc \
    -DCUDAToolkit_ROOT=/usr/local/cuda-12.8 \
    -DCMAKE_CUDA_ARCHITECTURES=89
make -j$(nproc)
```

**`CUDA_ARCHITECTURES` GPU별 값:**

| GPU | 값 |
|---|---|
| RTX 40xx (4070 Ti / 4080 / 4090) | `89` |
| RTX 30xx (3080 / 3090) | `86` |
| RTX 20xx (2080) | `75` |
| GTX 16xx | `75` |

빌드 결과물:
```
build/
├── fast_sam_3dbody_run      ← 메인 CLI
├── fast_sam_3dbody_render   ← OpenGL 오버레이 렌더러
├── offline_sam_3dbody_render
└── libfast_sam_3dbody.so
```

---

## 3. WSL2에서 실행

### 3-1. 실행 환경 이슈 (WSL2 한정)

WSL2에서 Anaconda/Miniconda가 설치된 경우 두 가지 런타임 문제가 발생합니다:

| 문제 | 원인 | 해결 |
|---|---|---|
| `undefined symbol: g_log_set_debug_enabled` | OpenCV가 anaconda의 GLib 2.69를 로드, 시스템 libgio 2.72와 버전 불일치 | 시스템 libglib LD_PRELOAD |
| `libcudnn.so.9: cannot open shared object file` | cuDNN 9가 시스템 경로에 없음 | pip 설치 경로를 LD_LIBRARY_PATH에 추가 |

`scripts/run_env.sh`가 이 두 문제를 자동 처리합니다.

### 3-2. 간편 실행 (run.sh)

```bash
# 웹캠 (기본값 index 0)
./run.sh

# 특정 웹캠
./run.sh /dev/video1

# 비디오 파일
./run.sh video.mp4

# 이미지
./run.sh image.jpg

# 추가 옵션 전달
./run.sh 0 --cuda 0 --thresh 0.5
```

### 3-3. 직접 실행 (환경 변수 수동 설정)

```bash
# cuDNN 9 경로 (pip 설치 위치)
CUDNN_LIB=$(python3 -c "import nvidia.cudnn; import os; print(os.path.dirname(nvidia.cudnn.__file__))")/lib

source scripts/run_env.sh

./build/fast_sam_3dbody_run \
    --onnx-dir ./onnx \
    --gguf    ./onnx/pipeline.gguf \
    --yolo    ./onnx/yolo.onnx \
    --from    0
```

### 3-4. 주요 CLI 옵션

```
--onnx-dir PATH   모델 폴더 경로
--gguf     PATH   pipeline.gguf 경로
--yolo     PATH   yolo.onnx 경로
--from     SRC    입력 소스: 웹캠 인덱스(0,1..), /dev/videoX, 이미지/비디오 파일
--cuda     N      CUDA 장치 번호 (기본값 0; -1 = CPU)
--thresh   F      사람 감지 임계값 (기본값 0.3)
--bvh      PATH   BVH 모션캡처 파일 출력 경로
```

### 3-5. WSL2 웹캠 접근

WSL2는 기본적으로 USB 장치에 직접 접근이 안 됩니다.  
`usbipd-win`을 사용해 웹캠을 WSL2로 연결해야 합니다.

#### 설치 (최초 1회)

**Windows PowerShell (관리자):**
```powershell
winget install usbipd
```

#### 웹캠 BUSID 확인 및 바인딩 (최초 1회, 관리자 필요)

```powershell
# Windows PowerShell (관리자)
usbipd list              # 웹캠 BUSID 확인 (예: 6-1)
usbipd bind --busid 6-1  # 최초 1회만 필요
```

> `bind`는 최초 1회만 실행하면 재부팅 후에도 유지됩니다.

#### 웹캠 연결 / 해제 (매 세션)

`bind` 이후부터는 **일반 PowerShell 또는 WSL2**에서 실행 가능합니다:

```powershell
# Windows PowerShell (일반)
usbipd attach --wsl --busid 6-1   # WSL2에 연결
usbipd detach --busid 6-1         # 연결 해제
```

```bash
# WSL2에서도 직접 실행 가능
usbipd.exe attach --wsl --busid 6-1
```

#### run.sh 자동 연결

`./run.sh`는 웹캠 소스(`0`, `/dev/videoX`)를 지정할 경우  
`/dev/video0`이 없으면 `usbipd.exe`로 자동 탐색·연결을 시도합니다.

```bash
./run.sh        # /dev/video0 없으면 자동 attach 후 실행
./run.sh 0      # 동일
```

자동 연결이 실패하면 다음 메시지와 함께 필요한 조치를 안내합니다:

```
[run.sh] No webcam device found (/dev/video0).
         Install usbipd-win on Windows and run as Admin:
           usbipd bind --busid <BUSID>
         Then retry ./run.sh   (auto-attach will handle the rest)
```

#### WSL2에서 장치 확인

```bash
ls /dev/video*
# /dev/video0  /dev/video1  ...
```

---

## 4. Docker로 빌드 및 실행

Docker는 WSL2 환경 이슈(glib 충돌, cuDNN 경로 등)가 없어 더 간단합니다.

### 4-1. 사전 요구사항

- Docker Desktop (Windows) 설치 및 WSL2 통합 활성화
- NVIDIA Container Toolkit:

```bash
# WSL2 Ubuntu에서
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 4-2. 이미지 빌드

```bash
# RTX 40xx (sm_89)
docker build --build-arg CUDA_ARCH=89 -t sam3dbody .

# RTX 30xx (sm_86)
docker build --build-arg CUDA_ARCH=86 -t sam3dbody .
```

> **첫 빌드 시 OpenCV 소스 컴파일로 약 20~30분 소요됩니다.**

### 4-3. 실행

**웹캠 (기본값):**
```bash
docker run --gpus all --rm \
    -v ./onnx:/app/onnx:ro \
    --device /dev/video0 \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    sam3dbody
```

**비디오 파일:**
```bash
docker run --gpus all --rm \
    -v ./onnx:/app/onnx:ro \
    -v ./videos:/videos:ro \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    sam3dbody /videos/input.mp4
```

**이미지:**
```bash
docker run --gpus all --rm \
    -v ./onnx:/app/onnx:ro \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    sam3dbody /app/doc/screen.jpg
```

**BVH 출력:**
```bash
docker run --gpus all --rm \
    -v ./onnx:/app/onnx:ro \
    -v ./output:/output \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    sam3dbody input.mp4 --bvh /output/result.bvh
```

### 4-4. docker-compose (웹캠)

```bash
# docker-compose.yml의 CUDA_ARCH를 GPU에 맞게 수정 후
docker compose up --build   # 첫 실행 (빌드 포함)
docker compose up           # 이후 실행
```

### 4-5. X11 디스플레이 설정 (WSL2)

컨테이너에서 imshow 창을 띄우려면 X11 포워딩이 필요합니다:

```bash
# WSL2 터미널에서
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
xhost +local:docker
```

또는 Windows에 **VcXsrv** / **X410** 같은 X 서버를 설치하고 DISPLAY를 설정합니다.

---

## 5. 자주 발생하는 에러

### `symbol lookup error: libgio-2.0.so.0: undefined symbol: g_log_set_debug_enabled`

**원인**: Anaconda의 GLib 2.69가 로드되어 시스템 libgio 2.72와 충돌  
**해결**: `source scripts/run_env.sh` 또는 `./run.sh` 사용

---

### `Failed to load library libonnxruntime_providers_cuda.so: libcudnn.so.9: cannot open shared object file`

**원인**: cuDNN 9가 없거나 경로에 없음  
**해결**:
```bash
pip install "nvidia-cudnn-cu12==9.*"
source scripts/run_env.sh
```

---

### `free(): invalid pointer` (빌드 직후 충돌)

**원인**: CUDA 13.x nvcc로 빌드 + CUDA 12 ORT 런타임 → ABI 불일치  
**해결**: CUDA 12.8 nvcc로 재빌드
```bash
bash scripts/build.sh
```

---

### `Could not find an implementation for Expand(13) node`

**원인**: `backbone.onnx`가 BFloat16 모델 → ORT CPU EP 미지원  
**해결**: CUDA GPU 사용 필수. CPU 전용은 `backbone_fp32.onnx` 다운로드 후:
```bash
./run.sh 0 --backbone backbone_fp32.onnx --cuda -1
```

---

### `Cannot open input: 0` / `can't open camera by index`

**원인**: WSL2에 웹캠 장치(`/dev/video0`)가 없음 — usbipd 연결 필요  
**해결**:
```powershell
# Windows PowerShell (관리자, 최초 1회)
usbipd bind --busid 6-1
```
```bash
# WSL2 (매 세션 또는 run.sh 자동 처리)
usbipd.exe attach --wsl --busid 6-1
./run.sh
```

자세한 내용은 [3-5. WSL2 웹캠 접근](#3-5-wsl2-웹캠-접근) 참고.

---

### `Pipeline load failed` (모델 파일 없음)

**원인**: `onnx/` 폴더에 모델 파일이 없음  
**해결**: HuggingFace에서 모델 다운로드 및 압축 해제
```bash
unzip SAM3DBody-cpp-onnx-models.zip
```
