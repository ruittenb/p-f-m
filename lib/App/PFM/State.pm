#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::State 0.26
#
# Name:			App::PFM::State
# Version:		0.26
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2014-05-05
#

##########################################################################

=pod

=head1 NAME

App::PFM::State

=head1 DESCRIPTION

PFM class used for storing the current state of the application.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::State;

use base 'App::PFM::Abstract';

use App::PFM::Directory;
use App::PFM::Util qw(ifnotdefined setifnotdefined);

use strict;
use locale;

use constant SORTMODES => [
	 n =>'Name',		N =>' reverse',
	'm'=>' ignorecase',	M =>' rev+igncase',
	 e =>'Extension',	E =>' reverse',
	 f =>' ignorecase',	F =>' rev+igncase',
	 d =>'Date/mtime',	D =>' reverse',
	 a =>'date/Atime',	A =>' reverse',
	's'=>'Size',		S =>' reverse',
	'z'=>'siZe total',	Z =>' reverse',
	 t =>'Type',		T =>' reverse',
	 p =>'Mode',		P =>' reverse',
	 u =>'User',		U =>' reverse',
	 w =>' Uid',		W =>' reverse',
	 g =>'Group',		G =>' reverse',
	 h =>' Gid',		H =>' reverse',
	 l =>'Link count',	L =>' reverse',
	 v =>'Version',		V =>' reverse',
	 i =>'Inode',		I =>' reverse',
	'*'=>'mark',
];

use constant NUMFORMATS => {
	'hex' => '\\%#04lx',
	'oct' => '\\%03lo',
	'dec' => '&#%d;',
};

##########################################################################
# private subs

=item I<_init(App::PFM::Application $pfm, App::PFM::Screen $screen,>
I<App::PFM::Config $config, App::PFM::OS $os, App::PFM::JobHandler>
I<$jobhandler, string $path)>

Initializes new instances. Called from the constructor.
Instantiates a App::PFM::Directory object.

=cut

sub _init {
	my ($self, $pfm, $screen, $config, $os, $jobhandler, $path) = @_;
	$self->{_screen}           = $screen;
	$self->{_config}           = $config;
	$self->{_os}               = $os;
	$self->{_directory}		   = App::PFM::Directory->new(
		$pfm, $screen, $config, $os, $jobhandler, $path);
	# We might not have useful values for these yet since the config file
	# might not have been read yet.
	$self->{_position}		   = undef;
	$self->{_baseindex}		   = undef;
	$self->{trspace}		   = undef;
	$self->{multiple_mode}	   = 0;
	$self->{dot_mode}		   = undef;
	$self->{white_mode}		   = undef;
	$self->{file_filter_mode}  = undef;
	$self->{_radix_mode}	   = undef;
	$self->{_sort_mode}		   = undef;
	# path_mode    sits in App::PFM::Directory
	# color_mode   sits in App::PFM::Screen
	# ident_mode   sits in App::PFM::Screen::Diskinfo
	# mouse_mode   sits in App::PFM::Browser
	# swap_mode    sits in App::PFM::Browser
	# clobber_mode sits in App::PFM::CommandHandler
	return;
}

=item I<_clone( [ array @args ] )>

Performs one phase of the cloning process by cloning an existing
App::PFM::Directory instance.

Arguments are passed to the clone() function of the Directory object.

=cut

sub _clone {
	my ($self, $original, @args) = @_;
	$self->{_directory} = $original->{_directory}->clone(@args);
	return;
}

=item I<DESTROY()>

Signals the Directory object to unregister itself with the Screen::Listing
object.

=cut

sub DESTROY {
	my ($self) = @_;
	if (defined $self->{_directory}) {
		$self->{_directory}->destroy();
	}
	return;
}

##########################################################################
# constructor, getters and setters

=item I<directory( [ App::PFM::Directory $directory ] )>

Getter/setter for the App::PFM::Directory object.

=cut

sub directory {
	my ($self, $value) = @_;
	$self->{_directory} = $value if defined $value;
	return $self->{_directory};
}

=item I<sort_mode( [ string $sort_mode ] )>

Getter/setter for the sort mode. The sort mode must be a string consisting
of valid sortmode characters as defined by the SORTMODES constant above.

=cut

sub sort_mode {
	my ($self, $value) = @_;
	if (defined $value) {
		my $valid = 1;
		my %sortmodes = @{SORTMODES()};
		foreach my $i (0 .. length($value) - 1) {
			if (!exists $sortmodes{substr($value, $i, 1)}) {
				$valid = 0;
				last;
			}
		}
		if ($valid) {
			$self->{_sort_mode} = $value;
		}
	}
	return $self->{_sort_mode};
}

#=item I<file_filter_mode( [ string $file_filter_mode ] )>
#
#Getter/setter for the filter mode for a custom list of files
#(F<.pfmrc> option: file_filter).
#
#=cut
#
#sub file_filter_mode {
#	my ($self, $value) = @_;
#	$self->{_file_filter_mode} = $value if defined $value;
#	return $self->{_file_filter_mode};
#}

=item I<radix_mode( [ string $radix_mode ] )>

Getter/setter for the radix mode. The radix mode must be one of the values
defined in NUMFORMATS.

=cut

sub radix_mode {
	my ($self, $value) = @_;
	if (defined $value and exists ${NUMFORMATS()}{$value}) {
		$self->{_radix_mode} = $value;
	}
	return $self->{_radix_mode};
}

##########################################################################
# public subs

=item I<prepare(string $path [, string $sort_mode ] )>

Prepares the contents of this state object. Called in case this state
is not to be displayed on-screen right away.

The I<path> argument is passed to the prepare() method of the Directory
object. I<sort_mode> specifies the initial sort mode.

=cut

sub prepare {
	my ($self, $path, $sort_mode) = @_;
	$self->sort_mode($sort_mode || $self->{_config}{sort_mode});
	$self->{_position}  = '.';
	$self->{_baseindex} = 0;
	$self->{_directory}->prepare($path);
	return;
}

=item I<on_after_parse_config(App::PFM::Event $event)>

Applies the config settings when the config file has been read and parsed.
Is also called directly from App::PFM::Application::_bootstrap_states()
when a swap state is instantiated.

=cut

sub on_after_parse_config {
	my ($self, $event) = @_;
	# Store config. Since this function is also called directly by
	# App::PFM::Application, the event's origin should be checked.
	if (ref $event->{origin} eq 'App::PFM::Config') {
		setifnotdefined \$self->{_config},    $event->{origin};
#		my $pfmrc = $event->{data};
	}

	# Don't change settings back to the defaults if they may have
	# been modified by key commands.
	setifnotdefined \$self->{dot_mode},   $self->{_config}{dot_mode};
	setifnotdefined \$self->{trspace},    $self->{_config}{trspace};
	setifnotdefined \$self->{white_mode}, $self->{_config}{white_mode};
	unless (defined $self->{_sort_mode}) {
		$self->sort_mode($self->{_config}{sort_mode});
		setifnotdefined \$self->{_sort_mode}, 'n';
	}
	unless (defined $self->{_radix_mode}) {
		$self->radix_mode($self->{_config}{radix_mode});
		setifnotdefined \$self->{_radix_mode}, 'oct';
	}
	unless (defined $self->directory->path_mode) {
		$self->directory->path_mode($self->{_config}{path_mode});
	}
	return;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Application(3pm), App::PFM::Directory(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
