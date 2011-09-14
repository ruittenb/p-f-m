#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Application 2.11.0
#
# Name:			App::PFM::Application
# Version:		2.11.0
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-12-04
#

##########################################################################

=pod

=head1 NAME

App::PFM::Application

=head1 DESCRIPTION

This is the PFM application class that holds the elements together that
make up the application: Screen, Browser, CommandHandler, JobHandler,
History, Config, OS and the State array.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Application;

require 5.008;
# among other things, for the syntax: open my $fh, '-|', 'command';

use base 'App::PFM::Abstract';

use App::PFM::Browser::Files;
use App::PFM::CommandHandler;
use App::PFM::Config;
use App::PFM::History;
use App::PFM::JobHandler;
use App::PFM::OS;
use App::PFM::Screen;
use App::PFM::State;
use Getopt::Long;
use Cwd;

use locale;
use strict;

our $VERSION  = '2.11.0';
our $LASTYEAR = 2010;

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self) = @_;
	$self->{VERSION}       = $VERSION;
	$self->{LASTYEAR}      = $LASTYEAR;
	$self->{NEWER_VERSION} = '';
	$self->{_bootstrapped} = 0;
	$self->{_options}      = {};
	$self->{_states}       = {};
	return;
}

=item _usage(bool $extended)

Prints usage information for the user: commandline options and
if extended information is requested, the location of the F<.pfmrc> file.

=cut

sub _usage {
	my ($self, $extended) = @_;
	my $screen = $self->{_screen};
#	$screen->colorizable(1);
	my $directory  = $screen->colored('underline', 'directory');
	my $number     = $screen->colored('underline', 'number');
	my $sortmode   = $screen->colored('underline', 'sortmode');
	my $configname = App::PFM::Config::location();
	print "Usage: pfm [ $directory ] [ -s, --swap $directory ]\n",
		  "           [ -l, --layout $number ] [ -o, --sort $sortmode ]\n",
		  "       pfm { --help | --usage | --version }\n\n";
	return unless $extended;
	print "    $directory            : specify starting directory\n",
		  "        --help           : print extended help and exit\n",
		  "    -l, --layout $number  : startup with specified layout\n",
		  "    -o, --sort $sortmode  : startup with specified sortmode\n",
		  "    -s, --swap $directory : specify swap directory\n",
		  "        --usage          : print concise help and exit\n",
		  "        --version        : print version information and exit\n\n",
		  "Configuration options will be read from $configname\n",
		  "(or override this with \$PFMRC)\n";
	return;
}

=item _printversion()

Prints version information.

=cut

sub _printversion {
	my ($self) = @_;
	print "pfm ", $self->{VERSION}, "\r\n";
	return;
}

=item _copyright(float $delay)

Prints a short copyright message. Called at startup.

=cut

sub _copyright {
	my ($self, $delay) = @_;
	# lookalike to DOS version :)
	# note that configured colors are not yet known
	my $lastyear = $self->{LASTYEAR};
	my $vers     = $self->{VERSION};
	$self->{_screen}->clrscr()
		->at(0,0)->clreol()->cyan()
				 ->puts("PFM $vers for Unix and Unix-like operating systems.")
		->at(1,0)->puts("Copyright (c) 1999-$lastyear Rene Uittenbogaard")
		->at(2,0)->puts("This software comes with no warranty: " .
						"see the file COPYING for details.")
		->reset()->normal();
	return $self->{_screen}->key_pressed($delay || 0);
}

=item _bootstrap_commandline()

Phase 1 of the bootstrap process: parse commandline arguments.

=cut

sub _bootstrap_commandline {
	my ($self) = @_;
	my ($screen, $invalid, $opt_help, $opt_usage, $opt_version,
		$startingswapdir, $startingsort, $startinglayout);
	# hand over the application object to the other classes
	# for easy access.
	$self->{_screen} = App::PFM::Screen->new($self);
	$screen          = $self->{_screen};
	$screen->at($screen->rows(), 0)->cooked_echo();
	
	Getopt::Long::Configure(qw'bundling permute');
	GetOptions ('s|swap=s'   => \$startingswapdir,
				'o|sort=s'   => \$startingsort,
				'l|layout=i' => \$startinglayout,
				'help'       => \$opt_help,
				'usage'      => \$opt_usage,
				'version'    => \$opt_version) or $invalid = 1;
	$self->_usage($opt_help) if $opt_help || $opt_usage || $invalid;
	$self->_printversion()   if $opt_version;
	die                      if $invalid; # Died at ...
	exit 0                   if $opt_help || $opt_usage || $opt_version;

	$self->{_options}{'directory'} = shift @ARGV;
	$self->{_options}{'swap'}      = $startingswapdir;
	$self->{_options}{'sort'}      = $startingsort;
	$self->{_options}{'layout'}    = $startinglayout;
	$self->{_options}{'help'}      = $opt_help;
	$self->{_options}{'version'}   = $opt_version;
	return;
}

=item _bootstrap_members( [ bool $silent ] )

Phase 2 of the bootstrap process: instantiate member objects
and parse config file.

The I<silent> argument suppresses output and may be used for testing
if the application bootstraps correctly.

=cut

sub _bootstrap_members {
	my ($self, $silent) = @_;
	my ($screen, $config, $state, %bookmarks);

	# hand over the application object to the other classes
	# for easy access.
	$screen					 = $self->{_screen};
	$config					 =
	$self->{_config}		 = App::PFM::Config->new(
								$self,
								$screen,
								$self->{VERSION});
	$self->{_history}		 = App::PFM::History->new(
								$self,
								@{$self}{qw(_screen _config)});
	$self->{_os}			 = App::PFM::OS->new(
								$config);
	$self->{_jobhandler}	 = App::PFM::JobHandler->new();
	$self->{_states}{S_MAIN} = $state
							 = App::PFM::State->new(
								$self,
								@{$self}{qw(_screen _config _os _jobhandler)});
	$self->{_commandhandler} = App::PFM::CommandHandler->new(
								$self,
								@{$self}{qw(_screen _config _os _history)});
	$self->{_browser}		 = App::PFM::Browser::Files->new(
								@{$self}{qw(_screen _config)},
								$state);
	
	$self->_bootstrap_event_hub();

	# init screen
	$screen->clrscr()->raw_noecho();
	$screen->calculate_dimensions();
	
	# event handler for copyright message
	my $on_after_parse_usecolor = sub {
		my $event = shift;
		$screen->on_after_parse_usecolor($event);
		$self->_copyright($config->pfmrc->{copyrightdelay});
	};

	# read and parse config file
	unless ($silent) {
		$config->register_listener(
			'after_parse_usecolor', $on_after_parse_usecolor);
	}
	$config->read($silent ? $config->READ_AGAIN : $config->READ_FIRST);
	$config->parse();
	$config->unregister_listener(
			'after_parse_usecolor', $on_after_parse_usecolor);
	
	# initialize bookmark states
	%bookmarks = $config->read_bookmarks();
	@{$self->{_states}}{@{$config->BOOKMARKKEYS}} = ();
	@{$self->{_states}}{keys %bookmarks} = values %bookmarks;
	
	$screen->listing->layout($self->{_options}{'layout'});
	$self->{_history}->read();
	$self->checkupdates();
	return;
}

=item _bootstrap_states()

Phase 3 of the bootstrap process: initialize the B<S_*> state objects.

=cut

sub _bootstrap_states {
	my ($self) = @_;
	my $startingsort = $self->{_options}{'sort'};
	# current directory - MAIN for the time being
	my $currentdir = getcwd();
	$self->{_states}{S_MAIN}->prepare($currentdir, $startingsort);
	# do we have a starting directory?
	my $startingdir = $self->{_options}{directory} || '';
	if ($startingdir ne '') {
		# if so, make it MAIN; currentdir becomes PREV
		unless ($self->{_states}{S_MAIN}->directory->path($startingdir)) {
			$self->{_screen}->at(0,0)->clreol()
				->display_error("$startingdir: $! - using .");
			$self->{_screen}->important_delay();
		}
	} else {
		# if not, clone MAIN to PREV
		$self->{_states}{S_PREV} = $self->{_states}{S_MAIN}->clone($self);
	}
	# swap directory
	my $startingswapdir = $self->{_options}{swap};
	if (defined $startingswapdir) {
		$self->{_states}{S_SWAP} = App::PFM::State->new($self,
			$self->{_screen},
			$self->{_config},
			$self->{_os},
			$self->{_jobhandler},
			$startingswapdir);
		$self->{_states}{S_SWAP}->prepare(undef, $startingsort);
	}
	return;
}

=item _bootstrap_event_hub()

Phase 4 of the bootstrap process: register event listeners.

=cut

sub _bootstrap_event_hub {
	my ($self) = @_;

	# config file has been parsed
	my $on_after_parse_config = sub {
		my ($event) = @_;
		$self->{_screen}        ->on_after_parse_config($event);
		$self->{_history}       ->on_after_parse_config($event);
		$self->{_commandhandler}->on_after_parse_config($event);
		$self->{_browser}       ->mouse_mode(  $event->{origin}{mouse_mode});
		$self->{_states}{S_MAIN}->on_after_parse_config($event);
	};
	$self->{_config}->register_listener(
		'after_parse_config', $on_after_parse_config);

	# browser is idle: poll jobs
	my $on_browser_idle = sub {
		$self->{_jobhandler}->pollall();
	};
	$self->{_browser}->register_listener('browser_idle', $on_browser_idle);

	# browser passes control to the commandhandler
	my $on_after_receive_non_motion_input = sub {
		my ($event) = @_;
		$self->{_commandhandler}->handle($event);
	};
	$self->{_browser}->register_listener(
		'after_receive_non_motion_input', $on_after_receive_non_motion_input);
	return;
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
	my ($self) = @_;
	return $self->{_browser};
}

sub commandhandler {
	my ($self) = @_;
	return $self->{_commandhandler};
}

sub config {
	my ($self) = @_;
	return $self->{_config};
}

sub history {
	my ($self) = @_;
	return $self->{_history};
}

sub jobhandler {
	my ($self) = @_;
	return $self->{_jobhandler};
}

sub os {
	my ($self) = @_;
	return $self->{_os};
}

sub screen {
	my ($self) = @_;
	return $self->{_screen};
}

sub state {
	my ($self, $index, $value) = @_;
	$index ||= 'S_MAIN';
	if (defined $value) {
		if (defined $self->{_states}{$index}) {
		}
		$self->{_states}{$index} = $value;
	}
	return $self->{_states}{$index};
}

=item states()

Getter for the hash of states.

=cut

sub states {
	my ($self) = @_;
	return $self->{_states};
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

=item bootstrapped()

Getter/setter for the flag indicating that the application has been
bootstrapped.  If the flag is set this way, the appropriate action
(bootstrap or shutdown) is invoked.

=cut

sub bootstrapped {
	my ($self, $value) = @_;
	if (defined $value) {
		if ($value) {
			$self->bootstrap();
		} else {
			$self->shutdown();
		}
	}
	return $self->{_bootstrapped};
}

##########################################################################
# public subs

=item swap_states(string $statename1, string $statename2)

Swaps two state objects in the hash %_states.

=cut

sub swap_states {
	my ($self, $first, $second) = @_;
	@{$self->{_states}}{$first, $second} = @{$self->{_states}}{$second, $first};
	return;
}

=item checkupdates()

Starts the job for checking if there are new versions of the application
available for download.

=cut

sub checkupdates {
	my ($self) = @_;
	my $on_after_job_receive_data = sub {
		my ($event) = @_;
		my $job     = $event->{origin};
		my $jobdata = $event->{data};
		if (ref $jobdata eq 'ARRAY') {
			if ($jobdata->[0] gt $self->{VERSION}) {
				$self->{NEWER_VERSION}	= $jobdata->[0];
				$self->{PFM_URL}		= $job->PFM_URL;
			}
		}
	};
	$self->{_jobhandler}->start('CheckUpdates', {
		after_job_receive_data => $on_after_job_receive_data,
	});
	return;
}

=item bootstrap( [ bool $silent ] )

Initializes the application and instantiates the necessary member objects.

The I<silent> argument suppresses output and may be used for testing
if the application bootstraps correctly.

=cut

sub bootstrap {
	my ($self, $silent) = @_;
	$self->_bootstrap_commandline();
	$self->_bootstrap_members($silent);
	$self->_bootstrap_states();
	$self->{_bootstrapped} = 1;
	return;
}

=item run(bool $autoshutdown)

Runs the application. Calls bootstrap() first, if that has not
been done yet.

=cut

sub run {
	my ($self, $autoshutdown) = @_;
	$self->bootstrap() unless $self->{_bootstrapped};
	$self->{_browser}->browse();
	if ($autoshutdown) {
		$self->shutdown();
	}
	return;
}

=item shutdown( [ bool $silent ] )

Called when pfm exits.
Prints a goodbye message and restores the screen to a usable state.
Writes bookmarks and history if so configured. Destroys member objects.

=cut

sub shutdown {
	my ($self, $silent) = @_;
	my $state   = $self->{_states}{S_MAIN};
	return unless $self->{_bootstrapped};
	
	$self->{_screen}->on_shutdown($state->{altscreen_mode}, $silent);
	$self->{_history}->on_shutdown();
	$self->{_config}->on_shutdown($silent);
	$self->{_jobhandler}->stopall();
	
	if ($self->{NEWER_VERSION} and $self->{PFM_URL}) {
		$self->{_screen}->putmessage(
			"There is a newer version ($self->{NEWER_VERSION}) ",
			"available at $self->{PFM_URL}\n");
	}
	$self->{_bootstrapped}   = 0;
	$self->{_browser}        = undef;
	$self->{_commandhandler} = undef;
	$self->{_config}         = undef;
	$self->{_history}        = undef;
	$self->{_jobhandler}     = undef;
	$self->{_os}             = undef;
	$self->{_screen}         = undef;
	$self->{_states}         = {};
	return;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
