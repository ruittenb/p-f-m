#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Beos 0.01
#
# Name:			App::PFM::OS::Beos
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-10-16
# Date:			2010-10-16
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Beos

=head1 DESCRIPTION

PFM OS class for access to Beos-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Beos;

use base 'App::PFM::OS::Haiku';

use strict;
use locale;

#use constant MINORBITS => 2 ** 16;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
