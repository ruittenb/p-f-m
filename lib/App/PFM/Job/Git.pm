#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Git 0.02
#
# Name:			App::PFM::Job::Git
# Version:		0.02
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-21
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

use base 'App::PFM::Job::Abstract';

use strict;

my $_COMMAND = 'git status';

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
}

#=item _gitmaxchar()
#
#=item _gitmax()
#
#Determine which status character should be displayed on
#a directory that holds files with different status characters.
#For this purpose, a relative priority is defined:
#
#=over
#
#B<C> (conflict) E<gt> B<M> (modified) E<gt> B<U>,B<P> (updated) E<gt> I<other>
#
#=back
#
#=cut
#
#sub _gitmaxchar {
#	my ($self, $a, $b) = @_;
#	# C conflict
#	return 'C' if ($a eq 'C' or $b eq 'C');
#	# M modified
#	return 'M' if ($a eq 'M' or $b eq 'M');
#	# U updated on server
#	# P patch (like U, but sends only a diff/patch instead of the entire file).
#	return 'U' if ($a eq 'U' or $b eq 'U' or $a eq 'P' or $b eq 'P');
#	# ? unversioned
#	return $b  if ($a eq ''  or $a eq '-');
#	return $a;
#}
#
#sub _gitmax {
#	my ($self, $old, $new) = @_;
#	my $res = $old;
#	substr($res,0,1) = $self->_gitmaxchar(substr($old,0,1), substr($new,0,1));
#	return $res;
#}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub isapplicable {
	my ($self, $path) = @_;
	return -d "$path/.git";
}

sub start {
	my $self = shift;
	#TODO
}

sub poll {
	my $self = shift;
	#TODO
}

# Edit your code. To see what files have changed:
# 
# git status
# 
# Example output:
# 
# # On branch master
# # Changed but not updated:
# #   (use "git add <file>..." to update what will be committed)
# #   (use "git checkout -- <file>..." to discard changes in working directory)
# #
# #       modified:   tvnamer_exceptions.py
# #       modified:   utils.py

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Job(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
