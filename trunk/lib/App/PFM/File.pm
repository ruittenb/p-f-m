#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::File 0.42
#
# Name:			App::PFM::File
# Version:		0.42
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-11-23
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

use App::PFM::Util qw(find_uid find_gid isorphan fit2limit);

use POSIX qw(strftime);

use strict;
use locale;

use constant MAJORMINORTEMPLATE => '%d,%d';
use constant LOSTMSG            => ''; # was ' (lost)'

our ($_pfm);

##########################################################################
# private subs

=item _init(hashref { parent => string $parent_dir, entry => string
$filename, white => char $iswhite, mark => char $marked_flag } )

Initializes new instances. Called from the constructor.
If I<entry> is defined, the method stat_entry() is called automatically.

=cut

sub _init {
	my ($self, %o) = @_; # ($entry, $parent, $white, $mark)
	if (defined $o{parent}) {
		$self->{_parent} = $o{parent};
	}
	if (defined $o{entry}) {
		$self->stat_entry($o{entry}, $o{white}, $o{mark});
	}
	return;
}

=item _decidecolor()

Decides which color should be used on a particular file.

=cut

sub _decidecolor {
	my ($self) = @_;
	my %dircolors  = %{$_pfm->config->{dircolors}{$_pfm->screen->color_mode}};
	# by file type
	$self->{type}  eq 'w'				and return $dircolors{wh};
	$self->{nlink} ==  0 				and return $dircolors{lo};
	# by permissions
	$self->{mode}  =~ /^d.......w[tT]/o	and return $dircolors{tw};
	$self->{mode}  =~ /^d........[tT]/o	and return $dircolors{st};
	$self->{mode}  =~ /^d.......w./o	and return $dircolors{ow};
	$self->{mode}  =~ /^-..s/o			and return $dircolors{su};
	$self->{mode}  =~ /^-.....s/o		and return $dircolors{sg};
	# by file type
	$self->{type}  eq 'd'				and return $dircolors{di};
	$self->{type}  eq 'l'				and return $dircolors{
										isorphan($self->{name}) ?'or':'ln' };
	$self->{type}  eq 'b'				and return $dircolors{bd};
	$self->{type}  eq 'c'				and return $dircolors{cd};
	$self->{type}  eq 'p'				and return $dircolors{pi};
	$self->{type}  eq 's'				and return $dircolors{so};
	$self->{type}  eq 'D'				and return $dircolors{'do'};
	$self->{type}  eq 'n'				and return $dircolors{nt};
	$self->{type}  eq 'P'				and return $dircolors{ep};
	# by filename
	exists
		$dircolors{"'$self->{name}'"}	and return $dircolors{
											"'$self->{name}'"};
	# by nr. of hard links
	$self->{type}  eq '-'			&&
		$self->{nlink} > 1			&&
		defined $dircolors{hl}			and return $dircolors{hl};
	# by permissions
	$self->{mode}  =~ /[xst]/o			and return $dircolors{ex};
	# by extension
	$self->{name}  =~ /(\.\w+)$/o	&&
		defined ($dircolors{$1})		and return $dircolors{$1};
	# regular file
	$self->{type}  eq '-'				and return $dircolors{fi};
	return;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item mode2str(int $st_mode)

Converts a numeric I<st_mode> field (file type/permission bits) to a
symbolic one (I<e.g.> C<drwxr-x--->).
Uses I<App::PFM::OS::*::ifmt2str>() to determine the inode type.
Uses I<App::PFM::OS::*::mode2str>() to determine the symbolic
representation of permissions.

=cut

sub mode2str {
	my ($self, $nummode) = @_;
	my $strmode;
	my $octmode = sprintf("%lo", $nummode);
	$octmode	=~ /(\d\d?)(\d)(\d)(\d)(\d)$/;
	$strmode	= $_pfm->os->ifmt2str($1)
				. $_pfm->os->mode2str($2, $3, $4, $5);
	return $strmode;
}

=item stamp2str(int $timestamp)

Formats a timestamp for printing.

=cut

sub stamp2str {
	my ($self, $time) = @_;
	$time ||= 0;
	return strftime($_pfm->config->{timestampformat}, localtime $time);
}

=item stat_entry(string $entry, char $iswhite, char $marked_flag)

Initializes the current file information by performing a stat() on it.

The I<iswhite> argument indicates if the directory already has
an idea if this file is a whiteout. Allowed values: 'w', '?', ''.

The I<marked_flag> argument is used to have the caller specify whether
the 'mark' field of the file info should be cleared (when reading
a new directory) or kept intact (when re-statting).

=cut

sub stat_entry {
	my ($self, $entry, $iswhite, $marked_flag) = @_;
	my ($ptr, $name_too_long, $target, @white_entries);
	my %filetypeflags = %{$_pfm->config->{filetypeflags}};
	my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size,
		$atime, $mtime, $ctime, $blksize, $blocks) =
			lstat "$self->{_parent}/$entry";

	if (!defined $mode) {
		if ($iswhite eq '?') {
			@white_entries = $_pfm->os->listwhite($self->{_parent});
			chop @white_entries;
		}
		if ($iswhite eq 'w' or grep { $_ eq $entry } @white_entries) {
			$mode = oct(160000);
		}
	}
	$ptr = {
		name		=> $entry,
		uid			=> $uid,
		gid			=> $gid,
		user		=> find_uid($uid),
		group		=> find_gid($gid),
		mode_num	=> sprintf('%lo', $mode),
		mode		=> $self->mode2str($mode),
		device		=> $device,
		inode		=> $inode,
		nlink		=> $nlink,
		rdev		=> $rdev,
		mark		=> $marked_flag,
		atime		=> $atime,
		mtime		=> $mtime,
		ctime		=> $ctime,
		grand		=> '',
		grand_power	=> ' ',
		size		=> $size,
		blocks		=> $blocks,
		blksize		=> $blksize,
		rcs			=> '-',
		gap			=> '',
	};
	@{$self}{keys %$ptr} = values %$ptr;

	$self->{type} = substr($self->{mode}, 0, 1);
	$self->{display} = $entry . $self->filetypeflag();
	if ($self->{type} eq 'l') {
		$self->{target}  = readlink("$self->{_parent}/$entry");
		$self->{display} = $entry . $filetypeflags{'l'}
						. ' -> ' . $self->{target};
	} elsif ($self->{type} =~ /^[bc]/o) {
		$self->{size_num} =
			sprintf(MAJORMINORTEMPLATE, $_pfm->os->rdev_to_major_minor($rdev));
#	} elsif ($self->{type} eq ' ' and $self->{nlink} == 0) {
#		# or do this using filetypeflags?
#		$self->{display} .= LOSTMSG;
	}
	$self->format();
	return $self;
}

=item filetypeflag()

Returns the correct flag for this file type.

=cut

sub filetypeflag {
	my ($self) = @_;
	my $filetypeflags = $_pfm->config->{filetypeflags};
	if ($self->{type} eq '-' and $self->{mode} =~ /.[xst]/) {
		return $filetypeflags->{'x'};
	} else {
		return $filetypeflags->{$self->{type}} || '';
	}
}

=item format()

Formats the fields according to the current screen size.

=cut

sub format {
	my ($self)  = @_;
	my $listing = $_pfm->screen->listing;

	unless ($self->{type} =~ /[bc]/) {
		@{$self}{qw(size_num size_power)} =
			fit2limit($self->{size}, $listing->maxfilesizelength);
		@{$self}{qw(grand_num grand_power)} =
			fit2limit($self->{grand}, $listing->maxgrandtotallength);
	}

	$self->{atimestring}   = $self->stamp2str($self->{atime});
	$self->{mtimestring}   = $self->stamp2str($self->{mtime});
	$self->{ctimestring}   = $self->stamp2str($self->{ctime});
	$self->{gap}           = ' ' x $listing->{_gaplength};
	$self->{name_too_long} =
		length($self->{display}) > $listing->maxfilenamelength-1
			? $listing->NAMETOOLONGCHAR : ' ';
	$self->{color} = $self->_decidecolor();
	return;
}

=item apply(coderef $do_this, string $special_mode, array @args)

Applies the supplied function to the current file.
The function will be called as C<< $do_this->($self, @args) >>
where I<self> is the current File object.

The current file will be temporarily unregistered from the current
directory for the duration of do_this().

If I<special_mode> does not equal 'norestat', the file is re-stat()
after executing do_this().

=cut

sub apply {
	my ($self, $do_this, $special_mode, @args) = @_;
	my $state     = $_pfm->state;
	my $directory = $state->directory;
	my ($to_mark, $res);
	$directory->unregister($self);
	$res = $do_this->($self, @args);
	if ($state->{multiple_mode}) {
		$to_mark = $directory->M_OLDMARK;
	} else {
		$to_mark = $self->{mark};
	}
	if ($special_mode ne 'norestat') {
		$self->stat_entry($self->{name}, '?', $to_mark);
	} else {
		$self->{mark} = $to_mark;
	}
	$directory->register($self);
	return $res;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
