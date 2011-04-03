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

package PFM::State;

##########################################################################
# private subs

sub _init {
	my $self = shift;
	%_selected_nr_of = %_total_nr_of = ();
	$self->{selected_nr_of}	= %_selected_nr_of;
	$self->{total_nr_of}	= %_total_nr_of;
	$self->{multiple_mode}	= 0;
}

##########################################################################
# constructor, getters and setters

sub new {
	my $type = shift;
	$type = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	$self->_init();
	return $self;
}

##########################################################################
# public subs

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
