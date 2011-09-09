#!/usr/bin/env perl

system 'perl -cw pfm';

chdir 'lib/App/PFM';

foreach (<*.pm>, <Screen/*.pm>, <Job/*.pm>) {
	system "perl -cw $_";
}

