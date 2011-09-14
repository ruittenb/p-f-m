#!/usr/bin/env perl

use lib 'lib';

use App::PFM::Application;

system 'perl -cw pfm';

chdir 'lib/App/PFM';

foreach (<*.pm>, <Screen/*.pm>, <Job/*.pm>) {
	system "perl -cw $_";
}

chdir '../../..';

$p = new App::PFM::Application();
$p->bootstrap($silent = 1);
$p->screen->at(21,0);

