
# Build.PL for pfm

use Module::Build;

Module::Build->new(
	module_name		=> 'pfm',
	dist_version_from	=> 'pfm',
	license			=> 'gpl',
	requires		=> {
		'Term::Cap'		=> 1.12,
		'Term::Screen'		=> 1.03,
		'Term::ScreenColor'	=> 1.13,
		'Term::ReadLine::Gnu'	=> 1.17,
		'LWP::Simple'		=> 5.827, # not sure, probably too high
	},
	create_makefile_pl	=> 'passthrough',
	script_files		=> [ 'pfm', 'pfmrcupdate' ],
)->create_build_script();

#WriteMakefile(
#	NAME		=> 'pfm',
#	ABSTRACT	=> 'Personal File Manager for Unix/Linux',
#	MIN_PERL_VERSION => 5.008,
#	DIR		=> ['listwhite'],
#);


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
