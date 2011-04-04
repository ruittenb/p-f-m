#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Abstract 0.06
#
# Name:			PFM::Abstract.pm
# Version:		0.06
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-07
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

=item _init()

Stub init method to ensure it exists.

=cut

sub _init() {
}

=item _clone()

Stub clone method to ensure it exists.

=cut

sub _clone() {
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
	unless ($type) {
		croak("clone() cannot be called statically " .
			"(it needs an object to clone)");
	}
	my $clone = { %$self };
	bless($clone, $type);
	$clone->_clone($self, @_);
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
