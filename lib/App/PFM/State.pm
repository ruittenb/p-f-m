#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::State 0.13
#
# Name:			App::PFM::State
# Version:		0.13
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-06-16
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

our $_pfm;

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm)

Initializes new instances. Called from the constructor.
Instantiates a App::PFM::Directory object.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm					||= $pfm;
	$self->{_directory}		= new App::PFM::Directory($pfm);
	# We might not have useful values for these yet since the config file
	# might not have been read yet.
	$self->{_position}		= undef;
	$self->{_baseindex}		= undef;
	$self->{multiple_mode}	= 0;
	$self->{dot_mode}		= undef;
	$self->{radix_mode}		= undef;
	$self->{sort_mode}		= undef;
	$self->{white_mode}		= undef;
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

##########################################################################
# public subs

=item prepare(string $path)

Prepares the contents of this state object. Called in case this state
is not to be displayed on-screen right away.

The I<path> argument is passed to the prepare() method of the Directory
object.

=cut

sub prepare {
	my ($self, $path) = @_;
	$self->{dot_mode}	= $_pfm->config->{dot_mode};
	$self->{radix_mode}	= $_pfm->config->{radix_mode};
	$self->{sort_mode}	= $_pfm->config->{sort_mode};
	$self->{white_mode}	= $_pfm->config->{white_mode};
	$self->{_position}	= '.';
	$self->{_baseindex}	= 0;
	$self->{_directory}->prepare($path);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
