#!/usr/bin/env perl

package PFM::Browser;

use PFM::Directory;

# private subs

sub new {
	my $type = shift;
	$type = ref($type) || $type;
	my $self = {};
	bless($self,$type);
	return $self;
}

# public subs

sub browse {
	my $self = shift;
	carp("$self::".(caller(0))[3]."() cannot be called statically")
		unless ref $self;
	$self->{_directory} = new PFM::Directory();
	#TODO
}

1;

# vim: set tabstop=4 shiftwidth=4:
