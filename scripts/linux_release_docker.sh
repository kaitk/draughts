#!/bin/bash
# Runs inside ubuntu:22.04 (amd64), from docs/development.md: builds the Linux release from a clone of the repo mounted at /src, into /out.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -yq xz-utils curl gnupg python3 git cmake ninja-build pkg-config binutils ca-certificates \
  libwayland-dev libxkbcommon-dev libdecor-0-dev wayland-protocols \
  libegl-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev \
  libxss-dev libxtst-dev libasound2-dev libpulse-dev libpipewire-0.3-dev libjack-dev \
  libsndio-dev libdbus-1-dev libibus-1.0-dev libudev-dev liburing-dev
curl -s https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor > /etc/apt/trusted.gpg.d/llvm.gpg
echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-20 main" > /etc/apt/sources.list.d/llvm.list
apt-get update -q && apt-get install -yq clang-20
git config --global --add safe.directory '*'
git clone -q /src /work && cd /work
git submodule update --init --recursive
mkdir -p build && cd build
curl -sLO https://github.com/aardappel/goose/releases/download/v2026.4/goose-v2026.4-linux-x64.tar.gz
tar xzf goose-v2026.4-linux-x64.tar.gz && rm goose-v2026.4-linux-x64.tar.gz
curl -sLO https://github.com/shader-slang/slang/releases/download/v2026.18.2/slang-2026.18.2-linux-x86_64.tar.gz
mkdir -p slang && tar xzf slang-2026.18.2-linux-x86_64.tar.gz -C slang && rm slang-2026.18.2-linux-x86_64.tar.gz
curl -sLO https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-x86_64.tar.gz
tar xzf cmake-3.31.6-linux-x86_64.tar.gz && rm cmake-3.31.6-linux-x86_64.tar.gz
curl -sL -o vk.tar.xz https://sdk.lunarg.com/sdk/download/1.4.363.0/linux/vulkansdk-linux-x86_64-1.4.363.0.tar.xz
mkdir -p vulkansdk && tar xJf vk.tar.xz -C vulkansdk && rm vk.tar.xz
export VULKAN_SDK="$PWD/vulkansdk/1.4.363.0/x86_64"
export PATH="$VULKAN_SDK/bin:$PWD/cmake-3.31.6-linux-x86_64/bin:$PATH" CMAKE_LIBRARY_PATH="$VULKAN_SDK/lib/VulkanLoader/lib"
cd ..
git clone -q --recursive https://github.com/kaitk/goose-ngfx.git ../goose-ngfx
NGFX_SLANGC="$PWD/build/slang/bin/slangc" CC=clang-20 python3 scripts/linux.py --release
objdump -T build/linux/release/Draughts/draughts | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1
cp build/linux/release/Draughts-*-linux-x64.tar.gz /out/
sha256sum /out/*.tar.gz
