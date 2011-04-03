#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Abstract 2010-03-27 v0.01
#
# Name:			PFM::Abstract.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	The PFM Abstract class that defines shared functions.
#

##########################################################################
# declarations

package PFM::Abstract;

use Carp;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

sub new {
	my $type = shift;
	if ($type eq __PACKAGE__) {
		croak(__PACKAGE__, ' should not be instantiated');
	}
	$type = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	$self->_init();
	return $self;
}

##########################################################################
# public subs

#sub must_be_called_statically {
#	my ($self, $parent) = @_;
#	return unless ref $parent;
#	my ($package, $method);
#	($package, undef, undef, $method) = caller(1);
#	carp("$method() cannot be called dynamically");
#}
#
#sub must_be_called_dynamically {
#	my ($self, $parent) = @_;
#	return if ref $parent;
#	my ($package, $method);
#	($package, undef, undef, $method) = caller(1);
#	carp("$method() cannot be called statically");
#}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
