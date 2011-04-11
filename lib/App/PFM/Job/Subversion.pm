#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Subversion 0.02
#
# Name:			App::PFM::Job::Subversion
# Version:		0.02
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-14
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::Subversion

=head1 DESCRIPTION

PFM Job class for Subversion commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::Subversion;

use base 'App::PFM::Job::RCS';

use strict;

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, @args) = @_;
	$self->{_COMMAND} = 'svn status %s';
	$self->SUPER::_init(@args);
}

=item _svnmaxchar()

=item _svnmax()

Determine which subversion status character should be displayed on
a directory that holds files with different status characters.
For this purpose, a relative priority is defined:

=over

B<C> (conflict) E<gt> B<M>,B<A> (modified, added) E<gt> I<other>

=back

=cut

sub _svnmaxchar {
	my ($self, $a, $b) = @_;
	# C conflict
	return 'C' if ($a eq 'C' or $b eq 'C');
	# M modified
	# A added
	return 'M' if ($a eq 'M' or $b eq 'M' or $a eq 'A' or $b eq 'A');
	# D deleted
	# I ignored
	# ? unversioned
	return $b  if ($a eq ''  or $a eq '-');
	return $a;
}

sub _svnmax {
	my ($self, $old, $new) = @_;
	my $res = $old;
	substr($res,0,1) = $self->_svnmaxchar(substr($old,0,1), substr($new,0,1));
	substr($res,1,1) = $self->_svnmaxchar(substr($old,1,1), substr($new,1,1));
	substr($res,2,1) ||= substr($new,2,1);
	return $res;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub isapplicable {
	my ($self, $path) = @_;
	return -d "$path/.svn";
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm), App::PFM::Job::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
