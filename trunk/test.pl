#!/usr/bin/env perl

use lib './lib';

use App::PFM::Application;

print "INC1:", join ":", @INC, "\n";
system 'perl -cw pfm';
print "INC2:", join ":", @INC, "\n";

$dir = 'lib/App/PFM';
print "INC3:", join ":", @INC, "\n";

foreach (<$dir/*.pm>, <$dir/Screen/*.pm>, <$dir/Job/*.pm>) {
	system "perl -cw $_";
}

print "INC4:", join ":", @INC, "\n";
print "INC5:", join ":", @INC, "\n";

$p = new App::PFM::Application();
#$p->bootstrap($silent = 1);
$p->screen->at(21,0);

