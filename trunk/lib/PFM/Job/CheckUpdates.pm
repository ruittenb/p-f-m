#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job::CheckUpdates 0.01
#
# Name:			PFM::Job::CheckUpdates.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
#

##########################################################################

=pod

=head1 NAME

PFM::Job::CheckUpdates

=head1 DESCRIPTION

PFM Job class for checking for application updates.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Job::CheckUpdates;

use base 'PFM::Job::Abstract';

use strict;

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

pfm(1), PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
