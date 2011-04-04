#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Util 0.10
#
# Name:			PFM::Util.pm
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
#

##########################################################################

=pod

=head1 NAME

PFM::Util

=head1 DESCRIPTION

Static class derived from Exporter that provides some practical
utility functions for pfm.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Util;

use base 'Exporter';

use Carp;

use constant {
	TIME_FILE	=> 0,
	TIME_CLOCK	=> 1,
};

our @EXPORT = qw(min max inhibit triggle toggle isyes isno basename dirname
				 isxterm formatted time2str fit2limit canonicalize_path
				 mode2str TIME_FILE TIME_CLOCK);

my $XTERMS = qr/^(.*xterm.*|rxvt.*|gnome.*|kterm)$/;
my @SYMBOLIC_MODES = qw(--- --x -w- -wx r-- r-x rw- rwx);

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
	$_[0] =~ m!^(.*)/.+?!;
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
	formline(shift(), @_);
	return $^A;
}

=item time2str()

Formats a time for printing. Can be used for timestamps (with the TIME_FILE
flag) or for the on-screen clock (with TIME_CLOCK).

=cut

# TODO pfmrc
sub time2str {
	my ($time, $flag) = @_;
	if ($flag == TIME_FILE) {
		return strftime ($pfmrc{timestampformat}, localtime $time);
	} else {
		return strftime ($pfmrc{clockdateformat}, localtime $time),
			   strftime ($pfmrc{clocktimeformat}, localtime $time);
	}
}

=item fit2limit()

Fits a file size into a certain number of characters by converting it
to a number with kilo (mega, giga, ...) specification.

=cut

sub fit2limit {
	my ($self, $size_num, $limit) = @_;
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

sub canonicalize_path {
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

=item mode2str()

Converts a numeric file mode (permission bits) to a symbolic one
(I<e.g.> C<drwxr-x--->).

=cut

sub mode2str {
	# concerning acls, see http://compute.cnr.berkeley.edu/cgi-bin/man-cgi?ls+1
	my $strmode;
	my $nummode = shift; # || 0;
	my $octmode = sprintf("%lo", $nummode);
	$octmode	=~ /(\d\d?)(\d)(\d)(\d)(\d)$/;
	$strmode	= substr('-pc?d?b?-nl?sDw?', oct($1) & 017, 1)
				. $SYMBOLIC_MODES[$3] . $SYMBOLIC_MODES[$4] . $SYMBOLIC_MODES[$5];
	# 0000                000000  unused
	# 1000  S_IFIFO   p|  010000  fifo (named pipe)
	# 2000  S_IFCHR   c   020000  character special
	# 3000  S_IFMPC       030000  multiplexed character special (V7)
	# 4000  S_IFDIR   d/  040000  directory
	# 5000  S_IFNAM       050000  XENIX named special file with two subtypes,
	#                             distinguished by st_rdev values 1,2:
	# 0001  S_INSEM   s   000001    semaphore
	# 0002  S_INSHD   m   000002    shared data
	# 6000  S_IFBLK   b   060000  block special
	# 7000  S_IFMPB       070000  multiplexed block special (V7)
	# 8000  S_IFREG   -   100000  regular
	# 9000  S_IFNWK   n   110000  network special (HP-UX)
	# a000  S_IFLNK   l@  120000  symbolic link
	# b000  S_IFSHAD      130000  Solaris ACL shadow inode,not seen by userspace
	# c000  S_IFSOCK  s=  140000  socket
	# d000  S_IFDOOR  D>  150000  Solaris door
	# e000  S_IFWHT   w%  160000  BSD whiteout
	#
	if ($2 & 4) { substr($strmode,3,1) =~ tr/-x/Ss/ }
	if ($2 & 2) {
		if ($pfmrc{showlockchar} eq 'l') {
			substr($strmode,6,1) =~ tr/-x/ls/;
		} else {
			substr($strmode,6,1) =~ tr/-x/Ss/;
		}
	}
	if ($2 & 1) { substr($strmode,9,1) =~ tr/-x/Tt/ }
	return $strmode;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
