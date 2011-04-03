#!/usr/bin/env perl

package PFM::Abstract;

use Carp;

# private subs

sub new {
	my $type = shift;
	if ($type eq __PACKAGE__) {
		croak("PFM::Abstract is not meant to be instantiated");
	}
	$type = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	$self->_init();
	return $self;
}

# public subs

sub must_be_called_statically {
	my ($self, $parent) = @_;
	return unless ref $parent;
	my ($package, $method);
	($package, undef, undef, $method) = caller(1);
	carp("$method() cannot be called dynamically");
}

sub must_be_called_dynamically {
	my ($self, $parent) = @_;
	return if ref $parent;
	my ($package, $method);
	($package, undef, undef, $method) = caller(1);
	carp("$method() cannot be called statically");
}

1;

# vim: set tabstop=4 shiftwidth=4:
