#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Abstract 0.06
#
# Name:			App::PFM::Abstract
# Version:		0.06
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-07
#

##########################################################################

=pod

=head1 NAME

App::PFM::Abstract

=head1 DESCRIPTION

The PFM Abstract class from which the other classes are derived.
It defines shared functions.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Abstract;

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

Constructor for all classes based on App::PFM::Abstract.

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

Clone one object to create an independent one. By calling
the _clone() method, each class can define which contained objects
must be recursively cloned.

=cut

sub clone {
	my $original = shift;
	my $type     = ref $original;
	unless ($type) {
		croak("clone() cannot be called statically " .
			"(it needs an object to clone)");
	}
	my $clone = { %$original };
	bless($clone, $type);
	$clone->_clone($original, @_);
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
