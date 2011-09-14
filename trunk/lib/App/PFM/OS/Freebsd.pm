#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Freebsd 0.01
#
# Name:			App::PFM::OS::Freebsd
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-25
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Freebsd

=head1 DESCRIPTION

PFM OS class for access to FreeBSD-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Freebsd;

use base 'App::PFM::OS::Abstract';

use strict;

#use constant MINORBITS => 2 ** n;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item aclget(string $path)

Gets a file's Access Control List.

=cut

sub aclget {
	my ($self, $path) = @_;
	return $self->backtick('getfacl', $path);
}

=item aclput(string $path, string $aclfilename)

Sets a file's Access Control List from the data in a temporary file.

=cut

sub aclput {
	my ($self, $path, $aclfilename) = @_;
	$self->system(qw{setfacl -M}, $aclfilename, $path);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
