#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Git 0.30
#
# Name:			App::PFM::Job::Git
# Version:		0.30
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-05-19
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::Git

=head1 DESCRIPTION

PFM Job class for Git commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::Git;

use base 'App::PFM::Job::RCS';

use strict;

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
	$self->{_COMMAND} = 'git status --porcelain %s';
}

=item _gitmaxchar()

=item _gitmax()

Determine which status character should be displayed on
a directory that holds files with different status characters.
For this purpose, a relative priority is defined:

=over 2

B<U> (unmerged) E<gt> B<M>,B<C>,B<R>,B<A>,B<D> (modified,copied,renamed,added,deleted) E<gt> I<other>

=back

=cut

sub _gitmaxchar {
	my ($self, $a, $b) = @_;
	# U unmerged
	return 'U' if ($a eq 'U' or $b eq 'U');
	# M modified
	# C copied
	# R renamed
	# A added
	# D deleted
	return 'M' if ($a =~ /^[MCRAD]$/o or $b =~ /^[MCRAD]$/o);
	# ? unversioned
	#   unchanged
	return $b  if ($a eq ''  or $a eq '-' or $a eq ' ');
	return $a;
}

sub _gitmax {
	my ($self, $old, $new) = @_;
	my $res = $old;
	substr($res,0,1) = $self->_gitmaxchar(substr($old,0,1), substr($new,0,1));
	substr($res,1,1) = $self->_gitmaxchar(substr($old,1,1), substr($new,1,1));
	return $res;
}

=item _preprocess()

Split the status output in a filename- and a status-field.

=cut

# In short-format, the status of each path is shown as
# 
# XY PATH1 -> PATH2
# 
# where PATH1 is the path in the HEAD, and -> PATH2 part is shown only
# when PATH1 corresponds to a different path in the index/worktree
# (i.e. the file is renamed). The XY is a two-letter status code.
# 
# The fields (including the ->) are separated from each other by a
# single space. If a filename contains whitespace or other nonprintable
# characters, that field will be quoted in the manner of a C string
# literal: surrounded by ASCII double quote (34) characters, and with
# interior special characters backslash-escaped.
# 
# For paths with merge conflicts, X and Y show the modification states
# of each side of the merge. For paths that do not have merge conflicts,
# X shows the status of the index, and Y shows the status of the work
# tree. For untracked paths, XY are ??. Other status codes can be
# interpreted as follows:
#
#   = unmodified
# M = modified
# A = added
# D = deleted
# R = renamed
# C = copied
# U = updated but unmerged

# X          Y     Meaning
# -------------------------------------------------
#           [MD]   not updated
# M        [ MD]   updated in index
# A        [ MD]   added to index
# D         [ M]   deleted from index
# R        [ MD]   renamed in index
# C        [ MD]   copied in index
# [MARC]           index and work tree matches
# [ MARC]     M    work tree changed since index
# [ MARC]     D    deleted in work tree
# -------------------------------------------------
# D           D    unmerged, both deleted
# A           U    unmerged, added by us
# U           D    unmerged, deleted by them
# U           A    unmerged, added by them
# D           U    unmerged, deleted by us
# A           A    unmerged, both added
# U           U    unmerged, both modified
# -------------------------------------------------
# ?           ?    untracked
# -------------------------------------------------

sub _preprocess {
	my ($self, $data) = @_;
	return undef if $data !~ /^([UMCRAD\? ]{2}) (?:.+ -> )?(.+)/o;
	my $flags = $1;
	my $file  = $2;
	if ($file =~ /^"(.*)"$/) {
		$file = $1;
		$file =~ s/\\(.)/$1/;
	}
	return [ $flags, $file ];
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item isapplicable()

Checks if there is a F<.git> directory, in which case Git commands
would be applicable.

=cut

sub isapplicable {
	my ($self, $path) = @_;
	return -d "$path/.git";
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm), App::PFM::Job::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
