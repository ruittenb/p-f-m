#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Job::Cvs 0.01
#
# Name:			PFM::Job::Cvs.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
#

##########################################################################

=pod

=head1 NAME

PFM::Job::Cvs

=head1 DESCRIPTION

PFM Job class for CVS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Job::Cvs;

use base 'PFM::Abstract';

my $_command = 'cvs -n -q update -l';

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub start {
	my $self = shift;
	#TODO
}

sub poll {
	my $self = shift;
	#TODO
}

# [23:43] Maurice Makaay: cvs -n -q update -l
# [23:43] Maurice Makaay: Dat slaat subdirs over.
# [23:43] Maurice Makaay: RCS file: /vol/cvs/kavnet/kavnetserver.c,v
# [23:43] Maurice Makaay: retrieving revision 1.11
# [23:43] Maurice Makaay: retrieving revision 1.13
# [23:43] Maurice Makaay: Merging differences between 1.11 and 1.13 into kavnetserver.c
# [23:43] Maurice Makaay: M kavnetserver.c
# [23:41] Maurice Makaay: M libkavnetclient.h
# [23:41] Maurice Makaay: M perl/test.pl
# [23:41] Maurice Makaay: U kavnetserver.c
# [23:35] Maurice Makaay: ? md5.h
# [23:35] Maurice Makaay: /^([PMCU\?]) (\S.)/

# ? unversioned
# U updated on server
# P patch (like U, but sends only a diff/patch instead of the entire file).
# M modified
# C conflict

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
