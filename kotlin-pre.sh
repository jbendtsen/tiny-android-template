#!/bin/bash

source includes.sh

[ ! -d "build" ] && $CMD_MKDIR "build"

$CMD_D8 --intermediate "$KOTLIN_LIB_DIR/kotlin-stdlib.jar" --classpath $PLATFORM_DIR/android.jar --output build || exit

$CMD_RENAME "build/classes.dex" "build/kotlin.dex"
