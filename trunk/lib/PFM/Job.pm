#!/usr/bin/env perl

package PFM::Job;

# private subs

sub new {
	my $type = shift;
	$type = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	return $self;
}

# public subs

sub start {
	my $self = shift;
	carp("$self::".(caller(0))[3]."() cannot be called statically")
		unless ref $self;
	#TODO
}

sub poll {
	my $self = shift;
	carp("$self::".(caller(0))[3]."() cannot be called statically")
		unless ref $self;
	#TODO
}

1;

# vim: set tabstop=4 shiftwidth=4:
