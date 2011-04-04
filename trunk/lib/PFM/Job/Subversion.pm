#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job::Subversion 0.01
#
# Name:			PFM::Job::Subversion.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
#

##########################################################################

=pod

=head1 NAME

PFM::Job::Subversion

=head1 DESCRIPTION

PFM Job class for Subversion commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Job::Subversion;

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

=back

=head1 SEE ALSO

pfm(1), PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
