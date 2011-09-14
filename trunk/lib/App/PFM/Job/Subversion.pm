#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Subversion 0.30
#
# Name:			App::PFM::Job::Subversion
# Version:		0.30
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-05-19
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

=item _preprocess()

Split the status output in a filename- and a status-field.

=cut

# First column:
#
# A  File to be added
# C  Conflicting changes
# D  File to be deleted
# G  File to be merged with updates from server
# M  File has been modified
# R  File to be replaced
# G  File to be merged
# X  Resource is external to repository (svn:externals)
# ?  File/directory not under version control
# !  File/directory missing
# ~  Versioned item obstructed by some item of a different kind.
#
# Second column: Modification of properties
#
#' ' no modifications. Working copy is up to date.
# C  Conflicted
# M  Modified
# *  Local file different than repository. A newer revision exists on the
#    server. Update will result in merge or possible conflict.
# 
# Third column: Locks
#
#' ' not locked
# L  locked
# S  switched to a branch


sub _preprocess {
	my ($self, $data) = @_;
	$data =~ /^(.....)\s+(.*)/;
	return [ $1, $2 ];
}

=item _svnmaxchar()

=item rcsmax()

Determines which subversion status character should be displayed on
a directory that holds files with different status characters.
For this purpose, a relative priority is defined:

=over 2

B<C> (conflict) E<gt> B<M>,B<A>,B<D> (modified, added, deleted) E<gt> I<other>

=back

=cut

sub _svnmaxchar {
	my ($self, $a, $b) = @_;
	# C conflict
	return 'C' if ($a eq 'C' or $b eq 'C');
	# M modified
	# A added
	# D deleted
	return 'M' if ($a =~ /^[MAD]$/o or $b =~ /^[MAD]$/o);
	# I ignored
	# ? unversioned
	return $b  if ($a eq ''  or $a eq '-');
	return $a;
}

sub rcsmax {
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

=item isapplicable()

Checks if there is a F<.svn> directory, in which case Subversion commands
would be applicable.

=cut

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
