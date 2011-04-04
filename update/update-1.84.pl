#!/usr/bin/perl -p

# this updates (Y)our commands for version 1.84

# use this script as a filter, like you would an awk program, e.g.
# mend_your_cmnds.pl ~/.pfm/.pfmrc > ~/.pfm/.pfmrc.new

s/^(\s*)([[:upper:]])(\s*):(.*)$/$1your[\l$2]$3:$4/;
s/^(\s*)([[:lower:]])(\s*):(.*)$/$1your[\u$2]$3:$4/;

