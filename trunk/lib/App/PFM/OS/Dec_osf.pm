#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Dec_osf 0.01
#
# Name:			App::PFM::OS::Dec_osf
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-08-22
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Dec_osf

=head1 DESCRIPTION

PFM OS class for access to OSF1-specific OS commands.
This class extends App::PFM::OS::Tru64(3pm).

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Dec_osf;

use base 'App::PFM::OS::Tru64';

use strict;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm),
App::PFM::OS::Tru64(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
