
# Makefile.PL for pfm

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME			=> 'pfm',
	VERSION_FROM		=> 'pfm',
	ABSTRACT		=> 'Personal File Manager for Unix/Linux',
	LICENSE			=> 'gpl',
	PREREQ_PM		=> {
		'Term::Cap'		=> 1.12,
		'Term::Screen'		=> 1.03,
		'Term::ScreenColor'	=> 1.13,
		'Term::ReadLine::Gnu'	=> 1.17,
		'LWP::Simple'		=> 5.827, # not sure, probably too high
	},
	EXE_FILES		=> ['pfm', 'pfmrcupdate'],
	MIN_PERL_VERSION	=> 5.008,
	DIR			=> ['listwhite'],
#	INSTALLSITESCRIPT
#	INST_SCRIPT
#	INST_BIN
#	MAN1PODS
#	MAN3PODS
);



