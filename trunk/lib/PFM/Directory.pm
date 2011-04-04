#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Directory 2010-03-27 v0.01
#
# Name:			PFM::Directory.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Directory class, containing the directory
#				contents and the actions that can be performed on them.
#

##########################################################################
# declarations

package PFM::Directory;

use base 'PFM::Abstract';

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

sub dirsort {
	my $self = shift;
	#TODO
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
