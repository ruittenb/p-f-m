#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Util 0.48
#
# Name:			App::PFM::Util
# Version:		0.48
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-24
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

use POSIX qw(mktime);
use Carp;

use strict;

use constant ELLIPSIS => '..'; # path ellipsis string

our %EXPORT_TAGS = (
	all => [ qw(
		min max inhibit toggle triggle isxterm isyes isno dirname basename
		formatted time2str fit2limit canonicalize_path reducepaths reversepath
		isorphan ifnotdefined clearugidcache find_uid find_gid condquotemeta
		touch2time testdirempty fitpath
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{all}};

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

=item min(float $first, float $second)

=item max(float $first, float $second)

Determine the minimum or maximum numeric value out of two.

=cut

sub min ($$) {
	return +($_[1] < $_[0]) ? $_[1] : $_[0];
}

sub max ($$) {
	return +($_[1] > $_[0]) ? $_[1] : $_[0];
}

=item inhibit(bool $first, bool $second)

Calculates the logical inhibition of two values,
defined as ((not $a) and $b).

=cut

sub inhibit ($$) {
	return !$_[0] && $_[1];
}

=item toggle(bool \$arg)

=item triggle(int \$arg)

Determine the next value in a cyclic two/three-state system.

=cut

sub toggle ($) {
	$_[0] = !$_[0];
}

sub triggle ($) {
	++$_[0] > 2 and $_[0] = 0;
	return $_[0];
}

=item isxterm(string $termname)

Determines if a certain value for $ENV{TERM} is compatible with 'xterm'.

=cut

sub isxterm ($) {
	return $_[0] =~ $XTERMS;
}

=item isyes(string $yesno)

=item isno(string $yesno)

Determine if a certain string value is equivalent to boolean false or true.

=cut

sub isyes ($) {
	return $_[0] =~ /^(1|y|yes|true|on|always)$/i;
}

sub isno ($) {
	return $_[0] =~ /^(0|n|no|false|off|never)$/;
}

=item dirname(string $path)

=item basename(string $path)

Determine the filename without directory (basename) or directoryname
containing the file (dirname) for the specified path.

=cut

sub dirname ($) {
	$_[0] =~ m{^(.*)/.+?};
	return length($1) ? $1
					  : $_[0] =~ m!^/! ? '/'
									   : '.';
#					  : '.';
}

sub basename ($) {
	$_[0] =~ m{/([^/]*)/?$};
	return length($1) ? $1 : $_[0];
}

=item formatted( [ $field1 [, $field2 [, ... ] ] ] )

Returns a line that has been formatted using Perl formatting algorithm.

=cut

sub formatted (@) {
	local $^A = '';
	formline(shift, @_);
	return $^A;
}

=item fit2limit(int $number, int $limit)

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

=item canonicalize_path(string $path [, bool $keeptrail ] )

Turns a directory path into a canonical path (like realpath()),
but does not resolve symlinks.

If I<keeptrail> is set, a trailing B<.> or B<..> component is
left untouched.

=cut

sub canonicalize_path ($;$) {
	my ($path, $keeptrail) = @_;
	my $ANY_FILE_EXCEPT_DOTDOT  = qr{(?:\.?[^./][^/]*|\.\.[^/]+)};
	my $ANY_NUMBER_OF_SLASHES   = qr{/+};
	my $DOT                     = qr{\.};
	my $DOTDOT                  = qr{\.\.};
	my $ANYTHING                = qr{.*};
	my $START                   = qr{^};
	my $END                     = qr{$};
	my $SLASH                   = qr{/};
	my $BEFORE_SLASH            = qr{(?=/)};
	my $START_OR_SLASH          = qr{(?:^|/)};
	my $END_OR_SLASH            = qr{(?:/|$)};
	my $END_OR_BEFORE_SLASH     = qr{(?=/|$)};

	# strip trailing slash
	$path =~ s! (.) $SLASH $END ! $1 !gexo;

	# remove '.' components in the middle
	1 while $path =~ s! $SLASH $DOT $SLASH !/!gxo;
	# remove '.' components at start
	1 while $path =~ s! $START $DOT $ANY_NUMBER_OF_SLASHES ($ANYTHING)
		! $1 eq '' ? '.' : $1 !gexo;
	if (!$keeptrail) {
		# remove '.' components at end
		1 while $path =~ s! ($ANYTHING) $SLASH $DOT $END
			! $1 eq '' ? '/' : $1 !gexo;
		# remove '..' components anywhere
		1 while $path =~ s! ($START_OR_SLASH) $ANY_FILE_EXCEPT_DOTDOT
			$ANY_NUMBER_OF_SLASHES $DOTDOT $END_OR_BEFORE_SLASH
		! $1 eq '' ? '.' : '/' !gexo;
	} else {
		# reduce '/.'
		1 while $path =~ s! $START $SLASH $DOT $END !/!gxo;
		# remove '..' components, but not at end
		1 while $path =~ s! ($START_OR_SLASH) $ANY_FILE_EXCEPT_DOTDOT
			$ANY_NUMBER_OF_SLASHES $DOTDOT $BEFORE_SLASH
		! $1 eq '' ? '.' : '/' !gexo;
		#! $1 !gexo;
	}
	# reduce multiple slashes
	1 while $path =~ s! $SLASH $ANY_NUMBER_OF_SLASHES !/!gxo;
	# remove '/..' at beginning
	1 while $path =~ s! $START $SLASH $DOTDOT $END_OR_SLASH !/!gxo;

	# strip trailing slash
	$path =~ s! (.) $SLASH $END ! $1 !gexo;
	# everything above could have caused './' at the beginning. Remove it.
	1 while $path =~ s! $START $DOT $ANY_NUMBER_OF_SLASHES ($ANYTHING)
		! $1 eq '' ? '.' : $1 !gexo;

	# return the result
	return $path;
}

=item reducepaths(string $firstpath, string $secondpath)

Removes an identical prefix from two paths.

=cut

sub reducepaths ($$) {
	# remove identical prefix from path
	my ($symlink_target_abs, $symlink_name_abs) = @_;
	my $subpath;
	while (($subpath) = ($symlink_target_abs =~ m!^(/[^/]+)(?:/|$)!)
	and index($symlink_name_abs, $subpath) == 0)
	{
		$symlink_target_abs =~ s!^/[^/]+!!;
		$symlink_name_abs   =~ s!^/[^/]+!!;
	}
	# one of these could be empty now.
	return $symlink_target_abs, $symlink_name_abs;
}

=item reversepath(string $symlink_target_abs, string $symlink_name_rel)

Reverses the path from target to symlink, I<i.e.> returns the path
from symlink to target.

=cut

sub reversepath ($$) {
	my ($symlink_target_abs, $symlink_name_rel) =
		map { canonicalize_path($_, 1) } @_;
	# $result ultimately is named as requested
	my $result = basename($symlink_target_abs);
	if ($symlink_name_rel !~ m!/!) {
		# in same dir: reversed path == rel_path
		return $result;
	}
	# lose the filename from the symlink_target_abs and symlink_name_rel,
	# keep the directory
	$symlink_target_abs = dirname($symlink_target_abs);
	$symlink_name_rel   = dirname($symlink_name_rel);
	# reverse this path as follows:
	# foreach_left_to_right pathname element of symlink_name_rel {
	#	case '..' : prepend basename target to result
	#	case else : prepend '..' to result
	# }
	foreach (split (m!/!, $symlink_name_rel)) {
		if ($_ eq '..') {
			$result = basename($symlink_target_abs) .'/'. $result;
			$symlink_target_abs = dirname($symlink_target_abs);
		} else {
			$result = '../'. $result;
			$symlink_target_abs .= '/'.$_;
		}
	}
	return canonicalize_path($result);
}

=item isorphan(string $symlinkpath)

Returns true if a symlink is an orphan symlink.

=cut

sub isorphan ($) {
	return ! -e $_[0];
}

=item ifnotdefined(mixed $first, mixed $second)

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

=item find_uid(int $uid)

=item find_gid(int $gid)

Finds the username or group name corresponding to a uid or gid,
and caches the result.

=cut

sub find_uid ($) {
	my ($uid) = @_;
	return $_usercache{$uid} ||
		+($_usercache{$uid} =
			(defined($uid) ? getpwuid($uid) : '') || $uid);
}

sub find_gid ($) {
	my ($gid) = @_;
	return $_groupcache{$gid} ||
		+($_groupcache{$gid} =
			(defined($gid) ? getgrgid($gid) : '') || $gid);
}

=item condquotemeta(bool $condition, string $text)

Conditionally quotemeta() a string.

=cut

sub condquotemeta ($$) {
	return $_[0] ? quotemeta($_[1]) : $_[1];
}

=item touch2time(string $datetime)

Parses a datetime string of the format [[CC]YY-]MM-DD hh:mm[.ss]
and returns a datetime integer as created by mktime(3).

=cut

sub touch2time ($) {
	my ($input) = @_;
	my ($yr, $mon, $day, $hr, $min, $sec) =
		($input =~ /((?:\d\d)?\d\d)?-?(\d\d)-?(\d\d)\s*(\d\d):?(\d\d)(\...)?$/);
	if ($yr < 70) {
		$yr = 2000 + $yr;
	} elsif ($yr >= 70 and $yr < 100) {
		$yr = 1900 + $yr;
	}
	return mktime($sec, $min, $hr, $day, $mon-1, $yr-1900, 0, 0, 0);

}

=item testdirempty(string $dirpath)

Tests if a directory is empty.

=cut

sub testdirempty ($) {
	my ($dirname) = @_;
	opendir TESTDIR, $dirname;
	readdir TESTDIR;				  # every directory has at least a '.' entry
	readdir TESTDIR;				  # and a '..' entry
	my $third_entry = readdir TESTDIR;# but not necessarily a third entry
	closedir TESTDIR;
	# if the directory could not be read at all, this will return true.
	# instead of catching the exception here, we will simply wait for
	# 'unlink' to return false
	return !$third_entry;
}

=item fitpath(string $path, int $maxlength)

Fits a path string to a certain length by taking out directory components.

=cut

sub fitpath ($$) {
	my ($path, $maxlength) = @_;
	my ($restpathlen);
	my $r_disppath   = '';
	my $r_baselen    = 0;
	my $r_overflow   = 0;
	my $r_ellipssize = 0;
	FIT: {
		# the next line is supposed to contain an assignment
		unless (length($path) <= $maxlength and $r_disppath = $path) {
			# no fit: try to replace (part of) the name with ..
			# we will try to keep the first part e.g. /usr1/ because this often
			# shows the filesystem we're on; and as much as possible of the end
			unless ($path =~ /^(~?\/[^\/]+?\/)(.+)/) {
				# impossible to replace; just truncate
				# this is the case for e.g. /some_ridiculously_long_directory_name
				$r_disppath = substr($path, 0, $maxlength);
				$r_baselen  = $maxlength;
				$r_overflow = 1;
				last FIT;
			}
			($r_disppath, $path) = ($1, $2);
			$r_baselen = length($r_disppath);
			# the one being subtracted is for the '/' char in the next match
			$restpathlen = $maxlength -length($r_disppath) -length(ELLIPSIS) -1;
			unless ($path =~ /(.*?)(\/.{1,$restpathlen})$/) {
				# impossible to replace; just truncate
				# this is the case for e.g. /usr/some_ridiculously_long_directory_name
				$r_disppath = substr($r_disppath.$path, 0, $maxlength);
				$r_overflow = 1;
				last FIT;
			}
			# pathname component candidate for replacement found; name will fit
			$r_disppath  .= ELLIPSIS . $2;
			$r_ellipssize = length($1) - length(ELLIPSIS);
		}
	}
	return ($r_disppath,
		' ' x max($maxlength -length($r_disppath), 0),
		$r_overflow,
		$r_baselen,
		$r_ellipssize);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
