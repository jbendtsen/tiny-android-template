#!/bin/python
# It is strongly encouraged that you modify this script to suit your needs

import os

ARCHITECTURE_MAP = {
    "aarch64": "arm64-v8a",
    "armv7a": "armeabi-v7a",
    "i686": "x86",
    "x86_64": "x86_64"
}

TARGET_ARCHES = ["aarch64"]

HOST_OS = "windows-x86_64" # use "windows-x86_64" for windows, and "linux-x86_64" for linux
API_LEVEL = "33"
NDK_VERSION = "23.0.7599858"
SDK_DIR = "C:/Android/sdk"

NDK_DIR = f"{SDK_DIR}/ndk/$NDK_VERSION"
NDK_BIN_DIR = f"{NDK_DIR}/toolchains/llvm/prebuilt/$HOST_OS/bin"
NDK_INCLUDE_DIR = f"{NDK_DIR}/toolchains/llvm/prebuilt/$HOST_OS/usr/sysroot/include"
NDK_LIB_DIR = f"{NDK_DIR}/toolchains/llvm/prebuilt/$HOST_OS/usr/sysroot/lib"

OUTPUT = "libjni-example.so"
LIBS = ""

INCLUDE_DIRS = f"-I{NDK_INCLUDE_DIR}"

SOURCE_DIRS = ["src"]
SOURCE_EXTS = [".c"]

for arch in TARGET_ARCHES:
    sources = []
    for d in SOURCE_DIRS:
        ls = os.listdir(d)
        for f in ls:
            is_source = False
            for e in SOURCE_EXTS:
                if f.endswith(e):
                    is_source = True
                    break
            if not is_source:
                continue
            filepath = d + "/" + f
            if os.path.isfile(filepath):
                sources.append(filepath)

    lib_dirs = f"-L{NDK_LIB_DIR}/{arch}-linux-android/{API_LEVEL}"
    cmd = f"{NDK_BIN_DIR}/clang-12 --target={arch}-linux-android{API_LEVEL} -shared -fPIC {INCLUDE_DIRS} {lib_dirs} {LIBS} {" ".join(sources)} -o "
    cmd += ARCHITECTURE_MAP[arch] + "/" + OUTPUT

    os.mkdir(ARCHITECTURE_MAP[arch])
    os.system(cmd)
