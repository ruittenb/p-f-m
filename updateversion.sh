#!/usr/bin/env bash

shopt -s extglob

currentdir=$(basename $(pwd -P)) # pfm-2.07.2-alpha
currentvrc=${currentdir##pfm-}
currentver=${currentvrc%-@(alpha|beta|stable|dist)}

if [ -z "$currentver" ]; then
	echo "Cannot determine current version, exiting"
	exit 1
fi

previous_vw="$(grep 'ds Vw .... pfm.pl [0-9]\.[0-9][0-9]\.[0-9]' pfm)"
previousver="${previous_vw##*pfm.pl }"

if [ -z "$previousver" ]; then
	echo "Cannot determine previous version, exiting"
	exit 1
fi

echo "Previous version: '$previousver'"
echo "Current  version: '$currentver'"

if [ "$previousver" = "$currentver" ]; then
	echo "Nothing to do, exiting"
	exit 1
fi


treesed "$previousver" "$currentver" \
	-files README pfm pfmrcupdate lib/App/PFM/Application.pm \
		lib/App/PFM/Config/Update.pm




