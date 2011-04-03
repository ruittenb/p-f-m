#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Browser 2010-03-27 v0.01
#
# Name:			PFM::Browser.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Browser class. This class is responsible for
#				executing the main browsing loop:
#				- wait for keypress
#				- dispatch command to CommandHandler
#				- refresh screen
#

##########################################################################
# declarations

package PFM::Browser;

use PFM::Directory;

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

sub browse {
	my $self = shift;
	#TODO
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
