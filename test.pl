#!/usr/bin/env perl
#
##########################################################################
#
# Name:         test.pl
# Version:      0.12
# Author:       Rene Uittenbogaard
# Date:         2010-09-16
# Usage:        test.pl
# Description:  Test the pfm script and the associated libraries for
#		syntax errors (using perl -cw).
#		Additionally, try to bootstrap the pfm application.
#

##########################################################################
# declarations

use App::PFM::Application;

use POSIX;
use strict;

##########################################################################
# functions

sub produce_output {
	# child process: perform tests
	my $silent = 1;
	my $libdir = POSIX::getcwd() . '/lib';

	foreach (<lib/App/PFM/*.pm>,
		<lib/App/PFM/Config/*.pm>,
		<lib/App/PFM/Job/*.pm>,
		<lib/App/PFM/OS/*.pm>,
		<lib/App/PFM/Screen/*.pm>)
	{
		system "perl -I $libdir -cw $_";
	}

	system 'perl -cw pfm';

	my $pfm = new App::PFM::Application();
	$pfm->bootstrap($silent);
	print "pfm bootstrap OK\n" if $pfm->{_bootstrapped};
}

sub filter_output {
	# parent process: filter result
	while (<HANDLE>) {
		s/\e\[(1;1H|\d+;1H|H|2J|\?12;25h|\?9[hl]|34l)//g;
		print;
	}
	#print "\n";
}

sub main {
	# setup pipe
	my $childpid = open(HANDLE, "-|");
	die "cannot fork(): $!" unless (defined $childpid);

	if ($childpid) {
		# parent
		filter_output();
	} else {
		# child
		produce_output();
	}
}

##########################################################################
# main

main();

__END__

