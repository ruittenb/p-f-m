#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Util 0.14
#
# Name:			App::PFM::Util.pm
# Version:		0.14
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-20
#

##########################################################################

=pod

=head1 NAME

App::PFM::Util

=head1 DESCRIPTION

Static class derived from Exporter that provides some practical
utility functions for pfm.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Util;

use base 'Exporter';

use Carp;

use strict;

our @EXPORT = qw(min max inhibit triggle toggle isyes isno basename dirname
				 isxterm formatted time2str fit2limit canonicalize_path
				 isorphan ifnotdefined clearugidcache find_uid find_gid
				 TIME_FILE TIME_CLOCK);

my $XTERMS = qr/^(.*xterm.*|rxvt.*|gnome.*|kterm)$/;

my %_usercache  = ();
my %_groupcache = ();

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

sub new {
	croak(__PACKAGE__, ' should not be instantiated');
}

##########################################################################
# public subs

=item min()

=item max()

Determine the minimum or maximum numeric value out of two.

=cut

sub min ($$) {
	return +($_[1] < $_[0]) ? $_[1] : $_[0];
}

sub max ($$) {
	return +($_[1] > $_[0]) ? $_[1] : $_[0];
}

=item inhibit()

Calculates the logical inhibition of two values,
defined as ((not $a) and $b).

=cut

sub inhibit ($$) {
	return !$_[0] && $_[1];
}

=item toggle()

=item triggle()

Determine the next value in a cyclic two/three-state system.

=cut

sub toggle ($) {
	$_[0] = !$_[0];
}

sub triggle ($) {
	++$_[0] > 2 and $_[0] = 0;
	return $_[0];
}

=item isxterm()

Determines if a certain value for $ENV{TERM} is compatible with 'xterm'.

=cut

sub isxterm ($) {
	return $_[0] =~ $XTERMS;
}

=item dirname()

=item basename()

Determine the filename without directory (basename) or directoryname
containing the file (dirname) for the specified path.

=cut

sub dirname ($) {
	$_[0] =~ m{^(.*)/.+?};
	return length($1) ? $1
					  : $_[0] =~ m!^/! ? '/'
									   : '.';
}

sub basename ($) {
	$_[0] =~ m{/([^/]*)/?$};
	return length($1) ? $1 : $_[0];
}

=item isyes()

=item isno()

Determine if a certain string value is equivalent to boolean false or true.

=cut

sub isyes ($) {
	return $_[0] =~ /^(1|y|yes|true|on|always)$/i;
}

sub isno ($) {
	return $_[0] =~ /^(0|n|no|false|off|never)$/;
}

=item formatted()

Returns a line that has been formatted using Perl formatting algorithm.

=cut

sub formatted (@) {
	local $^A = '';
	formline(shift, @_);
	return $^A;
}

=item fit2limit()

Fits a file size into a certain number of characters by converting it
to a number with kilo (mega, giga, ...) specification.

=cut

sub fit2limit ($$) {
	my ($size_num, $limit) = @_;
	my $size_power = ' ';
	while ($size_num > $limit) {
		$size_num = int($size_num/1024);
		$size_power =~ tr/ KMGTPEZ/KMGTPEZY/;
	}
	return ($size_num, $size_power);
}

=item canonicalize_path()

Turns a directory path into a canonical path (like realpath()),
but does not resolve symlinks.

=cut

sub canonicalize_path ($) {
	# works like realpath() but does not resolve symlinks
	my $path = shift;
	1 while $path =~ s!/\./!/!g;
	1 while $path =~ s!^\./+!!g;
	1 while $path =~ s{/\.$}{}g;
	1 while $path =~ s!
		(^|/)				# start of string or following /
		(?:\.?[^./][^/]*
		|\.\.[^/]+)			# any filename except ..
		/+					# any number of slashes
		\.\.				# the name '..'
		(?=/|$)				# followed by nothing or a slash
		!$1!gx;
	1 while $path =~ s!//!/!g;
	1 while $path =~ s!^/\.\.(/|$)!/!g;
	$path =~ s{(.)/$}{$1}g;
	length($path) or $path = '/';
	return $path;
}

=item isorphan()

Returns if a symlink is an orphan symlink or not.

=cut

sub isorphan ($) {
	return ! -e $_[0];
}

=item ifnotdefined()

Emulates the perl 5.10 C<//> operator (returns the first argument
if it is defined, otherwise the second).

=cut

sub ifnotdefined ($$) {
	my ($a, $b) = @_;
	return (defined($a) ? $a : $b);
}

=item clearugidcache()

Clears the username/groupname cache.

=cut

sub clearugidcache() {
	%_usercache  = ();
	%_groupcache = ();
}

=item find_uid()

=item find_gid()

Finds the username or group name corresponding to a uid or gid,
and caches the result.

=cut

sub find_uid {
	my ($uid) = @_;
	return $_usercache{$uid} ||
		+($_usercache{$uid} =
			(defined($uid) ? getpwuid($uid) : '') || $uid);
}

sub find_gid {
	my ($gid) = @_;
	return $_groupcache{$gid} ||
		+($_groupcache{$gid} =
			(defined($gid) ? getgrgid($gid) : '') || $gid);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
