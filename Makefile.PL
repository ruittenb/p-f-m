#!/usr/bin/env perl

# Makefile.PL for pfm

use ExtUtils::MakeMaker;

unless ($ENV{MAKEFILE_PL_CALLED_FROM_INSTALL_SH}) {
print <<_install_help_;

---------------------------------------------------------------
This Makefile will build, test and install pfm, and it will
rely on MakeMaker to install some of its dependencies.

Since this has proven to be unreliable at times, you are
advised to use the install script instead: 'sh install.sh'.

install.sh will install dependencies and re-run this Makefile.
---------------------------------------------------------------

_install_help_
}

WriteMakefile(
	NAME			=> 'pfm',
	VERSION_FROM		=> 'pfm',
	ABSTRACT		=> 'Personal File Manager for Unix/Linux',
	LICENSE			=> 'gpl',
	MIN_PERL_VERSION	=> 5.008,
	PREREQ_PM		=> {
		'File::stat'		=> 0,
		'File::Stat::Bits'	=> 0.19,  # maybe less
		'File::Temp'		=> 0.22,
		'Term::Cap'		=> 0,
		'Term::Screen'		=> 1.03,  # for Solaris; others 1.02
		'Term::ScreenColor'	=> 1.20,  # for HP-UX;   others 1.13
		'Term::ReadLine::Gnu'	=> 1.16,  # maybe as little as 1.09
		'HTML::Parser'		=> 3.59,  # LWP needs it. maybe less, but 3.36 is too low
		'LWP'			=> 5.827, # maybe less
	},
	EXE_FILES		=> ['pfm'],
#	DIR			=> ['listwhite'],
	MAN1PODS		=> {
		'pfm'			=> 'blib/man1/pfm.1',
#		'listwhite/listwhite.c'	=> 'blib/man1/listwhite.1',
	},
#	INSTALLSITESCRIPT
#	INST_SCRIPT
#	INST_BIN
);



