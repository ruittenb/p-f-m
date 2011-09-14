#!/usr/bin/env bash

TRASH=/tmp

if pwd -P | grep -qs dist; then
	:
else
	echo "Make sure you are in the dist directory!" 1>&2
	exit 1
fi

mv TODO Build.PL lib-App-PFM updateversion.sh distribute.sh $TRASH
cd lib/App/PFM/
mv critic.log criticise.sh debug.sh pfm $TRASH


