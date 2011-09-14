#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Event 0.09
#
# Name:			App::PFM::Event
# Version:		0.09
# Author:		Rene Uittenbogaard
# Created:		2010-08-30
# Date:			2010-09-09
#

##########################################################################

=pod

=head1 NAME

App::PFM::Event

=head1 DESCRIPTION

This class defines events that can occur in and be handled by pfm.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Event;

use Carp;

use strict;
use locale;

use constant KNOWN_PROPERTIES => {
	name		=> 1, # event name (mandatory)
	origin		=> 1, # object
	type		=> 1, # 'key', 'mouse', 'job', 'soft', 'resize'
	data		=> 1, # received data (for 'key' and 'job')
	mousebutton	=> 1, # mouse button       (for 'mouse')
	mouserow	=> 1, # mouse row          (for 'mouse')
	mousecol	=> 1, # mouse column       (for 'mouse')
	mouseitem	=> 1, # mouse clicked item (for 'mouse')
	currentfile	=> 1, # current file, if fired by the Browser
	lunchbox	=> 1, # misc data (always added by constructor)
};

use constant KNOWN_EVENTS => {
	browser_idle					=> 1, # Browser
	resize_window					=> 1, # Screen
	before_job_start				=> 1, # Job
	after_job_start					=> 1, # Job
	after_job_receive_data			=> 1, # Job
	after_job_finish				=> 1, # Job
	after_create_entry				=> 1, # CommandHandler
	after_parse_usecolor			=> 1, # Config
	after_receive_user_input		=> 1, # Screen
	after_receive_non_motion_input	=> 1, # Browser
};

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

=item new(hashref $args)

Initializes new instances. Called from the constructor.
Copies known object properties from the options to the new object.

=cut

sub new {
	my ($type, $args) = @_;
	$type = ref($type) || $type;
	my $self = {
		lunchbox => {},
	};
	my @keys = grep {
		${KNOWN_PROPERTIES()}{$_}
	} keys %$args;
	@{$self}{@keys} = @{$args}{@keys};
	unless ($self->{name}) {
		croak('Event is missing mandatory property "name"');
	}
	unless (${KNOWN_EVENTS()}{$self->{name}}) {
		croak(sprintf('"%s" is not a known event name', $self->{name}));
	}
	bless($self, $type);
	return $self;
}

##########################################################################
# public subs

=item clone()

Clone the Event object. References inside the event are conserved, I<i.e.>
objects contained inside the event are not cloned.

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
	return $clone;
}

##########################################################################

=back

=head1 EVENT PROPERTIES

Event objects have got the following properties:

=over

=item name

The name of the event, also to be used by (un)register_listener().
This is a mandatory property.

=item origin

The object from which this event originates.

=item type

Allowed values:

=over 2

=item key

A keyboard command has been received.

=item mouse

A mouse command has been received.

=item job

A job receives input

=item soft

A 'soft' event that does not provide data.

=item resize

A window resize has been requested.

=back

=item data

The received data (for B<key> and B<job>).

=item mousebutton

The mouse button which was clicked (for B<mouse>).

=item mouserow

The screen row on which the mouse was clicked (for B<mouse>).

=item mousecol

The screen column on which the mouse was clicked (for B<mouse>).

=item currentfile

The current File object, to pass it from the Browser to the CommandHandler.

=item lunchbox

A container for miscellaneous data.

=back

=head1 SEE ALSO

pfm(1), App::PFM::Abstract.

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
