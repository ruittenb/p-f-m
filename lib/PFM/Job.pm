#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job 0.01
#
# Name:			PFM::Job.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
#

##########################################################################

=pod

=head1 NAME

PFM::Job

=head1 DESCRIPTION

PFM Job class, used for: firing off commands in the background,
polling them to see if output is available, and returning their
output to the application.

=head1 METHODS

=over

=cut

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
