#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Abstract 1.10
#
# Name:			App::PFM::Job::Abstract
# Version:		1.10
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2014-04-09
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

use App::PFM::Event;

use IO::Pipe;
use IO::Select;
use Carp;
use strict;
use locale;

use constant KILL_DELAY => 0.100;

##########################################################################
# private subs

=item I<< _init(hashref { $eventname1 => coderef $handler1 [, ...] } >>
I<< [, hashref $options ] ) >>

Initializes the 'running' flag ('childpid'), and registers the
provided event handlers.

=cut

sub _init {
	my ($self, $handlers, $options) = @_;
	$self->{_childpid}    = 0;
	$self->{_pipe}        = undef;
	$self->{_selector}    = IO::Select->new();
	$self->{_options}     = $options;
	$self->{_line_buffer} = '';
	$self->{_poll_buffer} = undef;
	$self->{_stop_next_iteration} = 0;
	foreach (keys %$handlers) {
		$self->register_listener($_, ${$handlers}{$_});
	}
	return;
}

=item I<_catch_child()>

Cleans up finished child processes.

perlvar(1) warns us that: "If you have installed a signal handler for
SIGCHLD, the value of C<$?> will usually be wrong outside that handler."
Therefore, the child's exit code is fetched and propagated via
C<$App::PFM::Application::CHILD_ERROR>.

=cut

sub _catch_child {
	local ($!, $?);
	my ($self) = @_;
	# Reap.
	my $pid = wait();
	if ($pid == -1) {
		# There was no child to receive an exit status from (maybe it was
		# automatically reaped (see perlfunc(1)). Reset CHILD_ERROR.
		$App::PFM::Application::CHILD_ERROR = 0;
	}
	# Reinstall the reaper.
	$SIG{CHLD} = sub {
		# Fetch the child's exit code. This must be done *before* reaping it.
		$App::PFM::Application::CHILD_ERROR = $?;
		$self->_catch_child();
	};
	return;
}

=item I<_start_child()>

Stub routine for starting the actual job.

=cut

sub _start_child {
	# my ($self) = @_;
}

=item I<_stop_child()>

Routine for stopping the job. Send TERM, INT and QUIT signals.
Returns whether the job was stopped correctly.

=cut

sub _stop_child {
	my ($self) = @_;
	return "0 but true" unless $self->{_childpid};
	my $alive = kill TERM => $self->{_childpid};
	if ($alive) {
		select(undef, undef, undef, KILL_DELAY);
		$alive = kill TERM => $self->{_childpid} ||
				 kill INT  => $self->{_childpid} ||
				 kill QUIT => $self->{_childpid};
		if ($alive) {
			select(undef, undef, undef, KILL_DELAY);
			$alive = kill TERM => $self->{_childpid} ||
					 kill INT  => $self->{_childpid} ||
					 kill QUIT => $self->{_childpid};
#					 kill KILL => $self->{_childpid};
		}
	}
	return !$alive;
}

=item I<_poll_data()>

Checks if there is data available on the pipe, and if so, reads it and
sends it to the preprocessor.  If the preprocessor returns a defined value,
The output is accumulated in the poll buffer.

Returns a true value if the job is still running, false if it has finished.

=cut

sub _poll_data {
	my ($self) = @_;
	my ($can_read, $input, $newlinepos);
	# shortcut if not running
	return 0 unless $self->{_childpid};
	# handle delayed stopping
	if ($self->{_stop_next_iteration}) {
		$self->stop();
		return 0;
	}
	# Check if there is data ready on the filehandle. Make sure we return
	# true, because we want poll() to know we're still running.
	return $self->{_childpid} if ($self->{_selector}->can_read(0.001) <= 0);
	# the filehandle is ready
	if ($self->{_pipe}->sysread($input, 10000) > 0 or
		length $self->{_line_buffer})
	{
		$self->{_line_buffer} .= $input;
		JOB_LINE_INPUT: # the next line contains an assignment on purpose
		while (($newlinepos = index($self->{_line_buffer}, "\n")) >= 0) {
			# process one line of input.
			$input = substr($self->{_line_buffer}, 0, $newlinepos);
			$self->{_line_buffer} =
				substr($self->{_line_buffer}, $newlinepos + 1);
			# the next line contains an assignment on purpose
			if (defined($input = $self->_preprocess($input))) {
				push @{$self->{_poll_buffer}}, $input;
			}
		}
		goto &_poll_data; # continue parsing
	} else {
		# delayed stop
		$self->{_stop_next_iteration} = 1;
#		$self->stop();
	}
	return $self->{_childpid};
}

=item I<_preprocess(string $data)>

Stub routine for preprocessing job output.
This routine is used for "massaging" the command output
into a common format that can be used by the callback routine.

=cut

sub _preprocess {
	my ($self, $data) = @_;
	return $data;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item I<isapplicable()>

Stub routine for telling if the job is applicable. The job may not be
applicable if e.g. the current directory does not belong to the type of
RCS repository handled by the job.

=cut

sub isapplicable {
	# my ($self) = @_;
	return 0;
}

=item I<start()>

Fires the I<before_job_start> event. If this returns true, it sets
the 'running' flag, opens a pipe, starts the job and fires the
I<after_job_start> event.

Note that if no handler has been registered, the fire() method will
return I<0 but true>.

=cut

sub start {
	my ($self) = @_;
	return 0 if $self->{_childpid};
	return 0 unless $self->fire(App::PFM::Event->new({
		name   => 'before_job_start',
		origin => $self,  # not used ATM
		type   => 'soft', # not used ATM
	}));
	# The reaper causes problems in combination with system() on Darwin.
	# As a workaround, don't install it in that case. Note that this may
	# break si(Z)e.
	if ($^O ne 'darwin') {
		$SIG{CHLD} = sub {
			# Fetch the child's exit code. This must be done *before* reaping it.
			$App::PFM::Application::CHILD_ERROR = $?;
			$self->_catch_child();
		};
	}
	$self->{_stop_next_iteration} = 0;
	$self->{_line_buffer} = '';
	$self->{_pipe}        = IO::Pipe->new();
	$self->{_childpid}    = $self->_start_child();
	# If we were not successful, return false.
	return 0 unless $self->{_childpid};
	$self->{_selector}->add($self->{_pipe});
	$self->fire(App::PFM::Event->new({
		name   => 'after_job_start',
		origin => $self,  # not used ATM
		type   => 'soft', # not used ATM
	}));
	return 1;
}

=item I<poll()>

Calls _poll_data() to accumulate job data into a poll buffer.  When done
and if data is available, the I<after_job_receive_data> event is fired.

=cut

sub poll {
	my ($self, @args) = @_;
	$self->{_poll_buffer} = [];
	my $returnvalue = $self->_poll_data(@args);
	if (@{$self->{_poll_buffer}}) {
		$self->fire(
			App::PFM::Event->new({
					name   => 'after_job_receive_data',
					origin => $self,
					type   => 'job',
					data   => $self->{_poll_buffer},
				})
		);
	}
	return $returnvalue;
}

=item I<stop()>

Resets the 'running' flag, stops the job, closes the pipe and fires the
I<after_job_finish> event.

=cut

sub stop {
	my ($self) = @_;
	return 0 unless $self->{_childpid};
	$self->_stop_child();
	$self->{_childpid} = 0;
	$self->{_pipe}->close();
	$self->fire(App::PFM::Event->new({
		name   => 'after_job_finish',
		origin => $self,  # not used ATM
		type   => 'soft', # not used ATM
	}));
	$self->{_line_buffer} = '';
	#$self->{_event_handlers} = {}; # necessary for garbage collection?
	return 0;
}

##########################################################################

=back

=head1 EVENTS

This package implements the following events:

=over 2

=item before_job_start

Called before starting the job. If the handler returns false,
starting the job is aborted.

=item after_job_start

Called when the job has started.

=item after_job_receive_data

Called when data has been received from the job.

=item after_job_finish

Called when the job has finished.

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
