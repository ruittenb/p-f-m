#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Abstract 0.01
#
# Name:			PFM::Abstract.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
#

##########################################################################

=pod

=head1 NAME

PFM::Abstract

=head1 DESCRIPTION

The PFM Abstract class from which the other classes are derived.
It defines shared functions.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Abstract;

use Carp;

use strict;

##########################################################################
# private subs

sub _init() {
	carp('_init() not defined');
}

##########################################################################
# constructor, getters and setters

=item new()

Constructor for all classes based on PFM::Abstract.

=cut

sub new {
	my $type = shift;
	if ($type =~ /::Abstract$/) {
		croak("$type should not be instantiated");
	}
	$type = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	$self->_init(@_);
	return $self;
}

=item clone()

Clone one object to create an independent one. References
stored in the object will be copied as-is to the clone.

=cut

sub clone {
	my $self  = shift;
	my $type  = ref $self;
	my $clone = { %$self };
	unless ($type) {
		croak("clone() cannot be called statically (there is nothing to clone)");
	}
	bless($clone, $type);
	return $clone;
}

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
