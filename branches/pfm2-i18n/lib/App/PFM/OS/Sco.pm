#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Sco 0.01
#
# Name:			App::PFM::OS::Sco
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-08-22
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Sco

=head1 DESCRIPTION

PFM OS class for access to SCO-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Sco;

use base 'App::PFM::OS::Abstract';

use strict;
use locale;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item df(string $path)

SCO-specific method for requesting filesystem info.

=cut

sub df {
	my ($self, $file) = @_;
	my @lines = $self->backtick('dfspace', $file);
	return $self->_df_unwrap(@lines);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
