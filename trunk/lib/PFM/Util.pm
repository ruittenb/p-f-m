#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Util 2010-03-27 v0.01
#
# Name:			PFM::Util.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Util class, containing utility functions.
#

=pod

=head1 NAME

PFM::Util

=head1 DESCRIPTION

Static class derived from Exporter that provides some practical
utility functions.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Util;

use base 'Exporter';

use Carp;

our @EXPORT = qw(min max inhibit triggle toggle isyes isno basename dirname
				 isxterm formatted svnmaxchar svnmax);

my $XTERMS = qr/^(.*xterm.*|rxvt.*|gnome.*|kterm)$/;

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

sub min($$) {
	return +($_[1] < $_[0]) ? $_[1] : $_[0];
}

sub max($$) {
	return +($_[1] > $_[0]) ? $_[1] : $_[0];
}

=item inhibit()

Calculates the logical inhibition of two values,
defined as ((not $a) and $b).

=cut

sub inhibit($$) {
	return !$_[0] && $_[1];
}

=item toggle()

=item triggle()

Determine the next value in a cyclic two/three-state system.

=cut

sub toggle($) {
	$_[0] = !$_[0];
}

sub triggle($) {
	++$_[0] > 2 and $_[0] = 0;
	return $_[0];
}

=item isxterm()

Determines if a certain value for $ENV{TERM} is compatible with 'xterm'.

=cut

sub isxterm($) {
	return $_[0] =~ $XTERMS;
}

=item basename()

=item dirname()

Determine the filename without directory (basename) or directoryname
containing the file (dirname) for the specified path.

=cut

sub dirname {
	$_[0] =~ m!^(.*)/.+?!;
	return length($1) ? $1
					  : $_[0] =~ m!^/! ? '/'
									   : '.';
}

sub basename {
	$_[0] =~ m{/([^/]*)/?$};
	return length($1) ? $1 : $_[0];
}

=item isyes()

=item isno()

Determine if a certain string value is equivalent to boolean false or true.

=cut

sub isyes($) {
	return $_[0] =~ /^(1|y|yes|true|on|always)$/i;
}

sub isno($) {
	return $_[0] =~ /^(0|n|no|false|off|never)$/;
}

=item formatted()

Returns a line that has been formatted using Perl formatting algorithm.

=cut

sub formatted {
	local $^A = '';
	formline(shift(), @_);
	return $^A;
}

=item svnmaxchar()

=item svnmax()

Determine which svn status character has the higher priority
and should be displayed.

=cut

sub svnmaxchar($$) {
	my ($a, $b) = @_;
	if ($a eq 'C' or $b eq 'C') {
		return 'C';
	} elsif ($a eq 'M' or $b eq 'M'or $a eq 'A' or $b eq 'A') {
		return 'M';
	} elsif ($a eq '' or $a eq '-') {
		return $b;
	} else {
		return $a;
	}
}

sub svnmax($$) {
	my ($old, $new) = @_;
	my $res = $old;
	substr($res,0,1) = svnmaxchar(substr($old,0,1), substr($new,0,1));
	substr($res,1,1) = svnmaxchar(substr($old,1,1), substr($new,1,1));
	substr($res,2,1) ||= substr($new,2,1);
	return $res;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
