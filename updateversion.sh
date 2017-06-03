#!/usr/bin/env bash

shopt -s extglob

GITROOT=$(git rev-parse --show-toplevel)
cd $GITROOT

previous_vw="$(grep 'ds Vw .... pfm.pl [0-9]\.[0-9][0-9]\.[0-9]' pfm)"
previousver="${previous_vw##*pfm.pl }"

if [ -z "$previousver" ]; then
	echo "Cannot determine previous version, exiting"
	exit 1
fi

newver=$(perl -le '
	($previousver = "'"$previousver"'") =~ tr/.//d;
	($newver = ++$previousver) =~ s/^(\d)(\d\d)(\d)$/$1\.$2\.$3/;
	print $newver;
')

echo "Previous version: '$previousver'"
echo "Current  version: '$newver'"

if [ "$previousver" = "$newver" ]; then
	echo "Nothing to do, exiting"
	exit 1
fi

# https://github.com/metaperl/binn/blob/master/treesed.pl

treesed "$previousver" "$newver"	\
	-files README pfm pfmrcupdate lib/App/PFM/Application.pm

treesed "# @.#. App::PFM::Config::Update $previousver"	\
	"# @(#) App::PFM::Config::Update $newver"	\
	-files lib/App/PFM/Config/Update.pm


treesed	"# Version:		$previousver"	\
	"# Version:		$newver"	\
	-files lib/App/PFM/Config/Update.pm
	

