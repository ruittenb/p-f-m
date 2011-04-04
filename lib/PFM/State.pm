#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::State 2010-03-27 v0.01
#
# Name:			PFM::State.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM class used for storing the current state of the
#				application.
#

##########################################################################
# declarations

package PFM::State;

use base 'PFM::Abstract';

use PFM::Directory;

my ($_pfm, $_directory);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $swap_mode) = @_;
	$_pfm					= $pfm;
	$self->{multiple_mode}	= 0;
	$self->{swap_mode}		= $swap_mode;
	# TODO some of these may have to be moved elsewhere.
	$self->{color_mode}		= 0;
	$self->{sort_mode}		= 0;
	$self->{currentlayout}	= 0;
	$self->{mouse_mode}		= 0;
	$self->{clobber_mode}	= 0;
	$self->{dot_mode}		= 0;
	$self->{white_mode}		= 0;
	$self->{path_mode}		= 0;
	$self->{radix_mode}		= 0;
	$self->{ident_mode}		= 0;
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

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
