#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::RCS 0.01
#
# Name:			App::PFM::Job::RCS
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::RCS

=head1 DESCRIPTION

PFM Job class for version control status commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::RCS;

use base 'App::PFM::Job::Abstract';

use strict;

##########################################################################
# private subs

=item _init()

Initialize the 'running' flag.

=cut

sub _init() {
	my ($self) = @_;
	$self->{running} = 0;
	$self->SUPER::_init();
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub isapplicable {
	# implemented by subclasses
	return 0;
}

sub start {
	# start $self->{_COMMAND}
	#$_screen->set_deferred_refresh(R_HEADINGS);
}

sub poll {
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
