#!/bin/bash

# Heavily based off https://github.com/authmane512/android-project-template

# This script makes the following assumptions:
#  1) You have a local copy of the Android SDK
#  2) You have an installed copy of the Java Development Kit (JDK)
#  3) You have already created a KeyStore file using keytool (comes with the JRE/JDK)

ANDROID_VER="android-29"
BUILD_VER="29.0.3"

SDK_DIR="../Sdk"
TOOLS_DIR="$SDK_DIR/build-tools/$BUILD_VER"
PLATFORM_DIR="$SDK_DIR/platforms/$ANDROID_VER"

JAR_TOOLS="java -Xmx1024M -Xss1m -jar $TOOLS_DIR/lib"

KEYSTORE="keystore.jks"
KS_PASS="123456"

rm -rf build
mkdir -p build/R

# Generate R.java (for accessing resources from code)
$TOOLS_DIR/aapt package -f -m -J build/R -M AndroidManifest.xml -S res -I $PLATFORM_DIR/android.jar

# Compile the project
javac -source 8 -target 8 -classpath build/R -bootclasspath $PLATFORM_DIR/android.jar -d build src/*.java

# Assemble the classes into a DEX file
#   For some reason, AAPT does not provide a way to specify where to place a file when using the "add" command.
#   Since classes.dex has to be at the root of the APK, we must output classes.dex to the current working directory.
$JAR_TOOLS/dx.jar --dex --no-optimize --output=classes.dex build

# Pack the DEX file into a new APK file
$TOOLS_DIR/aapt package -f -m -F build/unaligned.apk -M AndroidManifest.xml -S res -I $PLATFORM_DIR/android.jar
$TOOLS_DIR/aapt add build/unaligned.apk classes.dex > /dev/null

rm classes.dex

# Align the APK
$TOOLS_DIR/zipalign -f 4 build/unaligned.apk build/aligned.apk

# Sign the APK
$JAR_TOOLS/apksigner.jar sign --ks $KEYSTORE --ks-pass "pass:$KS_PASS" --out app.apk build/aligned.apk
