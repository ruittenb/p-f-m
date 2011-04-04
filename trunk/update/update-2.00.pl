#!/usr/bin/perl -p

# this updates the framecolors for version 2.00

# use this script as a filter, like you would an awk program, e.g.
# mend_your_cmnds.pl ~/.pfm/.pfmrc > ~/.pfm/.pfmrc.new

s/(^|:)header=/${1}menu=/;
s/(^|:)title=/${1}headings=/;

