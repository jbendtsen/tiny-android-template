#!/bin/bash

ADB="../Sdk/platform-tools/adb"
MF=`cat AndroidManifest.xml`
TERM="package=[\'\"]([a-z0-9.]+)"

if [[ "$MF" =~ $TERM ]]
then
	package="${BASH_REMATCH[1]}"
	$ADB install -r -t app.apk && \
	$ADB shell am start -n $package/.MainActivity
else
	echo Could not find a suitable package name inside AndroidManifest.xml
	exit
fi
