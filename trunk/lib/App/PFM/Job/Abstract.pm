#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Abstract 0.52
#
# Name:			App::PFM::Job::Abstract
# Version:		0.52
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-05-14
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::Abstract

=head1 DESCRIPTION

Abstract PFM Job class for defining a common interface to Jobs.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::Abstract;

use base 'App::PFM::Abstract';

use IO::Pipe;
use Carp;
use strict;

##########################################################################
# private subs

=item _init()

Initializes the 'running' flag, and assigns the hash of event handlers.

=cut

sub _init {
	my ($self, %o) = @_;
	$self->{_running} = 0;
	$self->{_pipe}    = undef;
	$self->{_on}      = { %o };
}

=item _fire_event()

Fires an event. Currently supported events are:

=over 2

=item before_start

Called before starting the job. If the handler returns false, starting
the job is aborted.

=item after_start

Called when the job has started.

=item after_receive_data

Called when data has been received from the job.

=item after_finish

Called when the job has finished.

=back

=cut

sub _fire_event {
	my ($self, $event) = @_;
	if (defined $self->{_on}->{$event}) {
		return $self->{_on}->{$event}->();
	}
	return 1;
}

=item _catch_child()

Cleans up finished child processes.

=cut

sub _catch_child {
	# my ($self) = @_;
	(wait() == -1) ? 0 : $?;
}

=item _start_child()

Stub routine for starting the actual job.

=cut

sub _start_child {
	# my ($self) = @_;
}

=item _stop_child()

Stub routine for stopping the job.

=cut

sub _stop_child {
	# my ($self) = @_;
}

##########################################################################
# constructor, getters and setters

=item on()

Registers an event handler. At most one handler is supported per event.

=cut

sub on {
	my ($self, $event, $handler) = @_;
	$self->{_on}->{$event} = $handler;
}

##########################################################################
# public subs

=item isapplicable()

Stub routine for telling if the job is applicable.

=cut

sub isapplicable {
	# my ($self) = @_;
	return 0;
}

=item start()

Fires the I<before_start> event. If this returns true, it sets the
'running' flag, opens a pipe, starts the job and fires the
I<after_start> event.

=cut

sub start {
	my ($self) = @_;
	return 0 if $self->{_running};
	return 0 unless $self->_fire_event('before_start');
	$SIG{CHLD} = \&_catch_child;
	$self->{_pipe} = new IO::Pipe();
	$self->_start_child();
	$self->{_running} = 1;
	$self->_fire_event('after_start');
}

=item poll()

Checks if there is data available on the pipe, and if so, processes it
and fires the I<after_receive_data> event.

=cut

sub poll {
	my ($self) = @_;
	return 0 unless $self->{_running};
	# TODO
}

=item stop()

Resets the 'running' flag, stops the job, closes the pipe and fires the
I<after_finish> event.

=cut

sub stop {
	my ($self) = @_;
	return 0 unless $self->{_running};
	$self->{_running} = 0;
	$self->_stop_child();
	$self->{_pipe}->close();
	$self->_fire_event('after_finish');
	return 0;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
