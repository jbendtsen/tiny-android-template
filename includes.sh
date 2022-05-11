#!/bin/bash
# Roughly arranged in descending order of how likely you'll need to change each value

HOST_OS="linux-x86_64"
API_LEVEL="30"
ANDROID_VERSION="11"
NDK_VERSION="r23-beta4"
TARGET_ARCHES=( "arm64-v8a" )
SDK_DIR="../Sdk"
KOTLIN_LIB_DIR="/usr/share/kotlin/lib"

REPO="https://dl.google.com/dl/android/maven2"

KEYSTORE="keystore.jks"
KS_PASS="123456"

TOOLS_DIR="$SDK_DIR/android-$ANDROID_VERSION"
PLATFORM_DIR="$SDK_DIR/android-$ANDROID_VERSION"

NDK_DIR="$SDK_DIR/android-ndk-$NDK_VERSION"
NDK_BIN_DIR="$NDK_DIR/toolchains/llvm/prebuilt/$HOST_OS/bin"
NDK_INCLUDE_DIR="$NDK_DIR/toolchains/llvm/prebuilt/$HOST_OS/usr/sysroot/include"
NDK_LIB_DIR="$NDK_DIR/toolchains/llvm/prebuilt/$HOST_OS/usr/sysroot/lib"

LIB_RES_DIR="lib/res"
LIB_CLASS_DIR="lib/classes"

PKG_OUTPUT="lib"

JAR_TOOLS="java -Xmx1024M -Xss1m -jar $TOOLS_DIR/lib"

CMD_7Z="7z"
CMD_MKDIR="mkdir"
CMD_RENAME="mv"
CMD_DELETE="rm -rf"
CMD_FIND="/usr/bin/find"
CMD_CURL="curl"
CMD_SED="sed"
CMD_JAR="jar"
CMD_JAVA="java"
CMD_JAVAC="javac"
CMD_KOTLINC="kotlinc"

CMD_ADB="$SDK_DIR/platform-tools/adb"
CMD_D8="$CMD_JAVA -Xmx1024M -Xss1m -cp $TOOLS_DIR/lib/d8.jar com.android.tools.r8.D8"
