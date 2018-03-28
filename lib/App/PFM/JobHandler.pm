#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::JobHandler 0.18
#
# Name:			App::PFM::JobHandler
# Version:		0.18
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2018-03-28
#

##########################################################################

=pod

=head1 NAME

App::PFM::JobHandler

=head1 DESCRIPTION

PFM JobHandler class, used to manage jobs (commands running in the
background).

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::JobHandler;

use base 'App::PFM::Abstract';

use App::PFM::Job::CheckUpdates;
use App::PFM::Job::Cvs;
use App::PFM::Job::Bazaar;
use App::PFM::Job::Git;
use App::PFM::Job::Mercurial;
use App::PFM::Job::Subversion;

use POSIX ':sys_wait_h';

use strict;
use locale;

##########################################################################
# private subs

=item I<_init()>

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self) = @_;
	$self->{_jobs} = [];
	return;
}

=item I<_check_reaper_necessity()>

Finds out how many jobs are still running. Unregisters the reaper
if possible.

=cut

sub _check_reaper_necessity {
	my ($self) = @_;
	if ($self->count() <= 0) {
		$SIG{CHLD} = 'DEFAULT';
	}
	return;
}

##########################################################################
# constructor, getters and setters

=item I<job( [ int $index [, App::PFM::Job::Abstract $job ] ] )>

Getter/setter for the job with the specified jobnumber.

=cut

sub job {
	my ($self, $index, $value) = @_;
	$index ||= 0;
	if (defined $value) {
		$self->{_jobs}[$index] = $value;
	}
	return $self->{_jobs}[$index];
}

##########################################################################
# public subs

=item I<start(string $subclass [, array @args ] )>

Starts one job of the type specified. Adds the job to the internal
job stack. Returns the jobnumber.

Arguments are passed to the constructor of the job.

=cut

sub start {
	my ($self, $class, @args) = @_;
	$class =~ tr/a-zA-Z0-9_//cd;
	$class = "App::PFM::Job::$class";
	my $job = $class->new(@args);
	push @{$self->{_jobs}}, $job;
	$job->register_listener('after_job_finish', sub {
		$self->_check_reaper_necessity();
	});
	$job->start();
	return $#{$self->{_jobs}};
}

=item I<stop(int $jobno)>

Stops the job with the provided jobnumber.

=cut

sub stop {
	my ($self, $jobnr) = @_;
	return -1 unless defined $self->{_jobs}[$jobnr];
	my $ret = $self->{_jobs}[$jobnr]->stop();
	delete $self->{_jobs}[$jobnr];
	return $ret;
}

=item I<stopall()>

Stops all jobs.

=cut

sub stopall {
	my ($self) = @_;
	my ($i);
	for ($i = $#{$self->{_jobs}}; $i > 0; $i--) {
		$self->{_jobs}[$i]->stop();
		delete $self->{_jobs}[$i];
	}
	return 1;
}

=item I<poll(int $jobno)>

Polls the job with the number provided. If it is done, the job is
removed from the stack. Returns a boolean indicating if the job is
still running.

=cut

sub poll {
	my ($self, $jobnr) = @_;
	return 0 unless defined $self->{_jobs}[$jobnr];
	my $ret = $self->{_jobs}[$jobnr]->poll();
	unless ($ret) {
		# We cannot use splice() here because it would change
		# the index of the individual jobs. Or we should rewrite
		# @_jobs as %_jobs.
		delete ${$self->{_jobs}}[$jobnr];
	}
	return $ret;
}

=item I<pollall()>

Polls all jobs on the stack for output. If they are done, they are
removed from the stack. It is the job's responsibility to return data
to the application.

=cut

sub pollall {
	my ($self) = @_;
	my ($i);
	for ($i = 0; $i <= $#{$self->{_jobs}}; $i++) {
		$self->poll($i);
	}
	# we hoped that this would eliminate the need for a signal handler,
	# but it doesn't.
#	1 while waitpid(-1, WNOHANG) > 0;
	return $self->count();
}

=item I<count()>

Counts the number of running jobs.

=cut

sub count {
	my ($self)      = @_;
	my @jobs        = @{$self->{_jobs}};
	my @runningjobs = grep { $_->{_childpid} } @jobs;
	return scalar @runningjobs;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Job::Abstract(3pm), App::PFM::Job::Bazaar(3pm),
App::PFM::Job::CheckUpdates(3pm), App::PFM::Job::Cvs(3pm),
App::PFM::Job::Git(3pm), App::PFM::Job::RCS(3pm),
App::PFM::Job::Mercurial(3pm), App::PFM::Job::Subversion(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
