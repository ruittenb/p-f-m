#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job::Abstract 0.01
#
# Name:			PFM::Job::Abstract.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
#

##########################################################################

=pod

=head1 NAME

PFM::Job::Abstract

=head1 DESCRIPTION

Abstract PFM Job class for defining a common interface to Jobs.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Job::Abstract;

use Carp;
use strict;

use base 'PFM::Abstract';

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub start {
	my $self = shift;
	my $class = ref($self) || $self;
	croak("$class does not implement a start() method");
}

sub poll {
	my $self = shift;
	my $class = ref($self) || $self;
	croak("$class does not implement a poll() method");
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
