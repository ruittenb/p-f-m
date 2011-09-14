#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Sunos 0.01
#
# Name:			App::PFM::OS::Sunos
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-08-22
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Sunos

=head1 DESCRIPTION

PFM OS class for access to SunOS-specific OS commands.
This class extends App::PFM::OS::Solaris(3pm).

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Sunos;

use base 'App::PFM::OS::Solaris';

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
App::PFM::OS::Solaris(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
