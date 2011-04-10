
# Makefile.PL for Term::ScreenColor module

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME		=> 'pfm',
	VERSION_FROM	=> 'pfm',
	ABSTRACT	=> 'Personal File Manager for Unix/Linux',
	PREREQ_PM	=> {
		'Term::Cap'		=> 1.12,
		'Term::Screen'		=> 1.03,
		'Term::ScreenColor'	=> 1.13,
		'Term::ReadLine::Gnu'	=> 1.19,
		'LWP::Simple'		=> 5.834, # not sure, probably too high
	},
	EXE_FILES	=> 'pfm',
	MIN_PERL_VERSION => 5.8,
	DIR		=> ['listwhite'],
);


#MANIFEST
#lib/App/PFM/*.pm
#lib/App/PFM/Job/*.pm
#lib/App/PFM/Screen/*.pm
#
#t/01-perl-cw.t
#t/02-version.t
#Changes
#README
#INSTALL
#MANIFEST.SKIP
#bin/pfm
#
#--------------------------------------------------------------------------------
#
#--------------------------------------------------------------------------------
#
#Makefile.PL
#
#INSTALLSITESCRIPT
#INST_SCRIPT
#INST_BIN
#LICENSE
#MAN1PODS
#MAN3PODS
#
