#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Frame 2010-03-27 v0.01
#
# Name:			PFM::Screen::Frame.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	Subclass of PFM::Screen, used for drawing a frame
#				(header, footer and column headings)
#

package PFM::Screen::Frame;

#use constant {
#};
#
#my ();

##########################################################################
# private subs

sub _init {
	my $self = shift;
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

sub draw_frame {
	my $self = shift;
	# TODO
	return $self;
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
