#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job 2010-03-27 v0.01
#
# Name:			PFM::Job.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Job class. Supports:
#				- firing off commands in the background
#				- polling if output is available
#				- returning output to the application
#

##########################################################################
# declarations

package PFM::Job;

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

sub start {
	my $self = shift;
	#TODO
}

sub poll {
	my $self = shift;
	#TODO
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
