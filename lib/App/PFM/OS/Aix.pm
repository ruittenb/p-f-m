#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Aix 0.01
#
# Name:			App::PFM::OS::Aix
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-21
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Aix

=head1 DESCRIPTION

PFM OS class for access to AIX-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Aix;

use base 'App::PFM::OS::Abstract';

use strict;

use constant MINORBITS => 2 ** 16;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item df(string $path)

AIX-specific method for requesting filesystem info.

=cut

sub df {
	# we have:
	# AIX$ df -k 
	# Filesystem  1024-blocks   Free  %Used  Iused  %Iused  Mounted on
	# /dev/hd4          45056   3528    93%   1389      7%  /
	# /dev/hd2         303104  31984    90%  10081     14%  /usr
	#    0                1      2       3     4        5    6
	#
	# we'd like:
	# Linux$ df -k
	# Filesystem      1K-blocks      Used  Available  Use%  Mounted on
	# /dev/sda5       107890108  10446800   91962736   11%  /
	# /dev/sda1        41286796   2862444   36327068    8%  /home
	#    0                1           2          3      4    5
	#
	my ($self, $file) = @_;
	my (@fields, $used);
	my @lines = $self->backtick(qw{df -k}, $file);
	@lines = $self->_df_unwrap(@lines);
	# skip header: start at 1
	foreach (1..$#lines) {
		@fields = split(/\s+/, $lines[$_]);
		$used = $fields[1] - $fields[2]; # total - free
		splice(@fields, 2, 0, $used);
		$lines[$_] = join ' ', @fields;
	}
	return @lines;
}

=item acledit(string $path)

AIX-specific method for editing Access Control Lists.

=cut

sub acledit {
	# AIX$ getacl filename
	# AIX$ ls -e
	#
	# AIX$ acledit filename
	# 
	# attributes: SUID
	# base permissions:
	#     owner(root): rw-
	#     group(root): r-x
	#     others: ---
	# extended permissions:
	#     enabled
	#     permit  r--  u:oracle
	#     permit  rw-  u:robin
	#     deny    r-x  u:catwoman
	#     deny    rwx  g:intergang
	#
	my ($self, $path) = @_;
	local $ENV{EDITOR} = $self->{_pfm}->config->{fg_editor};
	$self->system('acledit', $path);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
