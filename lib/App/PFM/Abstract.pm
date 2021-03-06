#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Abstract 0.18
#
# Name:			App::PFM::Abstract
# Version:		0.18
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2011-09-05
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

use Data::Dumper;
use Carp;

use strict;

##########################################################################
# private subs

=item I<_init()>

Stub init method to ensure it exists.

=cut

sub _init {
}

=item I<_clone()>

Stub clone method to ensure it exists.

=cut

sub _clone {
}

##########################################################################
# constructor, getters and setters

=item I<new( [ array @args ] )>

Constructor for all classes based on App::PFM::Abstract.

The I<args> are passed to the _init() methods of individual classes.

=cut

sub new {
	my ($type, @args) = @_;
	$type = ref($type) || $type;
	my $self = {
		_event_handlers => {},
	};
	bless($self, $type);
	$self->_init(@args);
	return $self;
}

=item I<clone( [ array @args ] )>

Clone one object to create an independent one. By providing
a _clone() method, each class can define which contained objects
must be recursively cloned.

The I<args> are passed to the _clone() methods of individual classes.

=cut

sub clone {
	my ($original, @args) = @_;
	my $type = ref $original;
	unless ($type) {
		croak("clone() cannot be called statically " .
			"(it needs an object to clone)");
	}
	my $clone = { %$original };
	bless($clone, $type);
	$clone->_clone($original, @args);
	return $clone;
}

##########################################################################
# public subs

=item I<register_listener(string $event_name, coderef $code)>

Register the code reference provided as listener for the specified event.
For an example, see below under fire().

=cut

sub register_listener {
	my ($self, $event_name, $listener) = @_;
	return 0 unless (ref $listener eq "CODE");
	my $handlers = $self->{_event_handlers};
	if (!exists $handlers->{$event_name}) {
		$handlers->{$event_name} = [];
	}
	# do we want to push or unshift here?
	push @{$handlers->{$event_name}}, $listener;
	return 1;
}

=item I<unregister_listener(string $event_name [ , coderef $code ] )>

If a I<code> argument is provided, unregisters it as listener for the
specified event. If no I<code> argument is provided, unregisters all listeners
for the specified event.

=cut

sub unregister_listener {
	my ($self, $event_name, $listener) = @_;
	return 0 unless (ref $listener eq "CODE");
	my $handlers = $self->{_event_handlers};
	return 0 unless exists $handlers->{$event_name};
	my $success = 0;
	foreach my $i (reverse 0 .. $#{$handlers->{$event_name}}) {
		if (!defined ($listener) or
			$listener == ${$handlers->{$event_name}}[$i]
		) {
			$success = 1;
			splice @{$handlers->{$event_name}}, $i, 1;
		}
	}
	return $success;
}

=item I<fire(App::PFM::Event $event)>

Fire an event. Calls all event handlers that have registered themselves.
Returns the handler results as an array or joined string, or I<'0 but true'>
if there are no handlers.

Example usage:

	package Parent;

	sub start()
	{
		my $onGreet = sub {
			my $event = shift;
			my $who = $event->{data};
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
		$self->fire(App::PFM::Event->new({
			name => 'greetWorld', 
			data => 'Fred'
		}));
	}

=cut

sub fire {
	my ($self, $event) = @_;
	my $handlers = $self->{_event_handlers}->{$event->{name}};
	return '0 but true' unless $handlers;
	my @res;
	foreach (@$handlers) {
		push @res, $_->($event);
	}
	return wantarray ? @res : join ':', @res;
}

=item I<debug()>

Dumps the contents of this object using Data::Dumper(3pm).
Primarily used for debugging.

=cut

sub debug {
	my ($self) = @_;
	$Data::Dumper::Sortkeys = sub {
		my %h = %{$_[0]};
		return [
			grep { $_ ne 'TERM' } keys %h
		];
	};
	print Dumper $self;
	return;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
