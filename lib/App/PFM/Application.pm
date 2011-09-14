#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Application 2.06.8
#
# Name:			App::PFM::Application
# Version:		2.06.8
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-21
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

use App::PFM::Browser;
use App::PFM::CommandHandler;
use App::PFM::Config;
use App::PFM::History;
use App::PFM::JobHandler;
#use App::PFM::OS;
use App::PFM::Screen;
use App::PFM::State;
use Getopt::Long;
use Cwd;

use locale;
use strict;

use constant BOOKMARKKEYS => [qw(
	a b c d e f g h i j k l m n o p q r s t u v w x y z
	A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
)];

our ($_os, $_config, $_browser, $_screen, $_commandhandler, $_history,
	$_jobhandler);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self) = @_;
	($self->{VERSION}, $self->{LASTYEAR}) = $self->_findversion();
	$self->{NEWER_VERSION} = '';
	$self->{_bootstrapped} = 0;
	$self->{_states}       = {};
#	$_os                   = new App::PFM::OS();
}

=item _findversionfromfile()

Reads the current file and parses it to find the current version
and last change date.

Returns: (string $version, string $year)

=cut

sub _findversionfromfile {
#	my ($self)  = @_;
	my $version = 'unknown';
	# default year, in case the year cannot be determined
	my $year    = 3 * 10 * 67;
	# the pragma 'locale' used to cause problems when the source
	# is read in using UTF-8
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

Determines the current version and year using the ROFFVERSION variable in
the main package.

Returns: (string $version, string $year)

=cut

sub _findversion {
#	my ($self)   = @_;
	my ($version)=($main::ROFFVERSION =~ /^\.ds Vw \S+ pfm.pl ([a-z0-9.]+)$/ms);
	my ($year)   =($main::ROFFVERSION =~ /^\.ds Yr (\d+)$/ms);
	# default values, in case they cannot be determined
	$version  ||= $main::VERSION || 'unknown';
	$year     ||= 3 * 10 * 67;
	return ($version, $year);
}

=item _usage()

Prints usage information for the user: commandline options and
location of the F<.pfmrc> file.

=cut

sub _usage {
	my ($self) = @_;
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
		  "Configuration options will be read from ", $config->give_location(), "\n",
		  "(or override this with \$PFMRC)\n";
}

=item _printversion()

Prints version information.

=cut

sub _printversion {
	my ($self) = @_;
	print "pfm ", $self->{VERSION}, "\r\n";
}

=item _goodbye()

Called when pfm exits.
Prints a goodbye message and restores the screen to a usable state.

=cut

sub _goodbye {
	my ($self) = @_;
	my $bye    = 'Goodbye from your Personal File Manager!';
	my $state  = $self->{_states}{S_MAIN};
	$_screen->cooked_echo()
		->mouse_disable()
		->alternate_off();
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
	$_history->write()          if $_config->{autowritehistory};
	$_config->write_bookmarks() if $_config->{autowritebookmarks};
	if ($state->{altscreen_mode} or !$_config->{clsonexit}) {
		$_screen->at($_screen->screenheight + $_screen->BASELINE + 1, 0)
				->clreol();
	}
	if ($self->{NEWER_VERSION} and $self->{PFM_URL}) {
		$_screen->putmessage(
			"There is a newer version ($self->{NEWER_VERSION}) ",
			"available at $self->{PFM_URL}\n");
	}
}

##########################################################################
# constructor, getters and setters

=item browser()

Getter for the App::PFM::Browser object.

=item commandhandler()

Getter for the App::PFM::CommandHandler object.

=item config()

Getter for the App::PFM::Config object.

=item history()

Getter for the App::PFM::History object.

=item jobhandler()

Getter for the App::PFM::JobHandler object.

=item os()

Getter for the App::PFM::OS object.

=item screen()

Getter for the App::PFM::Screen object.

=item state( [ string $statename [, App::PFM::State $state ] ] )

Getter/setter for the current App::PFM::State object. If a I<statename>
is provided, it indicates which item from the state stack is to be returned.
I<statename> defaults to B<S_MAIN> (the main state).

The predefined constants B<S_MAIN>, B<S_SWAP> and B<S_PREV> can be used to
refer to the main, swap and previous states.

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

sub os {
	return $_os;
}

sub screen {
	return $_screen;
}

sub state {
	my ($self, $index, $value) = @_;
	$index ||= 'S_MAIN';
	if (defined $value) {
		$self->{_states}{$index} = $value;
	}
	return $self->{_states}{$index};
}

=item newer_version( [ string $version ] )

Getter/setter for the variable that indicates the latest version on the
pfm website.

=cut

sub newer_version {
	my ($self, $value) = @_;
	$self->{NEWER_VERSION} = $value if defined $value;
	return $self->{NEWER_VERSION};
}

##########################################################################
# public subs

=item openwindow(App::PFM::File $file)

Opens a new terminal window running pfm.

=cut

sub openwindow {
	my ($self, $file) = @_;
	if ($_config->{windowtype} eq 'pfm') {
		# windowtype = pfm
		if (ref $self->{_states}{S_SWAP}) {
			system($_config->{windowcmd} . " 'pfm \Q$file->{name}\E -s " .
				quotemeta($self->{_states}{S_SWAP}->{path}) . "' &");
		} else {
			system($_config->{windowcmd} . " 'pfm \Q$file->{name}\E' &");
		}
	} else {
		# windowtype = standalone
		system($_config->{windowcmd} . " \Q$file->{name}\E &");
	}
}

=item swap_states(string $statename1, string $statename2)

Swaps two state objects in the hash %_states.

=cut

sub swap_states {
	my ($self, $first, $second) = @_;
	@{$self->{_states}}{$first, $second} = @{$self->{_states}}{$second, $first};
}

=item checkupdates()

Starts the job for checking if there are new versions of the application
available for download.

=cut

sub checkupdates {
	my ($self) = @_;
	my %on = (
		after_receive_data	=> sub {
			my ($job, $input) = @_;
			if ($input gt $self->{VERSION}) {
				$self->{NEWER_VERSION}	= $input;
				$self->{PFM_URL}		= $job->PFM_URL;
			}
		},
	);
	$_jobhandler->start('CheckUpdates', %on);
}

=item bootstrap( [ bool $silent ] )

Initializes the application and instantiates the necessary objects.

The I<silent> argument suppresses output and may be used for testing
if the application bootstraps correctly.

=cut

sub bootstrap {
	my ($self, $silent) = @_;
	my ($startingdir, $swapstartdir, $startinglayout,
		$currentdir, $opt_version, $opt_help,
		%bookmarks, $invalid, $state);
	
	# hand over the application object to the other classes
	# for easy access.
	$self->{_states}{S_MAIN} = new App::PFM::State($self);
	$_screen				 = new App::PFM::Screen($self);
	$_screen->at($_screen->rows(), 0)->cooked_echo();
	
	Getopt::Long::Configure(qw'bundling permute');
	GetOptions ('s|swap=s'   => \$swapstartdir,
				'l|layout=i' => \$startinglayout,
				'h|help'     => \$opt_help,
				'v|version'  => \$opt_version) or $invalid = 1;
	$self->_usage()			if $opt_help || $invalid;
	$self->_printversion()	if $opt_version;
	die "Invalid option\n"	if $invalid;
	die "\n"				if $opt_help || $opt_version;
	
	# hand over the application object to the other classes
	# for easy access.
	$_commandhandler = new App::PFM::CommandHandler($self);
	$_history		 = new App::PFM::History($self);
	$_browser		 = new App::PFM::Browser($self);
	$_jobhandler	 = new App::PFM::JobHandler($self);
	
	$_screen->clrscr()->raw_noecho();
	$_screen->calculate_dimensions();
	$_config = new App::PFM::Config($self);
	$_config->read( $silent ? $_config->READ_AGAIN   :$_config->READ_FIRST);
	$_config->parse($silent ? $_config->NO_COPYRIGHT :$_config->SHOW_COPYRIGHT);
	$_config->apply();
	%bookmarks = $_config->read_bookmarks();
	@{$self->{_states}}{@{BOOKMARKKEYS()}} = ();
	@{$self->{_states}}{keys %bookmarks} = values %bookmarks;
	$_screen->listing->layout($startinglayout);
	$_history->read();
	$self->checkupdates();
	
	# current directory - MAIN for the time being
	$currentdir = getcwd();
	$self->{_states}{S_MAIN}->prepare($currentdir);
	# do we have a starting directory?
	$startingdir = shift @ARGV;
	if ($startingdir ne '') {
		# if so, make it MAIN; currentdir becomes PREV
		unless ($self->{_states}{S_MAIN}->directory->path($startingdir)) {
			$_screen->at(0,0)->clreol();
			$_screen->display_error("$startingdir: $! - using .");
			$_screen->important_delay();
		}
	} else {
		# if not, clone MAIN to PREV
		$self->{_states}{S_PREV} = $self->{_states}{S_MAIN}->clone($self);
	}
	# swap directory
	if (defined $swapstartdir) {
		$self->{_states}{S_SWAP} = new App::PFM::State($self);
		$self->{_states}{S_SWAP}->prepare($swapstartdir);
	}
	# flag done
	$self->{_bootstrapped} = 1;
}

=item run()

Runs the application. Calls bootstrap() first, if that has not
been done yet.

=cut

sub run {
	my ($self) = @_;
	$self->bootstrap() if !$self->{_bootstrapped};
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
