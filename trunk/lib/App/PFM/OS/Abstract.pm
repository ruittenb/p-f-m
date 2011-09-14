#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Abstract 0.10
#
# Name:			App::PFM::OS::Abstract
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-25
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

use constant {
	MINORBITS => 2 ** 8,
	IFMTCHARS => ' pc?d?b?-Cl?sDw?', # whiteouts and contiguous files
};

our ($AUTOLOAD);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm)

Initializes new instances by storing the application object and
initializing some member variables.
Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$self->{_pfm}     = $pfm;
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
to a character indicating the file type.

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
	# destroy and unlink any old file
	$self->{_aclfile} = new File::Temp(
		TEMPLATE => 'pfm.acl.XXXXXXXX',
		DIR      => '/tmp',
	);
	$self->{_aclfile}->print($self->aclget($path));
	$self->{_aclfile}->close();
	return $self->{_aclfile}->filename;
}

=item aclput_from_file(string $path, string $aclfilename)

Sets a file's Access Control List from the data in a temporary file.
Removes the temporary file afterwards.

=cut

sub aclput_from_file {
	my ($self, $path, $aclfilename) = @_;
	$self->aclput($path, $aclfilename, $self->{_aclfile});
	undef $self->{_aclfile}; # destroy and unlink
}

=item acledit_via_file(string $aclfilename)

Allows the user to edit a temporary file containing an Access Control
List description.

=cut

sub acledit_via_file {
	my ($self, $aclfilename) = @_;
	$self->system(
		$self->{_pfm}->config->{fg_editor},
		$aclfilename);
}

##########################################################################
# public interface helper functions

=item system( [ args... ] )

Starts the OS command provided. Output goes to the terminal.

=cut

sub system {
	my ($self, @args) = @_;
	my $shellcmd = join ' ', map { quotemeta } (@args);
	system $shellcmd;
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
	my $aclfilename = $self->aclget_to_file($path);
	$self->acledit_via_file($aclfilename);
	$self->aclput_from_file($path, $aclfilename);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
