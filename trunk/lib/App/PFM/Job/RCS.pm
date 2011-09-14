#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::RCS 0.36
#
# Name:			App::PFM::Job::RCS
# Version:		0.36
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-11-23
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::RCS

=head1 DESCRIPTION

PFM Job class for status commands of revision control systems.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::RCS;

use base 'App::PFM::Job::Abstract';

use strict;
use locale;

##########################################################################
# private subs

=item _init(hashref { $eventname1 => coderef $handler1 [, ...] },
hashref { path => string $path })

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $handlers, $options) = @_;
	$self->{_path} = $options->{path};
	$self->SUPER::_init($handlers, $options);
	return;
}

=item _start_child()

Starts the actual job.

=cut

sub _start_child {
	my ($self) = @_;
	$self->{_pipe}->reader($self->command);
	return ${$self->{_pipe}}->{io_pipe_pid};
}

##########################################################################
# constructor, getters and setters

=item command()

Getter for the command.

=cut

sub command {
	my ($self) = @_;
	return sprintf($self->{_COMMAND}, quotemeta $self->{_path});
}

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm), App::PFM::Job::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
