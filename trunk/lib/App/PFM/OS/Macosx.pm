#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Macosx 0.02
#
# Name:			App::PFM::OS::Macosx
# Version:		0.02
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-26
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Macosx

=head1 DESCRIPTION

PFM OS class for access to Mac OS/X-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Macosx;

use base 'App::PFM::OS::Abstract';

use strict;
use locale;

#use constant MINORBITS => 2 ** n;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item aclget(string $path)

Gets a file's Access Control List.

=cut

sub aclget {
	my ($self, $path) = @_;
	my @lines = $self->backtick(qw{ls -lde}, $path);
	# discard 'ls' record, keep only acls
	shift @lines if $lines[0] !~ /^\s*0:/;
	return @lines;
}

=item aclput(string $path, string $aclfilename, File::Temp $aclfile)

Sets a file's Access Control List from the data in a temporary file.

=cut

sub aclput {
	#
	# 0: user:www deny read
	# 1: user:joekewoud allow write
	# 2: user:ruittenb inherited allow write
	# 3: user:www inherited allow write,append,writesecurity,chown
	#
	my ($self, $path, $aclfilename, $aclfile) = @_;
	my ($line, @lines, $flags, $res);
	# slurp new ACL data
	# flush? close/seek? open?
	@lines = <$aclfile>;
	# remove old ACL
	$res = $self->system(qw{chmod -N}, $path);
	# add new lines one at a time
	foreach $line (@lines) {
		$line =~ s/^\s*\d+:\s*(user|group)i://;
		if ($line =~s/\binherited\b//) {
			$flags = '+ai';
		} else {
			$flags = '+a';
		}
		$res = $res && $self->system('chmod', $flags, $line, $path);
	}
	return $res;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
