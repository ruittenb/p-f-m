#!/usr/bin/perl -p

# this adds a diskinfo column (f-column) to pre-1.91.7 config files

# use this script as a filter, like you would an awk program, e.g.
# mend_colors.pl ~/.pfm/.pfmrc > ~/.pfm/.pfmrc.new


s/^([^#].*nnn.*)(:\\?)$/$1 ffffffffffffff$2/;
s/ layouts must not be wider than this! /-------------- file info -------------/;


