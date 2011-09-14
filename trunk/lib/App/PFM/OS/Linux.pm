#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Linux 0.01
#
# Name:			App::PFM::OS::Linux
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-21
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Linux

=head1 DESCRIPTION

PFM OS class for access to Linux-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Linux;

use base 'App::PFM::OS::Abstract';

use strict;

# read somewhere:
#
# 2.4 kernel: major:  8 bits, minor:  8 bits.
# 2.6 kernel: major: 12 bits, minor: 20 bits.
#
# this does not seem to be confirmed when pfm's maj/min numbers are
# compared to those listed by ls(1). What is going on?
# do we need to dig into %Config?
#
#use constant MINORBITS => 2 ** 20;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item du(string $path)

Linux-specific method for requesting file space usage info
using du(1).

=cut

sub du {
	my ($self, $file) = @_;
	my $line = $self->backtick(qw{du -sb}, $file);
	return $line;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
