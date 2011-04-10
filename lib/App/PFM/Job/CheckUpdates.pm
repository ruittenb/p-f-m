#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::CheckUpdates 0.01
#
# Name:			App::PFM::Job::CheckUpdates
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
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

my $_pfm;

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
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
	if ($latest_version gt $self->{VERSION}) {
		$_pfm->latest_version(
			"There is a newer version ($latest_version) available at " .
			PFM_URL . "\n");
	}
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub start {
	my $self = shift;
	#TODO
}

sub poll {
	my $self = shift;
	#TODO
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
