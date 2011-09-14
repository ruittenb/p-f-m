#!/usr/bin/env bash

if pwd -P | grep -qs dist; then
	:
else
	echo "Make sure you are in the dist directory!" 1>&2
	exit 1
fi

(
	cd lib/App/PFM/
	rm critic.log criticise.sh debug.sh pfm
)
rm TODO Build.PL lib-App-PFM updateversion.sh distribute.sh


