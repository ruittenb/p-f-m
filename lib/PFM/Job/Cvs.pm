#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job::Cvs 2010-03-27 v0.01
#
# Name:			PFM::Job::Cvs.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Job class for CVS commands.
#

##########################################################################
# declarations

package PFM::Job::Cvs;

use base 'PFM::Abstract';

my $_command = 'cvs --help'; # TODO

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub start {
	my $self = shift;
	#TODO
}

sub poll {
	my $self = shift;
	#TODO
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
