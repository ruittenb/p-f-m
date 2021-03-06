#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Solaris 0.05
#
# Name:			App::PFM::OS::Solaris
# Version:		0.05
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-10-03
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
use locale;

use constant {
	MINORBITS => 2 ** 18,
	IFMTCHARS => ' pc?d?b?-Cl?sDP?', # with event ports and contiguous files
};

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item du(string $path)

Returns file space usage info using du(1).

=cut

sub du {
	my ($self, $file) = @_;
	my $line = $self->backtick(qw{du -s}, $file);
	$line =~ /(\d+)/;
	$line = 1024 * $1;
	return $line;
}

=item mode2str(char $sugid, char $user, char $group, char $others)

Determines the symbolic representation of permission digits.
Setgid files with the group execution bit off are represented as 'l'
in position six (I<e.g.> 'rw-r-lr--')

=cut

sub mode2str {
	my ($self, @digits) = @_;
	my $strmode = $self->SUPER::mode2str(@digits);
	substr($strmode,5,1) =~ s/S/l/;
	return $strmode;
}

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
	return $self->system(qw{setfacl -f}, $aclfilename, $path);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
