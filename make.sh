#!/bin/bash

# This script makes the following assumptions:
#  1) You have a local copy of the Android SDK
#  2) You have an installed copy of the Java Development Kit (JDK)
#  3) If you are using AAR libraries (such as the AndroidX suite), you have copied/downloaded them to the lib directory and have run export-libs.pl then link.pl
#  4) You have already created a KeyStore file using keytool (comes with the JRE/JDK)

ANDROID_VER="android-29"
BUILD_VER="29.0.3"

SDK_DIR="../Sdk"
TOOLS_DIR="$SDK_DIR/build-tools/$BUILD_VER"
PLATFORM_DIR="$SDK_DIR/platforms/$ANDROID_VER"

JAR_TOOLS="java -Xmx1024M -Xss1m -jar $TOOLS_DIR/lib"

KEYSTORE="keystore.jks"
KS_PASS="123456"

if [ ! -d "build" ]; then
	echo Build directory not found.
	echo proj-compile-res.sh needs to be run before this script.
	exit
fi

echo Cleaning build...

rm build/*.apk 2> /dev/null

echo Compiling project source...

# Compile the project
javac -source 8 -target 8 -classpath "R;build/libs.jar" -bootclasspath $PLATFORM_DIR/android.jar -d build src/*.java build/R.java || exit

echo Compiling classes into DEX bytecode...

sources="build/com/example/test/*"
# [ -f "lib/classes.dex" ] && sources="$sources lib/classes.dex"
java -Xmx1024M -Xss1m -cp $TOOLS_DIR/lib/d8.jar com.android.tools.r8.D8 --classpath $PLATFORM_DIR/android.jar build/classes.dex $sources || exit

echo Creating APK...

res="build/res.zip"
[ -f "build/res_libs.zip" ] && res+=" build/res_libs.zip"
$TOOLS_DIR/aapt2 link -o build/unaligned.apk --manifest AndroidManifest.xml -I $PLATFORM_DIR/android.jar --emit-ids ids.txt $res || exit

# Pack the DEX file into a new APK file
# $TOOLS_DIR/aapt package -f -m -F build/unaligned.apk -M AndroidManifest.xml -S res -I $PLATFORM_DIR/android.jar
$TOOLS_DIR/aapt add build/unaligned.apk classes.dex || exit

rm classes.dex

# Align the APK
$TOOLS_DIR/zipalign -f 4 build/unaligned.apk build/aligned.apk || exit

echo Signing APK...

# Sign the APK
$JAR_TOOLS/apksigner.jar sign --ks $KEYSTORE --ks-pass "pass:$KS_PASS" --min-sdk-version 15 --out app.apk build/aligned.apk
