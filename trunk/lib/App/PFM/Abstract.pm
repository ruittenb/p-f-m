#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Abstract 0.10
#
# Name:			App::PFM::Abstract
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-16
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

=item new( [ array @args ] )

Constructor for all classes based on App::PFM::Abstract.

The I<args> are passed to the _init() methods of individual classes.

=cut

sub new {
	my $type = shift;
	$type = ref($type) || $type;
#	if ($type =~ /::Abstract$/) {
#		croak("$type should not be instantiated");
#	}
	my $self = {
		_event_handlers => {},
	};
	bless($self, $type);
	$self->_init(@_);
	return $self;
}

=item clone( [ array @args ] )

Clone one object to create an independent one. By calling
the _clone() method, each class can define which contained objects
must be recursively cloned.

The I<args> are passed to the _init() methods of individual classes.

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

=item register_listener(string $event, coderef $code)

Register the code reference provided as listener for the specified event.
For an example, see below under fire().

=cut

sub register_listener {
	my ($self, $event, $listener) = @_;
	return 0 unless (ref $listener eq "CODE");
	my $handlers = $self->{_event_handlers};
	if (!exists $handlers->{$event}) {
		$handlers->{$event} = [];
	}
	# do we want to push or unshift here?
	push @{$handlers->{$event}}, $listener;
	return 1;
}

=item unregister_listener(string $event, coderef $code)

Unregisters the code reference provided as listener for the specified event.

=cut

sub unregister_listener {
	my ($self, $event, $listener) = @_;
	return 0 unless (ref $listener eq "CODE");
	my $handlers = $self->{_event_handlers};
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

=item fire_event(string $event [, array @args ] )

Fire an event. Calls all event handlers that have registered themselves.

Example usage:

	package Parent;

	sub start()
	{
		my $onGreet = sub {
			my $who = shift;
			system "xmessage 'Hello, $who!'";
		};
		$child = new Child();
		$child->register_listener('greetWorld', $onGreet);
		$child->do_something();
	}

	package Child;

	sub do_something()
	{
		my $self = shift;
		$self->fire('greetWorld', 'Fred');
	}

=cut

sub fire_event {
	my ($self, $event, @args) = @_;
	my $handlers = $self->{_event_handlers}->{$event};
	my @res;
	return '0 but true' unless $handlers;
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
