#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Tru64 0.01
#
# Name:			App::PFM::OS::Tru64
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-08-22
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Tru64

=head1 DESCRIPTION

PFM OS class for access to Tru64-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Tru64;

use base 'App::PFM::OS::Abstract';

use strict;

use constant MINORBITS => 2 ** 20;

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
