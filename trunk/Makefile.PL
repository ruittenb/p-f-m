
# Makefile.PL for pfm

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME			=> 'pfm',
	VERSION_FROM		=> 'pfm',
	ABSTRACT		=> 'Personal File Manager for Unix/Linux',
	LICENSE			=> 'GPL',
	MIN_PERL_VERSION	=> 5.008,
	PREREQ_PM		=> {
		'Term::Cap'		=> 0,     # as reported by Term::Screen
		'Term::Screen'		=> 1.02,
		'Term::ScreenColor'	=> 1.13,
		'Term::ReadLine::Gnu'	=> 1.17,
		'LWP'			=> 5.827, # not sure, probably too high
	},
	EXE_FILES		=> ['pfm', 'pfmrcupdate'],
	DIR			=> ['listwhite'],
	MAN1PODS		=> {
		'pfm'			=> 'blib/man1/pfm.1',
		'listwhite/listwhite.c'	=> 'blib/man1/listwhite.1',
	},
#	INSTALLSITESCRIPT
#	INST_SCRIPT
#	INST_BIN
#	MAN3PODS
);



