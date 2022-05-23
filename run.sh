#!/bin/bash

source includes.sh

MF=`cat AndroidManifest.xml`
TERM="package=[\'\"]([a-z0-9.]+)"

if [[ "$MF" =~ $TERM ]]
then
	package="${BASH_REMATCH[1]}"
	activity=".MainActivity"

	TERM="<activity([^>]+)"
	if [[ "$MF" =~ $TERM ]]; then
		tag="${BASH_REMATCH[1]}"
		TERM="[\'\"]([^\'\"]+)"
		[[ "$tag" =~ $TERM ]] && activity="${BASH_REMATCH[1]}"
	fi

	$CMD_ADB install -r -t app.apk && \
	$CMD_ADB shell am start -n $package/$activity
else
	echo Could not find a suitable package name inside AndroidManifest.xml
	exit
fi
