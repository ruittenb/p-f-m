#!/usr/bin/env perl
#
##########################################################################
# @(#) pfm.pl 2010-03-27 v2.00.0
#
# Name:			pfm
# Version:		2.00.0
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Usage:		pfm [ <directory> ] [ -s, --swap <directory> ]
#				    [ -l, --layout <number> ]
#				pfm { -v, --version | -h, --help }
# Requires:		Term::ReadLine::Gnu (preferably)
#				Term::ScreenColor
#				Getopt::Long
#				LWP::Simple
# Description:	Personal File Manager for Unix/Linux
#				Based on PFM.COM for DOS.
#

use lib '/home/ruitten/Desktop/projects/pfm-2.00.0/lib';

use PFM::Application;

END {
	# in case something goes wrong
	system qw(stty -raw echo);
}

##########################################################################
# main

$pfm = new PFM::Application();
$pfm->run();

# vim: set tabstop=4 shiftwidth=4:
