#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Application 2.02.7
#
# Name:			App::PFM::Application.pm
# Version:		2.02.7
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-21
#

##########################################################################

=pod

=head1 NAME

App::PFM::Application

=head1 DESCRIPTION

This is the PFM application class that holds all pfm elements together.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Application;

require 5.008;

use base 'App::PFM::Abstract';

use App::PFM::State;
use App::PFM::Config;
use App::PFM::Screen;
use App::PFM::Browser;
use App::PFM::CommandHandler;
use App::PFM::History;
use App::PFM::JobHandler;
use Getopt::Long;
use Cwd;

use locale;
use strict;

use constant {
	S_MAIN		=> 0,
	S_SWAP		=> 1,
	S_PREV		=> 2,
};

my ($_browser, $_screen, $_commandhandler, $_config, $_history, $_jobhandler,
	$_bootstrapped, @_states, $_latest_version,
);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
	($self->{VERSION}, $self->{LASTYEAR}) = $self->_findversion();
	$self->{LATEST_VERSION} = '';
}

=item _findversionfromfile()

Reads the current file and parses it to find the current version and
last change date. These are returned as an array.

=cut

sub _findversionfromfile {
	my $self    = shift;
	my $version = 'unknown';
	# default year, in case the year cannot be determined
	my $year    = 3 * 10 * 67;
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

=item _findversion()

Determines the current version from the ROFFVERSION variable in the main package.

=cut

sub _findversion {
	my $self    = shift;
	my ($version) = ($main::ROFFVERSION =~ /^\.ds Vw \S+ pfm.pl ([a-z0-9.]+)$/ms);
	my ($year)    = ($main::ROFFVERSION =~ /^\.ds Yr (\d+)$/ms);
	# default values, in case they cannot be determined
	$version  ||= 'unknown';
	$year     ||= 3 * 10 * 67;
	return ($version, $year);
}

=item _usage()

Print usage information: commandline options and F<.pfmrc> file.

=cut

sub _usage {
	my $self      = shift;
	$_screen->colorizable(1);
	my $directory = $_screen->colored('underline', 'directory');
	my $number    = $_screen->colored('underline', 'number');
	my $config    = new App::PFM::Config($self);
	print "Usage: pfm [ -l, --layout $number ] ",
		  "[ $directory ] [ -s, --swap $directory ]\n",
		  "       pfm { -h, --help | -v, --version }\n\n",
		  "    $directory            : specify starting directory\n",
		  "    -h, --help           : print this help and exit\n",
		  "    -l, --layout $number  : startup with specified layout\n",
		  "    -s, --swap $directory : specify swap directory\n",
		  "    -v, --version        : print version information and exit\n\n",
		  $config->give_location(), "\n";
}

=item _printversion()

Prints version information.

=cut

sub _printversion {
	my $self = shift;
	print "pfm ", $self->{VERSION}, "\r\n";
}

=item _goodbye()

Called when pfm exits.
Prints a goodbye message and restores the screen to a usable state.

=cut

sub _goodbye {
	my $self  = shift;
	my $bye   = 'Goodbye from your Personal File Manager!';
	my $state = $_states[S_MAIN];
	$_screen->stty_cooked();
	$_screen->mouse_disable();
	$_screen->alternate_off();
	system qw(tput cnorm) if $_config->{cursorveryvisible};
	if ($state->{altscreen_mode}) {
		print "\n";
	} else {
		if ($_config->{clsonexit}) {
			$_screen->clrscr();
		} else {
			$_screen->at(0,0)->putcentered($bye)->clreol()
					->at($_screen->PATHLINE, 0);
		}
	}
	$_history->write_dirs();
	$_history->write() if $_config->{autowritehistory};
	if ($state->{altscreen_mode} or !$_config->{clsonexit}) {
		$_screen->at($_screen->screenheight + $_screen->BASELINE + 1, 0)
				->clreol();
	}
	$_screen->putmessage($_latest_version) if $_latest_version;
}

##########################################################################
# constructor, getters and setters

=item browser()

=item commandhandler()

=item config()

=item history()

=item jobhandler()

=item screen()

Getters for the objects:

=over 2

=item App::PFM::Browser

=item App::PFM::CommandHandler

=item App::PFM::Config

=item App::PFM::History

=item App::PFM::JobHandler

=item App::PFM::Screen

=back

=item state()

Getter for the current App::PFM::State object. If an argument is provided,
it indicates which item from the state stack is to be returned.

=cut

sub browser {
	return $_browser;
}

sub commandhandler {
	return $_commandhandler;
}

sub config {
	return $_config;
}

sub history {
	return $_history;
}

sub jobhandler {
	return $_jobhandler;
}

sub screen {
	return $_screen;
}

sub state {
	my ($self, $index, $value) = @_;
	$index ||= S_MAIN;
	if (defined $value) {
		$_states[$index] = $value;
	}
	return $_states[$index];
}

sub latest_version {
	my ($self, $value) = @_;
	$_latest_version = $value if defined $value;
	return $_latest_version;
}

##########################################################################
# public subs

=item swap_states()

Swaps two state objects in the array @_states.

=cut

sub swap_states {
	my ($self, $first, $second) = @_;
	@_states[$first, $second] = @_states[$second, $first];
}

=item bootstrap()

Initializes the application.
Instantiates the necessary objects.

=cut

sub bootstrap {
	my $self = shift;
	my ($startingdir, $swapstartdir, $startinglayout,
		$currentdir,
		$opt_version, $opt_help, $invalid, $state);
	
	# hand over the application object to the other classes
	# for easy access.
	$_states[S_MAIN] = new App::PFM::State($self);
	$_screen		 = new App::PFM::Screen($self);
	$_screen->at($_screen->rows(), 0)->cooked();
	
	Getopt::Long::Configure(qw'bundling permute');
	GetOptions ('s|swap=s'   => \$swapstartdir,
				'l|layout=i' => \$startinglayout,
				'h|help'     => \$opt_help,
				'v|version'  => \$opt_version) or $invalid = 1;
	$self->_usage()			if $opt_help || $invalid;
	$self->_printversion()	if $opt_version;
	exit 1					if $invalid;
	exit 0					if $opt_help || $opt_version;
	
	# hand over the application object to the other classes
	# for easy access.
	$_commandhandler = new App::PFM::CommandHandler($self);
	$_history		 = new App::PFM::History($self);
	$_browser		 = new App::PFM::Browser($self);
	$_jobhandler	 = new App::PFM::JobHandler($self);
	
	$_screen->clrscr()->raw();
	$_screen->calculate_dimensions();
	$_config = new App::PFM::Config($self);
	$_config->read( $_config->READ_FIRST);
	$_config->parse($_config->SHOW_COPYRIGHT);
	$_config->apply();
	$_screen->listing->layout($startinglayout);
	$_history->read();
	$_latest_version = '';
	$_jobhandler->start('CheckUpdates');
	
	# current directory - MAIN for the time being
	$currentdir = getcwd();
	$_states[S_MAIN]->prepare($currentdir);
	# do we have a starting directory?
	$startingdir = shift @ARGV;
	if ($startingdir ne '') {
		# if so, make it MAIN; currentdir becomes PREV
		unless ($_states[S_MAIN]->currentdir($startingdir)) {
			$_screen->at(0,0)->clreol();
			$_screen->display_error("$startingdir: $! - using .");
			$_screen->important_delay();
		}
	} else {
		# if not, clone MAIN to PREV
		$_states[S_PREV] = $_states[S_MAIN]->clone($self);
	}
	# swap directory
	if (defined $swapstartdir) {
		$_states[S_SWAP] = new App::PFM::State($self);
		$_states[S_SWAP]->prepare($swapstartdir);
	}
	# done
	$_bootstrapped = 1;
}

=item run()

Runs the application. Calls bootstrap() first, if that has not
been done yet.

=cut

sub run {
	my $self = shift;
	$self->bootstrap() if !$_bootstrapped;
	$_browser->browse();
	$self->_goodbye();
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
