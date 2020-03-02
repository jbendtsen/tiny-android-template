#!/bin/bash

# Naive package downloader for the Jetpack/AndroidX suite
# Check out https://developer.android.com/jetpack/androidx/versions for a list of packages and versions

source includes.sh

get() {
	fname="$2.aar"
	echo -n "$2: "
	$CMD_CURL -s -f "$REPO/$1/$fname" -o "$PKG_OUTPUT/$fname"
	if [ $? -eq 0 ]; then
		echo OK
	else
		fname="$2.jar"
		$CMD_CURL -s -f "$REPO/$1/$fname" -o "$PKG_OUTPUT/$fname"

		if [ $? -eq 0 ]; then
			echo OK
		else
			echo "ERROR ($?)"
		fi
	fi
}

get_naive() {
	path="androidx/$1/$1/$2"
	name="$1-$2"
	get $path $name
}

parse_then_get() {
	if [[ "$1" =~ '//' ]]; then
		IFS='/'
		read -ra tokens <<< "$1"
		fname="${tokens[-1]}"
		IFS=' '

		echo -n "$fname: "
		$CMD_CURL -s -f "$1" -o "$PKG_OUTPUT/$fname"
		if [ $? -eq 0 ]; then
			echo OK
		else
			echo "ERROR ($?)"
		fi
	elif [[ "$1" =~ ':' ]]; then
		IFS=':'
		arg=( $1 )
		IFS=' '

		prefix=${arg[0]//\./\/}
		path="$prefix/${arg[1]}/${arg[2]}"
		name="${arg[1]}-${arg[2]}"
		get $path $name
	else
		IFS=' '
		params=( $line )
		get_naive ${params[0]} ${params[1]}
	fi
}

if [ $# -lt 1 ]; then
	echo "AndroidX Package Downloader"
	echo "usage:   $0 <package> <version>"
	echo "         $0 <text file with lines of <packet> <version>>"
	echo "         $0 <gradle \"implementation\" format>"
	echo "example: $0 core 1.2.0"
	echo "         $0 list.txt"
	echo "         $0 androidx.core:core:1.2.0"
	exit
fi

[ ! -d "$PKG_OUTPUT" ] && mkdir -p "$PKG_OUTPUT"

if [ $# -eq 2 ]; then
	get_naive $1 $2
	exit
fi

if [[ "$1" =~ ':' ]]; then
	parse_then_get $1
else
	# Take out those pesky carriage returns
	list=`$CMD_SED "s/\r//" $1`

	while IFS= read -r line; do
		parse_then_get $line
	done <<< "$list"
fi
