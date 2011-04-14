#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::CheckUpdates 0.10
#
# Name:			App::PFM::Job::CheckUpdates
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-21
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::CheckUpdates

=head1 DESCRIPTION

PFM Job class for checking for application updates.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::CheckUpdates;

use base 'App::PFM::Job::Abstract';

use LWP::Simple;

use strict;

use constant PFM_URL => 'http://p-f-m.sourceforge.net/';

our $_pfm;

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, @args) = @_;
	$_pfm = $pfm;
	$self->SUPER::_init(@args);
}

=item _start_child()

Starts the actual job.

=cut

sub _start_child {
	my ($self) = @_;
	my $pid;
	if ($pid = fork()) {	# parent
		$self->{_pipe}->reader();
		return;
	}
	elsif (defined $pid) {	# child
		$self->{_pipe}->writer();
		$self->_check_for_updates();
		$self->{_pipe}->close();
		# don't mess up the screen when the $screen object is destroyed
		undef $_pfm->screen;
		exit 0;
	}
	# fork failed
	$self->{_pipe}->close();
}

=item _check_for_updates()

Tries to connect to the URL of the pfm project page to see if there
is a newer version. Reports this version to the application.

=cut

sub _check_for_updates {
	my $self = shift;
	my $latest_version;
	my $pfmpage = get(PFM_URL);
	($latest_version = $pfmpage) =~
		s/.*?latest version \(v?([\w.]+)\).*/$1/s;
	$self->{_pipe}->print($latest_version, "\n");
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm), App::PFM::Job::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
