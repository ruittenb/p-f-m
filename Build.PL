
# Build.PL for pfm

use Module::Build;

Module::Build->new(
	module_name		=> 'pfm',
	dist_version_from	=> 'pfm',
	license			=> 'GPL',
	requires		=> {
		'File::stat'		=> 0,
		'File::Stat::Bits'	=> 0.19,   # maybe less
		'File::Temp'		=> 0.2304, # at least 0.22
		'Term::Cap'		=> 0,
		'Term::Screen'		=> 1.06,
		'Term::ScreenColor'	=> 1.20,
		'Term::ReadLine::Gnu'	=> 1.35,   # at least 1.16
		'HTML::Parser'		=> 3.72,   # at least 3.59
		'LWP'			=> 6.26,   # at least 5.827
		'Module::Load'          => 0.32,   # at least 0.16
	},
	create_makefile_pl	=> 'passthrough',
	script_files		=> [ 'pfm' ],
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
