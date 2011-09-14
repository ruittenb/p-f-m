#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Solaris 0.01
#
# Name:			App::PFM::OS::Solaris
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-08-22
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Solaris

=head1 DESCRIPTION

PFM OS class for access to Solaris-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Solaris;

use base 'App::PFM::OS::Abstract';

use strict;

use constant MINORBITS => 2 ** 18;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item du(string $path)

Solaris-specific method for requesting file space usage info
using du(1).

=cut

sub du {
	my ($self, $file) = @_;
	my $line = $self->backtick(qw{du -s}, $file);
	$line =~ /(\d+)/;
	$line = 1024 * $1;
	return $line;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
