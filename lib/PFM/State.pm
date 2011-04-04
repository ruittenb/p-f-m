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

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
	my %empty_hash = ();
	$self->{selected_nr_of}	= %empty_hash;
	$self->{total_nr_of}	= %empty_hash;
	$self->{multiple_mode}	= 0;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
