#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Abstract 0.01
#
# Name:			App::PFM::OS::Abstract
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-21
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

use strict;

use constant MINORBITS => 2 ** 8;

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

=item rdev_to_major_minor(int $rdev)

Getter for the constant used for splitting the I<st_rdev> field
of a I<stat> structure (see stat(2)).
Returns an array of two values: the major and minor number.

=cut

sub rdev_to_major_minor {
	my ($self, $rdev) = @_;
	return sprintf("%d", $rdev / $self->MINORBITS),
			($rdev % $self->MINORBITS);
}

##########################################################################
# public subs

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

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
