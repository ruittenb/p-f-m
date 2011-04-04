#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Application 2010-03-27 v2.00.3
#
# Name:			PFM::Application.pm
# Version:		2.00.3
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	The PFM application.
#

##########################################################################
# declarations

package PFM::Application;

require 5.008;

use base 'PFM::Abstract';

use PFM::Screen;
use PFM::Browser;
use PFM::CommandHandler;
use PFM::State;
use Getopt::Long;
use Cwd;

use locale;
use strict;

use constant PFM_URL => 'http://p-f-m.sourceforge.net/';

my ($_bootstrapped,
	$_browser, $_screen, $_commandhandler, $_config, $_state, $_swap_state,
	$_swap_mode);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
	($self->{VERSION}, $self->{LASTYEAR}) = $self->_findversion();
}

=item _findversion()

Reads the current file and parses it to find the current version and
last change date. These are returned as an array.

=cut

sub _findversion {
	my $self    = shift;
	my $version = 'unknown';
	my $year    = 3 * 10 * 67; # default, in case the year cannot be determined
	# the pragma 'locale' causes problems when the source is read in using UTF-8
	no locale;
	if (open (SELF, __FILE__)) {
		while (<SELF>) {
			/^#+\s+Version:\s+([\w\.]+)/ and $version = "$1";
			/^#+\s+Date:\s+(\d+)/        and $year    = "$1", last;
		}
		close SELF;
	}
	return ($version, $year);
}

=item _find_white_commands()

Finds out which commands should be used for listing and deleting whiteouts.

=cut

sub _find_white_commands {
	# TODO should this be split up? in CommandHandler?
	my $self = shift;
	my ($white_cmd, @unwo_cmd);
	$white_cmd = '';
	@unwo_cmd  = ();
	foreach (split /:/, $ENV{PATH}) {
		if (!@unwo_cmd) {
			if (-f "$_/unwhiteout") {
				@unwo_cmd = qw(unwhiteout);
			} elsif (-f "$_/unwo") {
				@unwo_cmd = qw(unwo);
			}
		}
		if (!$white_cmd) {
			if (-f "$_/listwhite") {
				$white_cmd = 'listwhite';
			} elsif (-f "$_/lsw") {
				$white_cmd = 'lsw';
			}
		}
	}
	unless (@unwo_cmd) {
		@unwo_cmd = qw(rm -W);
	}
	$_white_cmd = $white_cmd;
	@_unwo_cmd  = @unwo_cmd;
}

=item _usage()

Print usage information: commandline options and F<.pfmrc> file.

=cut

sub _usage {
	my $self      = shift;
	my $directory = $_screen->colored('underline', 'directory');
	my $number    = $_screen->colored('underline', 'number');
	my $config    = new PFM::Config();
	print "Usage: pfm [ -l, --layout $number ]",
		  "[ $directory ] [ -s, --swap $directory ]\n",
		  "       pfm { -h, --help | -v, --version }\n\n",
		  "    $directory            : specify starting directory\n",
		  "    -h, --help           : print this help and exit\n",
		  "    -l, --layout $number  : startup with specified layout\n",
		  "    -s, --swap $directory : specify swap directory\n",
		  "    -v, --version        : print version information and exit\n",
		  $config->explain(), "\n";
}

=item _printversion()

Prints version information.

=cut

sub _printversion {
	my $self = shift;
	print "pfm ", $self->{VERSION}, "\n";
}

=item _goodbye()

Called when pfm exits.
Prints a goodbye message and restores the screen to a usable state.

=cut

sub _goodbye {
	my $self = shift;
	my $bye  = 'Goodbye from your Personal File Manager!';
	$_screen->stty_cooked();
	$_screen->mouse_disable();
	$_screen->alternate_off();
	system qw(tput cnorm) if $_config->{cursorveryvisible};
	if ($_state->{altscreen_mode}) {
		print "\n";
	} else {
		if ($_config->{clsonexit}) {
			$_screen->clrscr();
		} else {
			$_screen->at(0,0)->putcentered($bye)->clreol()
					->at($_screen->PATHLINE, 0);
		}
	}
	$self->_write_cwd();
	$self->_write_history() if $_config->{autowritehistory};
	if ($_state->{altscreen_mode} or !$_config->{clsonexit}) {
		$_screen->at($_screen->screenheight + $_screen->BASELINE + 1, 0)
				->clreol();
	}
}

=item _check_for_updates()

Tries to connect to the URL of the pfm project page to see if there
is a newer version. Reports this version to the user.

=cut

sub _check_for_updates {
	use LWP::Simple;
	my $self = shift;
	my $latest_version;
	my $pfmpage = get(PFM_URL);
	($latest_version = $pfmpage) =~
		s/.*?latest version \(v?([\w.]+)\).*/$1/s;
	if ($latest_version gt $self->{VERSION}) {
		$_screen->putmessage(
			"There is a newer version ($latest_version) available at "
		.	PFM_URL . "\n"
		);
	}
}

##########################################################################
# constructor, getters and setters

=item screen()

Getter/setter for the PFM::Screen object.

=cut

sub screen {
	my ($self, $value) = @_;
	$_screen = $value if defined $value;
	return $_screen;
}

=item config()

Getter for the PFM::Config object.

=cut

sub config {
	my ($self, $value) = @_;
	return $_config;
}

=item state()

Getter for the PFM::State object.

=cut

sub state {
	my ($self, $value) = @_;
	return $_state;
}

##########################################################################
# public subs

=item bootstrap()

Initializes the application.
Instantiates the necessary objects.

=cut

sub bootstrap {
	my $self = shift;
	my ($startingdir, $opt_version, $opt_help, $invalid);

	# hand over the application object to the other classes
	# for easy access.
	$_screen         = new PFM::Screen($self);
	$_commandhandler = new PFM::CommandHandler($self);
	$_state          = new PFM::State();

	Getopt::Long::Configure(qw'bundling permute');
	GetOptions ('s|swap=s'   => \$swapstartdir,
				'l|layout=i' => \$currentlayout,
				'h|help'     => \$opt_help,
				'v|version'  => \$opt_version) or $invalid = 2;
	$self->_usage()			if $opt_help;
	$self->_printversion()	if $opt_version;
	exit 1					if $invalid;
	exit 0					if $opt_help || $opt_version;

	# TODO
#	$startingdir = shift @ARGV;
#	$SIG{WINCH}  = \&resizecatcher;
	$_screen->clrscr();
	$_screen->recalculate_dimensions();
	$_swap_mode	 = 0;
	$_swap_state	= new PFM::State();
#	@signame		= init_signames();
#	$baseindex		= 0;
	$self->_find_white_commands();
	$_config = new PFM::Config();
	$_config->read( $self, $_config->READ_FIRST);
	$_config->parse($self, $_config->SHOW_COPYRIGHT);
#	read_history();
	$_screen->draw_frame();
#	# now find starting directory
#	$oldcurrentdir = $currentdir = getcwd();
#	if ($startingdir ne '') {
#		unless (mychdir($startingdir)) {
#			$scr->at(0,0)->clreol();
#			display_error("$startingdir: $! - using .");
#			$scr->key_pressed($IMPORTANTDELAY);
#		}
#	}


	$_browser = new PFM::Browser();

	$_bootstrapped = 1;
}

=item run()

Runs the application. Calls bootstrap() if that has not been done yet.

=cut

sub run {
	my $self = shift;
	$self->bootstrap() if !$_bootstrapped;

	#TODO
	$_screen->demo();
	$_commandhandler->demo();
	# TODO

	$self->_goodbye();
	$self->_check_for_updates() if $_config->{check_for_updates};
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
