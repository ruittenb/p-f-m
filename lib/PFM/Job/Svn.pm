#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job::Svn 2010-03-27 v0.01
#
# Name:			PFM::Job::Svn.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Job class for Subversion commands.
#

##########################################################################
# declarations

package PFM::Job::Svn;

use base 'PFM::Abstract';

my $_command = 'svn status';

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
