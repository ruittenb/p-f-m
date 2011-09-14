#!/usr/bin/env perl
#
##########################################################################
#
# Name:         test.pl
# Version:      0.15
# Author:       Rene Uittenbogaard
# Date:         2010-10-23
# Usage:        test.pl
# Description:  Test the pfm script and the associated libraries for
#		syntax errors (using perl -cw).
#		Additionally, try to bootstrap the pfm application.
#

##########################################################################
# declarations

# for development
use lib '/usr/local/share/perl/devel/lib';

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

	system "perl -I $libdir -cw pfm";

	my $pfm = new App::PFM::Application();
	$pfm->bootstrap($silent);
	# terminal is in raw mode here
	printf "pfm bootstrap %s", $pfm->{_bootstrapped} ? 'OK' : 'not OK';
	$pfm->shutdown($silent);
	# terminal is in cooked mode here
	printf "\npfm shutdown %s\n", $pfm->{_bootstrapped} ? 'not OK' : 'OK';
}

sub filter_output {
	my $handle = shift;
	# parent process: filter result
	while (<$handle>) {
		s/\e\[([0-9;]*H|2J|\?[0-9;]+[hl])//g;
		print;
	}
}

sub main {
	# setup pipe
	my $childpid = open(HANDLE, "-|");
	die "cannot fork(): $!" unless (defined $childpid);

	if ($childpid) {
		# parent
		filter_output(*HANDLE);
	} else {
		# child
		produce_output();
	}
}

##########################################################################
# main

main();

__END__

