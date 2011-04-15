
# Build.PL for pfm

use Module::Build;

Module::Build->new(
	module_name		=> 'pfm',
	dist_version_from	=> 'pfm',
	license			=> 'GPL',
	requires		=> {
		'Term::Cap'		=> 0,
		'Term::Screen'		=> 1.03,  # for Solaris; others 1.02
		'Term::ScreenColor'	=> 1.13,  # no less than 1.13!
		'Term::ReadLine::Gnu'	=> 1.16,  # maybe as little as 1.09
		'HTML::Parser'		=> 3.59,  # LWP needs it. maybe less, but 3.36 is too low
		'LWP'			=> 5.827, # maybe less
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
