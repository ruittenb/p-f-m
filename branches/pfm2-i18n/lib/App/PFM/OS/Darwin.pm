#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Darwin 0.01
#
# Name:			App::PFM::OS::Darwin
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-25
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Darwin

=head1 DESCRIPTION

PFM OS class for access to Darwin-specific OS commands.
This class extends App::PFM::OS::Macosx.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Darwin;

use base 'App::PFM::OS::Macosx';

use strict;
use locale;

#use constant MINORBITS => 2 ** n;

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
