#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Abstract 0.14
#
# Name:			App::PFM::OS::Abstract
# Version:		0.14
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-09-18
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Abstract

=head1 DESCRIPTION

Abstract PFM OS class for defining a common interface to
platform-independent access to OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Abstract;

use base 'App::PFM::Abstract';

use File::Temp;
use File::Stat::Bits;

use strict;
use locale;

use constant {
	MINORBITS => 2 ** 8,
	IFMTCHARS => ' pc?d?b?-Cl?sDw?', # with whiteouts and contiguous files
};

our ($AUTOLOAD);

##########################################################################
# private subs

=item _init(App::PFM::Config $config)

Initializes new instances by storing the config object and
initializing some member variables.
Called from the constructor.

=cut

sub _init {
	my ($self, $config) = @_;
	$self->{_config}  = $config;
    $self->{_aclfile} = undef;
	$self->_init_white_commands();
}

=item _init_white_commands()

Finds out which commands should be used for listing and deleting whiteouts.
Called from _init().

=cut

sub _init_white_commands {
	my ($self) = @_;
	my $listwhite_cmd = '';
	my @unwo_cmd  = ();
	foreach (split /:/, $ENV{PATH}) {
		if (!$listwhite_cmd) {
			if (-f "$_/listwhite") {
				$listwhite_cmd = 'listwhite';
			} elsif (-f "$_/lsw") {
				$listwhite_cmd = 'lsw';
			}
		}
		if (!@unwo_cmd) {
			if (-f "$_/unwhiteout") {
				@unwo_cmd = qw(unwhiteout);
			} elsif (-f "$_/unwo") {
				@unwo_cmd = qw(unwo);
			}
		}
	}
	unless (@unwo_cmd) {
		@unwo_cmd = qw(rm -W);
	}
	$self->{_listwhite_cmd} = $listwhite_cmd;
	$self->{_unwo_cmd}  = [ @unwo_cmd ];
}

=item _df_unwrap(array @lines)

Filesystem info as output by df(1) may wrap onto a second line.
Concatenate those lines.

=cut

sub _df_unwrap {
	my ($self, @lines) = @_;
	my $combined;
	foreach (reverse 1..$#lines) {
		# if this line starts with whitespace, join it with
		# the previous one.
		if ($lines[$_] =~ /^\s/) {
			$combined = $lines[$_-1] . $lines[$_];
			splice(@lines, $_-1, 2, $combined);
		}
	}
	return @lines;
}

##########################################################################
# constructor, getters and setters

=item AUTOLOAD( [ args... ] )

Starts the corresponding OS command.

=cut

sub AUTOLOAD {
	my ($self, @args) = @_;
	my $command = $AUTOLOAD;
	$command =~ s/.*:://;
	return if $command eq 'DESTROY';
	return $self->system($command, @args);
}

=item listwhite_command()

Getter for the command for listing whiteouts.

=cut

sub listwhite_command {
	my ($self) = @_;
	return $self->{_listwhite_cmd};
}

##########################################################################
# public helper functions

=item rdev_to_major_minor(int $rdev)

Splits the I<st_rdev> field of a I<stat> structure (see stat(2)).
Returns an array of two values: the major and minor number.

=cut

sub rdev_to_major_minor {
	my ($self, $rdev) = @_;
	my ($maj, $min) = dev_split($rdev);
	# if not lucky, we'll try it ourselves
	if (!defined $maj) {
		$maj = sprintf("%d", $rdev / $self->MINORBITS);
	}
	if (!defined $min) {
		$min = $rdev % $self->MINORBITS;
	}
	return ($maj, $min);
}

=item ifmt2str(int $mode)

Translates the S_IFMT bits of the mode field of a stat(2) structure
to a character indicating the inode type.

Possible inode types are:

 0000                000000  unused inode
 1000  S_IFIFO   p|  010000  fifo (named pipe)
 2000  S_IFCHR   c   020000  character special
 3000  S_IFMPC       030000  multiplexed character special (V7)
 4000  S_IFDIR   d/  040000  directory
 5000  S_IFNAM       050000  named special file (XENIX) with two sub-
                             types, distinguished by st_rdev values 1,2:
 0001  S_INSEM   s   000001    semaphore
 0002  S_INSHD   m   000002    shared data
 6000  S_IFBLK   b   060000  block special
 7000  S_IFMPB       070000  multiplexed block special (V7)
 8000  S_IFREG   -   100000  regular file
 9000  S_IFCNT   C   110000  contiguous file
 9000  S_IFNWK   n   110000  network special (HP-UX)
 a000  S_IFLNK   l@  120000  symbolic link
 b000  S_IFSHAD      130000  Solaris ACL shadow inode,
                             not seen by userspace
 c000  S_IFSOCK  s=  140000  socket AF_UNIX
 d000  S_IFDOOR  D>  150000  door (Solaris)
 e000  S_IFWHT   w%  160000  whiteout (BSD)
 e000  S_IFPORT  P   160000  event port (Solaris)
 f000  S_IFEVC       170000  UNOS event count

=cut

sub ifmt2str {
	my ($self, $mode) = @_;
	return substr($self->IFMTCHARS, oct($mode) & 017, 1);
}

=item aclget_to_file(string $path)

Gets a file's Access Control List into a temporary file and returns its
filename.

=cut

sub aclget_to_file {
	my ($self, $path) = @_;
	my $res = '';
	# automatically destroys and unlinks any old file
	$self->{_aclfile} = new File::Temp(
		TEMPLATE => 'pfm.XXXXXXXXXXXX',
		DIR      => '/tmp',
	);
	my @lines = $self->aclget($path);
	return '' unless @lines;
	$self->{_aclfile}->print(@lines);
	if ($self->{_aclfile}->close()) {
		$res = $self->{_aclfile}->filename;
	}
	return $res;
}

=item aclput_from_file(string $path, string $aclfilename)

Sets a file's Access Control List from the data in a temporary file.
Removes the temporary file afterwards.

=cut

sub aclput_from_file {
	my ($self, $path, $aclfilename) = @_;
	my $res = $self->aclput($path, $aclfilename, $self->{_aclfile});
	undef $self->{_aclfile}; # destroy and unlink
	return $res;
}

=item acledit_via_file(string $aclfilename)

Allows the user to edit a temporary file containing an Access Control
List description.

=cut

sub acledit_via_file {
	my ($self, $aclfilename) = @_;
	my $res = $self->system(
		$self->{_config}{fg_editor},
		$aclfilename);
	return $res;
}

##########################################################################
# public interface helper functions

=item system( [ args... ] )

Starts the OS command provided. Output goes to the terminal.

=cut

sub system {
	my ($self, @args) = @_;
	my $shellcmd = join ' ', map { quotemeta } (@args);
	return !system $shellcmd;
}

=item backtick( [ args... ] )

Starts the OS command provided. Output is returned as an array.

=cut

sub backtick {
	my ($self, @args) = @_;
	my $shellcmd = join ' ', map { quotemeta } (@args);
	return qx($shellcmd);
}

##########################################################################
# public interfaces to Unix commands

=item unwo(string $file)

Platform-independent method for removing the whiteout file with
the provided name.

=cut

sub unwo {
	my ($self, $file) = @_;
	$self->system(@{$self->{_unwo_cmd}}, $file);
}

=item listwhite(string $path)

Platform-independent method for listing whiteout files.

=cut

sub listwhite {
	my ($self, $file) = @_;
	return () unless $self->{_listwhite_cmd};
	return $self->backtick($self->{_listwhite_cmd}, $file);
}

=item df(string $path)

Platform-independent method for requesting filesystem info
using df(1).

=cut

# aix     => requires parsing
# freebsd => can use the default unless proven otherwise
# netbsd  => can use the default unless proven otherwise
# dec_osf => can use the default unless proven otherwise
# beos    => can use the default unless proven otherwise
# hpux    => uses 'bdf'
# irix    => requires parsing
# sco     => uses 'dfspace'
# darwin  => can use the default unless proven otherwise
# MSWin32, os390 etc. not supported

sub df {
	my ($self, $file) = @_;
	my @lines = $self->backtick(qw{df -k}, $file);
	return $self->_df_unwrap(@lines);
}

=item du(string $path)

Platform-independent method for requesting file space usage info
using du(1).

=cut

# AIX,BSD,Tru64 : du gives blocks, du -k kbytes
# Solaris       : du gives kbytes
# HP            : du gives blocks,               du -b blocks in swap(?)
# Linux         : du gives blocks, du -k kbytes, du -b bytes
# Darwin        : du gives blocks, du -k kbytes

# aix     => can use the default
# freebsd => can use the default
# netbsd  => can use the default
# dec_osf => can use the default unless proven otherwise
# beos    => can use the default unless proven otherwise
# irix    => can use the default unless proven otherwise
# sco     => can use the default unless proven otherwise
# darwin  => can use the default
# MSWin32, os390 etc. not supported

sub du {
	my ($self, $file) = @_;
	my $line = $self->backtick(qw{du -sk}, $file);
	$line =~ /(\d+)/;
	$line = 1024 * $1;
	return $line;
}

=item aclget(string $path)

Stub method for getting a file's Access Control List.

=cut

sub aclget {
	my ($self, $path) = @_;
	return '';
}

=item aclput(string $path, string $aclfilename)

Stub method for setting a file's Access Control List.

=cut

sub aclput {
	my ($self, $path, $aclfilename) = @_;
	print "Not implemented\n";
	return 0;
}

=item acledit(string $path)

Platform-independent method for editing Access Control Lists.

=cut

sub acledit {
	my ($self, $path) = @_;
	my $aclfilename;
	# next line contains an assignment on purpose
	return 0 unless $aclfilename = $self->aclget_to_file($path);
	return 0 unless $self->acledit_via_file($aclfilename);
	return 0 unless $self->aclput_from_file($path, $aclfilename);
	return 1;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
