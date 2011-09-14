#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::CheckUpdates 0.16
#
# Name:			App::PFM::Job::CheckUpdates
# Version:		0.16
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2011-09-08
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

use strict;
use locale;

use constant PFM_URL => 'http://p-f-m.sourceforge.net/';

##########################################################################
# private subs

=item _init(hashref { $eventname1 => coderef $handler1 [, ...] })

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, @args) = @_;
	$self->{_COMMAND} = q!
		perl -MLWP::UserAgent -e'
			$ua = new LWP::UserAgent(timeout => 5);
			$pfmpage = $ua->get("%s");
			if ($pfmpage->is_success) {
				$pfmpagedata = $pfmpage->content;
				if ($pfmpagedata =~ /latest version/) {
					($latest_version = $pfmpagedata) =~
						s/.*?latest version \(v?([\w.]+)\).*/$1/s;
					print $latest_version, "\n";
				}
			}
		'
	!;
	$self->SUPER::_init(@args);
	return;
}

=item _start_child()

Starts the actual job.

=cut

sub _start_child {
	my ($self) = @_;
	# this doesn't work: the exiting of the child process
	# messes up the screen settings when the child process
	# goes through its END block
#	my $pid;
#	if ($pid = fork()) {	# parent
#		$self->{_pipe}->reader();
#		return;
#	}
#	elsif (defined $pid) {	# child
#		$self->{_pipe}->writer();
#		$self->_check_for_updates();
#		$self->{_pipe}->close();
#		# don't mess up the screen when the $screen object is destroyed
#		undef $_pfm->screen;
#		exit 0;
#	}
#	# fork failed
#	$self->{_pipe}->close();
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
	return sprintf($self->{_COMMAND}, PFM_URL);
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
