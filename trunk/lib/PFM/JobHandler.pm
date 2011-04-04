#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::JobHandler 0.01
#
# Name:			PFM::JobHandler.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
#

##########################################################################

=pod

=head1 NAME

PFM::JobHandler

=head1 DESCRIPTION

PFM JobHandler class, used to manage jobs (commands running in the
background).

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::JobHandler;

use base 'PFM::Abstract';

use PFM::Job::CheckUpdates;
use PFM::Job::Subversion;
use PFM::Job::Cvs;
use PFM::Job::Bazaar;

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
	$class = "PFM::Job::$class";
	my $job = $class->new($_pfm);
	push @_jobs, $job;
	$job->start(@args);
	return $#_jobs;
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
		next unless defined $_jobs[$i];
		unless ($_jobs[$i]->poll()) {
			# We cannot use splice() here because it would change
			# the index of the individual jobs. Or we should rewrite
			# @_jobs as %_jobs.
			delete $_jobs[$i];
		}
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
