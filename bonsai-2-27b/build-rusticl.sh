#!/bin/sh
# Runs inside alpine:edge (aarch64, musl): builds Mesa 26.2.6 Rusticl + panfrost with the
# bifrost-v7-idp patch already applied to /w/mesa-26.2.6. Output: /w/inst (libRusticlOpenCL + libgallium).
set -e
apk add -q build-base meson ninja python3 py3-mako py3-yaml py3-packaging py3-ply bison flex glslang \
  libdrm-dev zlib-dev zstd-dev expat-dev elfutils-dev llvm-dev clang-dev spirv-llvm-translator-dev \
  libclc-dev spirv-tools-dev linux-headers rust cargo rust-bindgen cbindgen 2>&1 | tail -2
cd /w/mesa-26.2.6
[ -d build ] || meson setup build --prefix=/usr --buildtype=release -Dgallium-drivers=panfrost -Dvulkan-drivers= \
  -Dgallium-rusticl=true -Dplatforms= -Dglx=disabled -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false \
  -Dllvm=enabled -Dshared-llvm=enabled -Dmesa-clc=enabled -Dprecomp-compiler=enabled -Dvideo-codecs= -Dtools= \
  -Dbuild-tests=false -Dgbm=disabled -Dglvnd=disabled > /w/meson.log 2>&1 || { tail -30 /w/meson.log; exit 1; }
ninja -C build -j12 > /w/ninja.log 2>&1 || { grep -E "error|FAILED" /w/ninja.log | head -20; exit 1; }
rm -rf /w/inst && DESTDIR=/w/inst ninja -C build install > /w/install.log 2>&1
find /w/inst -name "*.so*" -o -name "*.icd" | head -20
