#!/bin/bash

# You will definitely need to change this variable
KOTLIN_LIB_DIR="C:/Program Files/kotlinc/lib"

ANDROID_VER="android-29"
BUILD_VER="29.0.3"

SDK_DIR="../Sdk"
TOOLS_DIR="$SDK_DIR/build-tools/$BUILD_VER"
PLATFORM_DIR="$SDK_DIR/platforms/$ANDROID_VER"

[ ! -d "build" ] && mkdir "build"

[ -f "build/classes.dex" ] && mv "build/classes.dex" "build/classes_prev.dex"

# It would be great if d8 could let you specify the name of the output DEX file...
java -Xmx1024M -Xss1m -cp $TOOLS_DIR/lib/d8.jar com.android.tools.r8.D8 --intermediate "$KOTLIN_LIB_DIR/kotlin-stdlib.jar" --classpath $PLATFORM_DIR/android.jar --output build || exit

mv "build/classes.dex" "build/kotlin.dex"
[ -f "build/classes_prev.dex" ] && mv "build/classes_prev.dex" "build/classes.dex"