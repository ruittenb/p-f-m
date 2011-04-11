#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::State 0.12
#
# Name:			PFM::State.pm
# Version:		0.12
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-10
#

##########################################################################

=pod

=head1 NAME

PFM::State

=head1 DESCRIPTION

PFM class used for storing the current state of the application.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::State;

use base 'PFM::Abstract';

use PFM::Directory;

use strict;

my $_pfm;

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.
Instantiates a PFM::Directory object.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm					= $pfm;
	$self->{_directory}		= new PFM::Directory($pfm);
	# We might not have useful values for these yet since the config file
	# might not have been read yet.
	$self->{_position}		= undef;
	$self->{multiple_mode}	= 0;
	$self->{dot_mode}		= undef;
	$self->{radix_mode}		= undef;
	$self->{sort_mode}		= undef;
	$self->{white_mode}		= undef;
	# path_mode    sits in PFM::Directory
	# color_mode   sits in PFM::Screen
	# ident_mode   sits in PFM::Screen::Diskinfo
	# mouse_mode   sits in PFM::Browser
	# swap_mode    sits in PFM::Browser
	# clobber_mode sits in PFM::CommandHandler
}

=item _clone()

Performs one phase of the cloning process by cloning an existing
PFM::Directory instance.

=cut

sub _clone {
	my ($self, $original, @args) = @_;
	$self->{_directory} = $original->{_directory}->clone(@args);
}

##########################################################################
# constructor, getters and setters

=item directory()

Getter/setter for the PFM::Directory object.

=cut

sub directory {
	my ($self, $value) = @_;
	$self->{_directory} = $value if defined $value;
	return $self->{_directory};
}

=item currentdir()

Getter/setter for the current directory path.
If a new directory is provided, it will be passed to PFM::Directory.

=cut

sub currentdir {
	my $self = shift;
	return $self->{_directory}->path(@_);
}

##########################################################################
# public subs

=item prepare()

Prepares the contents of this state object. Called in case this state
is not to be displayed on-screen right away.

=cut

sub prepare {
	my ($self, $path) = @_;
	$self->{dot_mode}	= $_pfm->config->{dot_mode};
	$self->{radix_mode}	= $_pfm->config->{radix_mode};
	$self->{sort_mode}	= $_pfm->config->{sort_mode};
	$self->{white_mode}	= $_pfm->config->{white_mode};
	$self->{_position}	= '.';
	$self->{_directory}->prepare($path);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4: