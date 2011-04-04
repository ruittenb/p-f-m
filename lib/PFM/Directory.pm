#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Directory 0.01
#
# Name:			PFM::Directory.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
#

##########################################################################

=pod

=head1 NAME

PFM::Directory

=head1 DESCRIPTION

PFM Directory class, containing the directory contents and the
actions that can be performed on them.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Directory;

use base 'PFM::Abstract';

use PFM::Util;

my ($_pfm, $_path, @_dircontents, @_showncontents);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $path)	= shift;
	$self->{selected_nr_of}	= {};
	$self->{total_nr_of}	= {};
	$_pfm					= $pfm;
	$_path					= $path;
}

##########################################################################
# constructor, getters and setters

=item path()

Getter/setter for the current directory path.
Setting the current directory in this way is identical to calling
PFM::Directory::chdir(), and will return the success status.

=cut

sub path {
	my ($self, $target) = @_;
	if (defined $target) {
		return $self->chdir($target);
	}
	return $_path;
}

=item dircontents()

Getter/setter for the @_dircontents variable, which contains the
complete array of files in the directory.

=cut

sub dircontents {
	my ($self, @value) = @_;
	@_dircontents = @value if defined @value;
	return @_dircontents;
}

=item showncontents()

Getter/setter for the @_showncontents variable, which contains an
array of the files shown on-screen.

=cut

sub showncontents {
	my ($self, @value) = @_;
	@_showncontents = @value if defined @value;
	return @_showncontents;
}

##########################################################################
# public subs

sub chdir {
	my ($self, $target) = @_;
	my $result;
	my $screen = $_pfm->screen;
	if ($target eq '') {
		$target = $ENV{HOME};
	} elsif (-d $target and $target !~ m!^/!) {
		$target = "$_path/$target";
	} elsif ($target !~ m!/!) {
		foreach (split /:/, $ENV{CDPATH}) {
			if (-d "$_/$target") {
				$target = "$_/$target";
				$screen->at(0,0)->clreol();
				$screen->display_error("Using $target");
				$screen->at(0,0);
				last;
			}
		}
	}
	#TODO canonicalize_path
	$target = canonicalize_path($target);
	if ($result = chdir $target and $target ne $_path) {
		#TODO define constants for oldcwd
		$_pfm->state(2) = $self;
		$_path = $target;
		$chdirautocmd = $_pfm->config->chdirautocmd;
		system("$chdirautocmd") if length($chdirautocmd);
		$screen->set_deferred_refresh($screen->R_CHDIR);
	}
	return $result;
}

sub init_dircount {
	$self->{total_nr_of} = { d=>0, l=>0, '-'=>0, c=>0, b=>0, D=>0,
							 p=>0, 's'=>0, n=>0, w=>0, bytes => 0 };
	%{$self->{selected_nr_of}} = %{$self->{total_nr_of}};
}

#TODO
sub countdircontents {
	$self->init_dircount();
	foreach my $i (0..$#_) {
		$total_nr_of   {$_[$i]{type}}++;
		$selected_nr_of{$_[$i]{type}}++ if ($_[$i]{selected} eq '*');
	}
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
