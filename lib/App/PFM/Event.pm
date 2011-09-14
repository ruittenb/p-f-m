#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Event 0.04
#
# Name:			App::PFM::Event
# Version:		0.04
# Author:		Rene Uittenbogaard
# Created:		2010-08-30
# Date:			2010-08-30
#

##########################################################################

=pod

=head1 NAME

App::PFM::Event

=head1 DESCRIPTION

This class defines events that can occur and be handled in pfm.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Event;

use constant KNOWN_FIELDS => {
	name		=> 1, # event name (mandatory)
	origin		=> 1, # object
	type		=> 1, # 'key', 'mouse', 'job', 'soft', 'resize'
	data		=> 1, # received data (for 'key' and 'job')
	mousebutton	=> 1, # mouse button  (for 'mouse')
	mouserow	=> 1, # mouse row     (for 'mouse')
	mousecol	=> 1, # mouse column  (for 'mouse')
};

use constant KNOWN_EVENTS => {
	resize_window					=> 1, # screen
	before_job_start				=> 1, # job
	after_job_start					=> 1, # job
	after_job_receive_data			=> 1, # job
	after_job_finish				=> 1, # job
	after_parse_usecolor			=> 1, # config
	after_receive_user_input		=> 1, # screen
	after_receive_non_motion_input	=> 1, # browser
};

use Carp;
use strict;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

=item new(hashref $args)

Initializes new instances. Called from the constructor.
Copies known class fields from the options to the new object.

=cut

sub new {
	my ($type, $args) = @_;
	$type = ref($type) || $type;
	my $self = {};
	my @keys = grep {
		${KNOWN_FIELDS()}{$_}
	} keys %$args;
	@{$self}{@keys} = @{$args}{@keys};
	unless ($self->{name}) {
		croak('Event is missing mandatory field "name"');
	}
	unless (${KNOWN_EVENTS()}{$self->{name}}) {
		croak(sprintf('"%s" is not a known event name', $self->{name}));
	}
	bless($self, $type);
	return $self;
}

##########################################################################
# public subs

##########################################################################

=back

=head1 EVENT FIELDS

Event objects have got the following fields:

=over

=item name

The name of the event, also to be used by (un)register_listener().
This is a mandatory field.

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

=back

=head1 SEE ALSO

pfm(1), App::PFM::Abstract.

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
