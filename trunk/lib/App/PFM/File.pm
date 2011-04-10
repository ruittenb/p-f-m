#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::File 0.12
#
# Name:			App::PFM::File.pm
# Version:		0.12
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-18
#

##########################################################################

=pod

=head1 NAME

App::PFM::File

=head1 DESCRIPTION

PFM File class, containing the bookkeeping for each file in the directory.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::File;

use base 'App::PFM::Abstract';

use App::PFM::Util;

use POSIX qw(strftime);

use strict;

use constant {
	MAJORMINORSEPARATOR => ',',
};

my %RDEVTOMAJOR = (
	default	=> 2 **  8,
	aix		=> 2 ** 16,
	irix	=> 2 ** 18,
	solaris	=> 2 ** 18,
	sunos	=> 2 ** 18,
	dec_osf	=> 2 ** 20,
	tru64	=> 2 ** 20, # correct value for $OSNAME on Tru64?
	hpux	=> 2 ** 24,
);

my $RDEVTOMAJOR = $RDEVTOMAJOR{$^O} || $RDEVTOMAJOR{default};

my @SYMBOLIC_MODES = qw(--- --x -w- -wx r-- r-x rw- rwx);

our ($_pfm);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $path, $parent, $white, $mark) = @_;
	$self->{_parent} = $parent;
	if (defined $path) {
		$self->stat_entry($path, $white, $mark);
	}
	# the constructor returns $self for us.
}

=item _clone()

Performs one phase of the cloning process by cloning an existing
App::PFM::File instance.

=cut

sub _clone {
	my ($self, $original, @args) = @_;
	# TODO
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item mode2str()

Converts a numeric file mode (permission bits) to a symbolic one
(I<e.g.> C<drwxr-x--->).

Possible inode types are:

 0000                000000  unused inode
 1000  S_IFIFO   p|  010000  fifo (named pipe)
 2000  S_IFCHR   c   020000  character special
 3000  S_IFMPC       030000  multiplexed character special (V7)
 4000  S_IFDIR   d/  040000  directory
 5000  S_IFNAM       050000  XENIX named special file with two subtypes,
                             distinguished by st_rdev values 1,2:
 0001  S_INSEM   s   000001    semaphore
 0002  S_INSHD   m   000002    shared data
 6000  S_IFBLK   b   060000  block special
 7000  S_IFMPB       070000  multiplexed block special (V7)
 8000  S_IFREG   -   100000  regular
 9000  S_IFNWK   n   110000  network special (HP-UX)
 a000  S_IFLNK   l@  120000  symbolic link
 b000  S_IFSHAD      130000  Solaris ACL shadow inode,
                             not seen by userspace
 c000  S_IFSOCK  s=  140000  socket
 d000  S_IFDOOR  D>  150000  Solaris door
 e000  S_IFWHT   w%  160000  BSD whiteout

=cut

sub mode2str {
	my ($self, $nummode) = @_;
	my $strmode;
	my $octmode = sprintf("%lo", $nummode);
	$octmode	=~ /(\d\d?)(\d)(\d)(\d)(\d)$/;
	$strmode	= substr('-pc?d?b?-nl?sDw?', oct($1) & 017, 1)
				. $SYMBOLIC_MODES[$3] . $SYMBOLIC_MODES[$4] . $SYMBOLIC_MODES[$5];
	#
	if ($2 & 4) { substr($strmode,3,1) =~ tr/-x/Ss/ }
	if ($2 & 2) {
		if ($_pfm->config->{showlockchar} eq 'l') {
			substr($strmode,6,1) =~ tr/-x/ls/;
		} else {
			substr($strmode,6,1) =~ tr/-x/Ss/;
		}
	}
	if ($2 & 1) { substr($strmode,9,1) =~ tr/-x/Tt/ }
	return $strmode;
}

=item stamp2str()

Formats a timestamp for printing.

=cut

sub stamp2str {
	my ($self, $time) = @_;
	return strftime($_pfm->config->{timestampformat}, localtime $time);
}

=item stat_entry()

Initializes the current file information by performing a stat() on it.

The $iswhite argument is provided because the directory already has an
idea if this file is a whiteout. Allowed values: 'w', '?', ''.

The $selected_flag argument is used to have the caller specify whether
the 'selected' field of the file info should be cleared (when reading
a new directory) or kept intact (when re-statting).

=cut

sub stat_entry {
	my ($self, $entry, $iswhite, $selected_flag) = @_;
	my ($ptr, $name_too_long, $target, @white_entries, $whitecommand);
	my %filetypeflags = %{$_pfm->config->{filetypeflags}};
	my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size,
		$atime, $mtime, $ctime, $blksize, $blocks) = lstat $entry;

	if (!defined $mode) {
		$whitecommand = $_pfm->commandhandler->whitecommand;
		if (defined $whitecommand) {
			if ($iswhite eq '?') {
				@white_entries =
					map { chop; $_ } `$whitecommand \Q$self->{_parent}\E`;
			}
			if ($iswhite eq 'w' or grep /$entry/, @white_entries) {
				$mode = 0160000;
#				$entry->{type} = 'w';
#				substr($entry->{mode}, 0, 1) = 'w';
			}
		}
	}
	$ptr = {
		name		=> $entry,
		uid			=> find_uid($uid),
		gid			=> find_gid($gid),
		mode		=> $self->mode2str($mode),
		device		=> $device,
		inode		=> $inode,
		nlink		=> $nlink,
		rdev		=> $rdev,
		selected	=> $selected_flag,
		atime		=> $atime,
		mtime		=> $mtime,
		ctime		=> $ctime,
		grand_power	=> ' ',
		size		=> $size,
		blocks		=> $blocks,
		blksize		=> $blksize,
		svn			=> '-',
		atimestring => $self->stamp2str($atime),
		mtimestring => $self->stamp2str($mtime),
		ctimestring => $self->stamp2str($ctime),
	};
	@{$self}{keys %$ptr} = values %$ptr;
	@{$self}{qw(size_num size_power)} =
		fit2limit($size, $_pfm->screen->listing->maxfilesizelength);
	$self->{type} = substr($self->{mode}, 0, 1);
	if ($self->{type} eq 'l') {
		$self->{target}  = readlink($self->{name});
		$self->{display} = $entry . $filetypeflags{'l'}
						. ' -> ' . $self->{target};
	} elsif ($self->{type} eq '-' and $self->{mode} =~ /.[xst]/) {
		$self->{display} = $entry . $filetypeflags{'x'};
	} elsif ($self->{type} =~ /[bc]/) {
		$self->{size_num} = sprintf("%d", $rdev / $RDEVTOMAJOR) .
							MAJORMINORSEPARATOR . ($rdev % $RDEVTOMAJOR);
		$self->{display} = $entry . $filetypeflags{$self->{type}};
	} else {
		$self->{display} = $entry . $filetypeflags{$self->{type}};
	}
	$self->{name_too_long} =
		length($self->{display}) > $_pfm->screen->listing->maxfilenamelength-1
			? $_pfm->screen->listing->NAMETOOLONGCHAR : ' ';
	return $self;
}

=item format()

Format the fields according to the current screen size.

=cut

sub format {
	my ($self) = @_;

}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4: