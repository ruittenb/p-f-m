#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Directory 2010-03-27 v0.01
#
# Name:			PFM::Directory.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Directory class, containing the directory
#				contents and the actions that can be performed on them.
#

##########################################################################
# declarations

package PFM::Directory;

use base 'PFM::Abstract';

use PFM::Util;

my ($_pfm, $_path);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $path)	= shift;
	my %empty_hash			= ();
	$self->{selected_nr_of}	= %empty_hash;
	$self->{total_nr_of}	= %empty_hash;
	$_pfm					= $pfm;
	$_path					= $path;
}

##########################################################################
# constructor, getters and setters

=item path()

Getter/setter for the current directory path.
Setting the current directory in this way is identical to calling
PFM::Directory::chdir().

=cut

sub path {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->chdir($value);
	}
	return $_path;
}
##########################################################################
# public subs

sub chdir {
	my ($self, $goal) = @_;
	my $result;
	if ($goal eq '') {
		$goal = $ENV{HOME};
	} elsif (-d $goal and $goal !~ m!^/!) {
		$goal = "$_path/$goal";
	} elsif ($goal !~ m!/!) {
		foreach (split /:/, $ENV{CDPATH}) {
			if (-d "$_/$goal") {
				$goal = "$_/$goal";
				$_pfm->screen->at(0,0)->clreol();
				$_pfm->screen->display_error("Using $goal");
				$_pfm->screen->at(0,0);
				last;
			}
		}
	}
	#TODO canonicalize_path
	$goal = canonicalize_path($goal);
	if ($result = chdir $goal and $goal ne $_path) {
		#TODO oldcurr
		$oldcurrentdir = $_path;
		$_path = $goal;
		#TODO chdirautocmd
		system("$chdirautocmd") if length($chdirautocmd);
	}
	return $result;
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
