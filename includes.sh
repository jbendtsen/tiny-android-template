#!/bin/bash
# Roughly arranged in descending order of how likely you'll need to change each value

HOST_OS="windows-x86_64" # use "windows-x86_64" for windows, and "linux-x86_64" for linux
API_LEVEL="28"
ANDROID_VERSION="10"
NDK_VERSION="23.0.7599858"
TARGET_ARCHES=( "arm64-v8a" )
SDK_DIR="C:/Android/sdk"
KOTLIN_LIB_DIR="/usr/share/kotlin/lib"

REPO="https://dl.google.com/dl/android/maven2"

KEYSTORE="keystore.jks"
KS_PASS="123456"

TOOLS_DIR="$SDK_DIR/build-tools/28.0.3"
PLATFORM_DIR="$SDK_DIR/platforms/android-28"

NDK_DIR="$SDK_DIR/ndk/${NDK_VERSION}"
NDK_BIN_DIR="$NDK_DIR/toolchains/llvm/prebuilt/$HOST_OS/bin"
NDK_INCLUDE_DIR="$NDK_DIR/toolchains/llvm/prebuilt/$HOST_OS/usr/sysroot/include"
NDK_LIB_DIR="$NDK_DIR/toolchains/llvm/prebuilt/$HOST_OS/usr/sysroot/lib"

LIB_RES_DIR="lib/res"
LIB_CLASS_DIR="lib/classes"

PKG_OUTPUT="lib"

JAR_TOOLS="java -Xmx1024M -Xss1m -jar $TOOLS_DIR/lib"

CMD_7Z="7z"
CMD_MKDIR="mkdir" # use "mkdir" for windows, and "mkdir" for linux
CMD_RENAME="ren" # use "ren" for windows, and "mv" for linux
CMD_COPY_RECURSIVE="xcopy" # use "xcopy" for windows, and "cp -r" for linux
CMD_DELETE="rmdir /s /q" # use "rmdir /s /q" for windows, and "rm -rf" for linux
CMD_FIND_SRC_JAVA="ls -r src/**.java" # use "ls -r src/**.java" for windows, and "usr/bin/find src -name \"*.java\"" for linux
CMD_FIND_SRC_KOTLIN="ls -r src/**.kt" # use "ls -r src/**.kt" for windows, and "usr/bin/find src -name \"*.kt\"" for linux
CMD_CURL="curl"
CMD_SED="sed"
CMD_JAR="jar"
CMD_JAVA="java"
CMD_JAVAC="javac"
CMD_KOTLINC="kotlinc"

CMD_ADB="$SDK_DIR/platform-tools/adb"
CMD_D8="$CMD_JAVA -Xmx1024M -Xss1m -cp $TOOLS_DIR/lib/d8.jar com.android.tools.r8.D8"

DEV_NULL="NUL" # use "NUL" for windows, and "/dev/null" for linux
