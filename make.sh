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

# Cygwin's 'find' clashes with Windows' 'find' command on my system. This fix should still work on Unix.
FIND="/usr/bin/find"

if [ ! -d "build" ]; then
	echo Build directory not found.
	echo link.pl needs to be run before this script.
	exit
fi

echo Cleaning build...

# Deletes all folders and APK files inside the build folder
rm build/*.apk */ 2> /dev/null

echo Compiling project source...

java_list=`$FIND src -name "*.java"`
kt_list=`$FIND src -name "*.kt"`

# If string length of java_list > 2 then we've got some Java source
# I picked '2' in case newlines bump it up from 0, though it's likely overkill
found_src=0
if [ ${#java_list} -gt 2 ]; then
	javac -source 8 -target 8 -classpath "build/R.jar;build/libs.jar" -bootclasspath $PLATFORM_DIR/android.jar -d build $java_list || exit
	found_src=1
fi
if [ ${#kt_list} -gt 2 ]; then
	kotlinc -d build -cp "build/R.jar;build/libs.jar;$PLATFORM_DIR/android.jar" -jvm-target 1.8 $kt_list || exit
	found_src=1
fi

if (( ! $found_src )); then
	echo No project sources were found in the 'src' folder.
	exit
fi

echo Compiling classes into DEX bytecode...

dex_list="build/classes.dex"
[ -f "build/kotlin.dex" ] && dex_list+=" build/kotlin.dex"
java -Xmx1024M -Xss1m -cp $TOOLS_DIR/lib/d8.jar com.android.tools.r8.D8 --classpath $PLATFORM_DIR/android.jar $dex_list build/com/example/test/* || exit

echo Creating APK...

res="build/res.zip"
[ -f "build/res_libs.zip" ] && res+=" build/res_libs.zip"
$TOOLS_DIR/aapt2 link -o build/unaligned.apk --manifest AndroidManifest.xml -I $PLATFORM_DIR/android.jar --emit-ids ids.txt $res || exit

# Pack the DEX file into a new APK file
$TOOLS_DIR/aapt add build/unaligned.apk classes.dex || exit

rm classes.dex

# Align the APK
# I've seen the next step and this one be in the other order, but the Android reference site says it should be this way...
$TOOLS_DIR/zipalign -f 4 build/unaligned.apk build/aligned.apk || exit

echo Signing APK...

# Sign the APK
$JAR_TOOLS/apksigner.jar sign --ks $KEYSTORE --ks-pass "pass:$KS_PASS" --min-sdk-version 15 --out app.apk build/aligned.apk
