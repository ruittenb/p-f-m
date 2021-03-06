#!/usr/bin/env perl
#
##########################################################################
#
# Name:         test.pl
# Version:      0.22
# Author:       Rene Uittenbogaard
# Date:         2017-06-03
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
use Module::Load;

use POSIX;
use strict;

use warnings;
use diagnostics;

##########################################################################
# functions

sub produce_output {
	# child process: perform tests
	my $gitroot   = qx(git rev-parse --show-toplevel);
	chomp($gitroot);
	my $libdir    = "$gitroot/lib";
	my $scriptdir = "$gitroot";
	my $silent    = 1;
	my $critic;
	eval {
		load 'Perl::Critic';
		$critic = Perl::Critic->new(
			-verbose  => "%F(%l,%c): %s: %m\n",
			-severity => 'stern');
	};

	foreach (glob("$libdir/App/PFM/*.pm"),
		 glob("$libdir/App/PFM/Browser/*.pm"),
		 glob("$libdir/App/PFM/Config/*.pm"),
		 glob("$libdir/App/PFM/Job/*.pm"),
		 glob("$libdir/App/PFM/OS/*.pm"),
		 glob("$libdir/App/PFM/Screen/*.pm"))
	{
#		print $critic->critique($_) if defined $critic;
		system "perl -I $libdir -cw $_";
	}

	system "perl -I $libdir -cw $scriptdir/pfm";

	my $pfm = App::PFM::Application->new();
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
	my $childpid = open my $handle, "-|";
	die "cannot fork(): $!" unless (defined $childpid);

	if ($childpid) {
		# parent
		filter_output($handle);
	} else {
		# child
		produce_output();
	}
}

##########################################################################
# main

main();

__END__

