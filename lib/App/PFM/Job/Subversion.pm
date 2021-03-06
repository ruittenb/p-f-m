#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Subversion 0.40
#
# Name:			App::PFM::Job::Subversion
# Version:		0.40
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2013-10-17
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
use locale;

##########################################################################
# private subs

=item I<< _init(hashref { $eventname1 => coderef $handler1 [, ...] }, >>
I<< hashref { path => string $path, noignore => bool $noignore }) >>

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $handlers, $options) = @_;
	$self->{_COMMAND} = $options->{noignore}
		? 'svn status --no-ignore %s'
		: 'svn status %s';
	$self->SUPER::_init($handlers, $options);
	return;
}

=item I<_preprocess(string $data)>

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

=item I<_svnmaxchar(char $a, char $b)>

Sorting routine for subversion status characters.

=item I<rcsmax(string $old, string $new)>

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

=item I<isapplicable(string $path [, string $entry ] )>

Checks if there is a F<.svn> directory in this or any parent directory,
in which case Subversion commands would be applicable.

Known problems: if there is an unversioned directory under a svnroot,
pressing <F11> will trigger an svn warning.

=cut

sub isapplicable {
	my ($self, $path, $entry) = @_;
	if (-d "$path/$entry") {
		# Directory file
		return 0 if $entry eq '.svn';
		return 1 if -d "$path/$entry/.svn";
	}
    while ($path and $path =~ m!/! and $path !~ m{/\.svn$}) {
        if (-d "$path/.svn") {
            return $path;
        }
        $path =~ s{/[^/]*$}{};
    }
	return 0;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm), App::PFM::Job::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
