#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job 0.01
#
# Name:			PFM::Job.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
#

##########################################################################

=pod

=head1 NAME

PFM::Job

=head1 DESCRIPTION

PFM Job class, used to fire off commands in the background and to
poll them to see if output is available.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Job;

use base 'PFM::Abstract';

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

##########################################################################
# public subs

=item start()

Starts one job with the name specified. Adds the job to the internal
job stack.

=cut

sub start {
	my ($self, $class, @args) = @_;
	$class =~ tr/a-zA-Z0-9_//cd;
	$class = "PFM::Job::$class";
	my $job = eval "use $class; return $class->new($_pfm);";
	push @_jobs, $job;
	$job->start(@args);
	return $job;
}

=item pollall()

Polls all jobs on the stack for output. If they are done, they are removed
from the stack. Returns the number of running jobs. It is the job's
responsability to return data to the application.

=cut

sub pollall {
	my $self = shift;
	foreach my $i (0..$#_jobs) {
		unless ($_jobs[$i]->poll()) {
			delete $_jobs[$i];
		}
	}
	return scalar @_jobs;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
