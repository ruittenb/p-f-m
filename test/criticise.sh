#!/usr/bin/env bash

GITROOT=$(git rev-parse --show-toplevel)

perlcritic --stern $GITROOT/lib/App/PFM \
	| grep -v 'Comma used to separate statements'		\
	| grep -v 'Pragma "constant" used'			\
	| grep -v 'Code before warnings are enabled'		\
	| grep -v 'Always unpack @_ first'			\
	| grep -v 'Expression form of "grep"'			\
	| grep -v 'Mixed high and low-precedence booleans'	\
	| cat

