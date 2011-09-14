#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Haiku 0.02
#
# Name:			App::PFM::OS::Haiku
# Version:		0.02
# Author:		Rene Uittenbogaard
# Created:		2010-10-16
# Date:			2010-10-16
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Haiku

=head1 DESCRIPTION

PFM OS class for access to Haiku-specific OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Haiku;

use base 'App::PFM::OS::Abstract';

use strict;
use locale;

#use constant MINORBITS => 2 ** 16;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item df(string $path)

Haiku-specific method for requesting filesystem info.

=cut

sub df {
	# we have:
	# Haiku$ df .
	#    Device No.: 3
	#    Mounted at: /boot
	#   Volume Name: "Haiku"
	#   File System: bfs
	#        Device: /dev/disk/ata/0/master/raw
	#         Flags: QAM-P-W
	#      I/O Size:      64.0K (65536 byte)
	#    Block Size:       2.0K (2048 byte)
	#  Total Blocks:     649.7M (332640 blocks)
	#   Free Blocks:      23.8M (12178 blocks)
	#   Total Nodes: 0
	#    Free Nodes: 0
	#    Root Inode: 131072
	#
	# Haiku$ df /
	#    Device No.: 1
	#    Mounted at: /
	#   Volume Name: ""
	#   File System: rootfs
	#        Device:
	#         Flags: ------W
	#      I/O Size:          0 (0 byte)
	#    Block Size:          0 (0 byte)
	#  Total Blocks:          0 (0 blocks)
	#   Free Blocks:          0 (0 blocks)
	#   Total Nodes: 0
	#    Free Nodes: 0
	#    Root Inode: 1
	#
	# we'd like:
	# Linux$ df -k
	# Filesystem   1K-blocks      Used  Available  Use%  Mounted on
	# /dev/sda5    107890108  10446800   91962736   11%  /
	# /dev/sda1     41286796   2862444   36327068    8%  /home
	#    0             1           2          3      4    5
	#
	my ($self, $file) = @_;
	my (@result, $fs, $fstype, $total, $used, $free, $perc, $mountpt, $bsize);
	my @lines = $self->backtick('df', $file);
	foreach (0 .. $#lines) {
		for ($lines[$_]) {
			/Mounted at: (.*)/			and $mountpt = $1, last;
			/Device: (.*)/				and $fs      = $1, last;
			/File System: (.*)/			and $fstype  = $1, last;
			/Block Size:[^(]*\((\d+)/	and $bsize   = $1, last;
			/Total Blocks:[^(]*\((\d+)/	and $total   = $1, last;
			/Free Blocks:[^(]*\((\d+)/	and $free    = $1, last;
		}
	}
	$used = $total - $free;
	$perc = $total ? $used / $total * 100 : 0;
	$result[0] = "Filesystem 1K-blocks Used Available Use% Mountpoint";
	$result[1] = sprintf(
		'%s %d %d %d %d%% %s',
		$fs || $fstype,
		$total * $bsize / 1024,
		$used  * $bsize / 1024,
		$free  * $bsize / 1024,
		$perc,
		$mountpt,
	);
	return @result;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
