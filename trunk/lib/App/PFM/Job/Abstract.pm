#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Abstract 0.01
#
# Name:			App::PFM::Job::Abstract
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
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

Initialize the 'running' flag.

=cut

sub _init() {
	my ($self, %o) = @_;
	$self->{_running} = 0;
	$self->{_pipe}    = undef;
	$self->{_on}      = { %o };
	$self->SUPER::_init();
}

=item _reaper()

Cleans up finished child processes.

=cut

sub _reaper {
	(wait() == -1) ? 0 : $?;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub isapplicable {
	return 0;
}

sub start {
	my $self = shift;
	$SIG{CHLD} = \&_reaper;
	$self->{_pipe} = new IO::Pipe();
	$self->{_pipe}->reader($self->{_COMMAND});
	if (defined $self->{_on}->{after_start}) {
		$self->{_on}->{after_start}->();
	}
}

sub poll {
	my $self = shift;
}

sub stop {
	my $self = shift;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
