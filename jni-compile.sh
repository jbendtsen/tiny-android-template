#!/bin/bash
# It is strongly encouraged that you modify this script to suit your needs

source includes.sh

OUTPUT="libjni-example.so"

#CPP_FILES=`find src -name "*.cpp"`
C_FILES=`find src -name "*.c"`

INCLUDE_DIRS="-I$NDK_INCLUDE_DIR"
LIB_DIRS="-L$NDK_LIB_DIR/aarch64-linux-android/$API_LEVEL"

[ ! -d ${TARGET_ARCHES[0]} ] && $CMD_MKDIR ${TARGET_ARCHES[0]}
$NDK_BIN_DIR/clang-12 --target=aarch64-linux-android$API_LEVEL -shared -fPIC $INCLUDE_DIRS $LIB_DIRS $LIBS $C_FILES -o ${TARGET_ARCHES[0]}/$OUTPUT
