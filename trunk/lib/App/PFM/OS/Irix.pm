#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Irix 0.02
#
# Name:			App::PFM::OS::Irix
# Version:		0.02
# Author:		Rene Uittenbogaard
# Created:		2010-08-22
# Date:			2010-08-25
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Irix

=head1 DESCRIPTION

PFM OS class for access to IRIX-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Irix;

use base 'App::PFM::OS::Abstract';

use strict;

use constant MINORBITS => 2 ** 18;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item df(string $path)

IRIX-specific method for requesting filesystem info.

=cut

sub df {
	# we have:
	# IRIX% df -k 
	# Filesystem          Type    kbytes      use    avail %use Mounted on
	# /dev/root            xfs     39287    29074    10213  75  /
	# /dev/dsk/xlv/user2   xfs   3826740  3735108    91632  98  /usr
	# /dev/dsk/xlv/e       xfs  35224840 34471480   753360  98  /e
	#    0                  1        2        3        4    5    6
	#
	# we'd like:
	# Linux$ df -k
	# Filesystem      1K-blocks      Used  Available  Use%  Mounted on
	# /dev/sda5       107890108  10446800   91962736   11%  /
	# /dev/sda1        41286796   2862444   36327068    8%  /home
	#    0                1           2          3      4    5
	#
	my ($self, $file) = @_;
	my (@fields);
	my @lines = $self->backtick(qw{df -k}, $file);
	@lines = $self->_df_unwrap(@lines);
	# skip header: start at 1
	foreach (1..$#lines) {
		@fields = split(/\s+/, $lines[$_]);
		splice(@fields, 1, 1);
		$lines[$_] = join ' ', @fields;
	}
	return @lines;
}

=item aclget(string $path)

Gets a file's Access Control List.

=cut

sub aclget {
	my ($self, $path) = @_;
	# the linux port of XFS uses 'chacl -l', but this is not IRIX compatible
	return $self->backtick(qw{ls -dD}, $path);
}

=item aclput(string $path, string $aclfilename, File::Temp $aclfile)

Sets a file's Access Control List from the data in a temporary file.

=cut

sub aclput {
	# chacl u::rwx,g::r-x,o::r--,u:bob:r--,m::r-x file1
	my ($self, $path, $aclfilename, $aclfile) = @_;
	my $line = <$aclfile>;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	$self->system('chacl', $line, $path);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
