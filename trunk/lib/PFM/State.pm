#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::State 0.01
#
# Name:			PFM::State.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
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

my ($_pfm, $_directory,
	$_position);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.
Instantiates a PFM::Directory object.

=cut

sub _init {
	my ($self, $pfm, $swap_mode) = @_;
	$_pfm					= $pfm;
	$_directory				= new PFM::Directory($pfm);
	$self->{multiple_mode}	= 0;
	$self->{swap_mode}		= $swap_mode;
	# TODO some of these may have to be moved elsewhere.
	$self->{color_mode}		= 0; # Screen
	$self->{sort_mode}		= 0; # Screen::Listing
	$self->{currentlayout}	= 0; # Screen::Listing
	$self->{mouse_mode}		= 0; # Browser
	$self->{clobber_mode}	= 0; # CommandHandler
	$self->{dot_mode}		= 0; # Screen::Listing
	$self->{white_mode}		= 0; # Screen::Listing
	$self->{path_mode}		= 0; # Directory
	$self->{radix_mode}		= 0; # Screen::Listing
#	$self->{ident_mode}		= 0; # Screen::Diskinfo
}

##########################################################################
# constructor, getters and setters

=item directory()

Getter/setter for the PFM::Directory object.

=cut

sub directory {
	my ($self, $value) = @_;
	$_directory = $value if defined $value;
	return $_directory;
}

=item currentdir()

Getter/setter for the current directory path.
If a new directory is provided, it will be passed to PFM::Directory.

=cut

sub currentdir {
	my ($self, $value) = @_;
	return $_directory->path($value);
}

##########################################################################
# public subs

=item prepare()

Prepares the contents of this state object. Called in case this state
is not to be displayed on-screen right away.

=cut

sub prepare {
	my $self = shift;
	$_directory->init_dircount();
	$_directory->readcontents();
	$_directory->sortcontents();
	$_directory->filtercontents();
	$_position = '.';
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
