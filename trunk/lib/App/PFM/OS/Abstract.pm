#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Abstract 0.01
#
# Name:			App::PFM::OS::Abstract
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-21
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Abstract

=head1 DESCRIPTION

Abstract PFM OS class for defining a common interface to
platform-independent access to OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Abstract;

use base 'App::PFM::Abstract';

use Carp;

use strict;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

=item AUTOLOAD()

Starts the corresponding OS command.

=cut

sub AUTOLOAD {
	my ($self, $command, @args) = @_;
	system join ' ', map { quotemeta } ($command, @args);
}

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
