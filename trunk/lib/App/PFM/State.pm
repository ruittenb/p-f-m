#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::State 0.19
#
# Name:			App::PFM::State
# Version:		0.19
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-12
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
	 u =>'User',		U =>' reverse',
	 g =>'Group',		G =>' reverse',
	 l =>'Link count',	L =>' reverse',
	 v =>'Version',		V =>' reverse',
	 i =>'Inode',		I =>' reverse',
	'*'=>'mark',
];

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm, App::PFM::Screen $screen,
App::PFM::Config $config, App::PFM::OS $os, App::PFM::JobHandler $jobhandler,
string $path)

Initializes new instances. Called from the constructor.
Instantiates a App::PFM::Directory object.

=cut

sub _init {
	my ($self, $pfm, $screen, $config, $os, $jobhandler, $path) = @_;
	$self->{_screen}        = $screen;
	$self->{_config}        = $config;
	$self->{_os}            = $os;
	$self->{_directory}		= new App::PFM::Directory(
		$pfm, $screen, $config, $os, $jobhandler, $path);
	# We might not have useful values for these yet since the config file
	# might not have been read yet.
	$self->{_position}		= undef;
	$self->{_baseindex}		= undef;
	$self->{multiple_mode}	= 0;
	$self->{dot_mode}		= undef;
	$self->{radix_mode}		= undef;
	$self->{white_mode}		= undef;
	$self->{_sort_mode}		= undef;
	# path_mode    sits in App::PFM::Directory
	# color_mode   sits in App::PFM::Screen
	# ident_mode   sits in App::PFM::Screen::Diskinfo
	# mouse_mode   sits in App::PFM::Browser
	# swap_mode    sits in App::PFM::Browser
	# clobber_mode sits in App::PFM::CommandHandler
}

=item _clone( [ array @args ] )

Performs one phase of the cloning process by cloning an existing
App::PFM::Directory instance.

Arguments are passed to the clone() function of the Directory object.

=cut

sub _clone {
	my ($self, $original, @args) = @_;
	$self->{_directory} = $original->{_directory}->clone(@args);
}

##########################################################################
# constructor, getters and setters

=item directory( [ App::PFM::Directory $directory ] )

Getter/setter for the App::PFM::Directory object.

=cut

sub directory {
	my ($self, $value) = @_;
	$self->{_directory} = $value if defined $value;
	return $self->{_directory};
}

=item sort_mode( [ string $sort_mode ] )

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

##########################################################################
# public subs

=item prepare(string $path [, string $sort_mode ] )

Prepares the contents of this state object. Called in case this state
is not to be displayed on-screen right away.

The I<path> argument is passed to the prepare() method of the Directory
object. I<sort_mode> specifies the initial sort mode.

=cut

sub prepare {
	my ($self, $path, $sort_mode) = @_;
	$self->sort_mode($sort_mode || $self->{_config}{sort_mode});
	$self->{dot_mode}   = $self->{_config}{dot_mode};
	$self->{radix_mode} = $self->{_config}{radix_mode};
	$self->{white_mode} = $self->{_config}{white_mode};
	$self->{_position}  = '.';
	$self->{_baseindex} = 0;
	$self->{_directory}->prepare($path);
}

=item on_after_parse_config(App::PFM::Event $event)

Applies the config settings when the config file has been read and parsed.

=cut

sub on_after_parse_config {
	my ($self, $event) = @_;
	# store config
	my $pfmrc        = $event->{data};
	$self->{_config} = $event->{origin};
	$self->sort_mode(           $self->{_config}{sort_mode});
	$self->{dot_mode}         = $self->{_config}{dot_mode};
	$self->{radix_mode}       = $self->{_config}{radix_mode};
	$self->{white_mode}       = $self->{_config}{white_mode};
	$self->directory->path_mode($self->{_config}{path_mode});
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
