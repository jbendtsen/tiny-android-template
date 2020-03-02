#!/bin/bash

REPO="https://dl.google.com/dl/android/maven2"

PKG_OUTPUT="lib"

# You will almost certainly need to change this variable
KOTLIN_LIB_DIR="/usr/share/kotlin/lib"

ANDROID_VER="android-29"
BUILD_VER="29.0.3"

SDK_DIR="../Sdk"
TOOLS_DIR="$SDK_DIR/build-tools/$BUILD_VER"
PLATFORM_DIR="$SDK_DIR/platforms/$ANDROID_VER"

JAR_TOOLS="java -Xmx1024M -Xss1m -jar $TOOLS_DIR/lib"

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
