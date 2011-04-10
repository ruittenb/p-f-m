#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Bazaar 0.01
#
# Name:			App::PFM::Job::Bazaar.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-14
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::Bazaar

=head1 DESCRIPTION

PFM Job class for Bazaar commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::Bazaar;

use base 'App::PFM::Job::Abstract';

use strict;

my $_COMMAND = 'bzr status -S';

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
}

# ruitten@visnet:/home/ruitten/Desktop/working/alice$ bzr status -S
# ?   backup.bzr/
#  M  static/media/index.php

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub isapplicable {
	my ($self, $path) = @_;
	while ($path) {
		if (-d "$path/.bzr") {
			return 1;
		}
		$path =~ s{/[^/]*$}{};
	}
	return 0;
}

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
