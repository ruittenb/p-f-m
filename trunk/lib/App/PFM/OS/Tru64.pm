#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Tru64 0.02
#
# Name:			App::PFM::OS::Tru64
# Version:		0.02
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-08-26
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
use locale;

use constant MINORBITS => 2 ** 20;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item acledit(string $path)

Tru64-specific method for editing Access Control Lists.

=cut

sub acledit {
	my ($self, $path) = @_;
	local $ENV{EDITOR} = $self->{_pfm}->config->{fg_editor};
	return $self->system(qw{setacl -E}, $path);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
