#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Abstract 0.07
#
# Name:			App::PFM::Abstract
# Version:		0.07
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-13
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
	my $self = {
		event_handlers => {},
	};
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

=item register_listener()

Register the code reference provided as listener for the specified event.
Example usage:

	package Parent;

	my $onGreet = sub {
		system "xmessage 'Hello, world!'";
	};
	$child->register_listener('greetWorld', $onGreet);

	package Child;

	$self->fire('greetWorld');

=cut

sub register_listener {
	my ($self, $event, $listener) = @_;
	return 0 unless (ref $listener eq "CODE");
	my $handlers = $self->{event_handlers};
	if (!exists $handlers->{$event}) {
		$handlers->{$event} = [];
	}
	# do we want to push or unshift here?
	push @{$handlers->{$event}}, $listener;
	return 1;
}

=item unregister_listener()

Unregisters the code reference provided as listener for the specified event.

=cut

sub unregister_listener {
	my ($self, $event, $listener) = @_;
	return 0 unless (ref $listener eq "CODE");
	my $handlers = $self->{event_handlers};
	return 0 unless exists $handlers->{$event};
	my $success = 0;
	foreach my $i (reverse 0 .. $#{$handlers->{$event}}) {
		if ($listener == ${$handlers->{$event}}[$i]) {
			$success = 1;
			splice @{$handlers->{$event}}, $i, 1;
		}
	}
	return $success;
}

=item fire()

Fire an event. Calls all event handlers that have registered themselves.

=cut

sub fire {
	my ($self, $event, @args) = @_;
	my $handlers = $self->{event_handlers}->{$event};
	my @res;
	return unless $handlers;
	foreach (@$handlers) {
		push @res, $_->(@args);
	}
	return wantarray ? @res : join ':', @res;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
