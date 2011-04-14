#!/usr/bin/env perl

chdir 'lib/App/PFM';

foreach (<*.pm>, <Screen/*.pm>, <Job/*.pm>) {
	system "perl -cw $_";
}

