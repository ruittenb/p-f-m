#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::JobHandler 0.01
#
# Name:			App::PFM::JobHandler.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
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
use App::PFM::Job::Subversion;
use App::PFM::Job::Cvs;
use App::PFM::Job::Bazaar;

use strict;

my ($_pfm, @_jobs);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
}

##########################################################################
# constructor, getters and setters

=item job

Getter/setter for the job with the specified jobnumber.

=cut

sub job {
	my ($self, $index, $value) = @_;
	$index ||= 0;
	if (defined $value) {
		$_jobs[$index] = $value;
	}
	return $_jobs[$index];
}

##########################################################################
# public subs

=item start()

Starts one job with the name specified. Adds the job to the internal
job stack. Returns the jobnumber.

=cut

sub start {
	my ($self, $class, @args) = @_;
	$class =~ tr/a-zA-Z0-9_//cd;
	$class = "App::PFM::Job::$class";
	my $job = $class->new($_pfm);
	push @_jobs, $job;
	$job->start(@args);
	return $#_jobs;
}

=item poll()

Polls the job with the number provided. If it is done, the job is
removed from the stack. Returns a boolean indicating if the job is
still running.

=cut

sub poll() {
	my ($self, $jobnr) = @_;
	return 0 unless defined $_jobs[$jobnr];
	my $ret = $_jobs[$jobnr]->poll();
	unless ($ret) {
		# We cannot use splice() here because it would change
		# the index of the individual jobs. Or we should rewrite
		# @_jobs as %_jobs.
		delete $_jobs[$jobnr];
	}
	return $ret;
}

=item pollall()

Polls all jobs on the stack for output. If they are done, they are
removed from the stack. It is the job's responsability to return data
to the application.

=cut

sub pollall {
	my $self = shift;
	my $i;
	for ($i = 0; $i < $#_jobs; $i++) {
		$self->poll($i);
	}
	# Note that this does not return the number of running jobs,
	# but instead the total number of elements, some of which may
	# have finished already.
	return scalar @_jobs;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
