#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen::Diskinfo 2010-03-27 v0.01
#
# Name:			PFM::Screen::Diskinfo.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Diskinfo class, handles the display of
#				disk-related information, marked files,
#				identity and clock
#

##########################################################################
# declarations

package PFM::Screen::Diskinfo;

use base 'PFM::Abstract';

use constant {
	DISKINFOLINE	=> 4,
	DIRINFOLINE		=> 9,
	MARKINFOLINE	=> 15,
	USERINFOLINE	=> 21,
	DATEINFOLINE	=> 22,
};

use constant IDENTMODES => { user => 0, host => 1, 'user@host' => 2 };

my ($_pfm,
	$_ident);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
	$self->{ident_mode} = 0;
}

##########################################################################
# constructor, getters and setters

=item initident()

Decides whether to display just username, just hostname or both.

=cut

sub initident {
	my ($self) = @_;
	my $screen = $_pfm->screen;
	chomp ($_ident  = getpwuid($>)  ) unless $self->{ident_mode} == 1;
	chomp ($_ident  = `hostname`    )     if $self->{ident_mode} == 1;
	chomp ($_ident .= '@'.`hostname`)     if $self->{ident_mode} == 2;
	$screen->set_deferred_refresh($screen->R_DISKINFO | $screen->R_FOOTER);
}

##########################################################################
# public subs

=item show()

Shows the entire disk info column.

=cut

# TODO too much
sub show {
	my $self = shift;
	my $spaces = ' ' x $infolength;
	my $screen = $_pfm->screen;
	# gap is not filled in yet
	my $gap = ' ' x (max($infocol-length($currentformatline)-$filerecordcol,
						 $filerecordcol-$infolength));
	$self->disk_info(%disk);
	$screen->at(DIRINFOLINE-2, $infocol)->puts($spaces);
	$self->dir_info(%total_nr_of);
	$screen->at($MARKINFOLINE-2, $infocol)->puts($spaces);
	$self->mark_info(%selected_nr_of);
	$screen->at($USERINFOLINE-1, $infocol)->puts($spaces);
	user_info();
	clock_info();
	foreach ($DATEINFOLINE+2 .. $BASELINE+$screenheight) {
		$scr->at($_, $infocol)->puts($spaces);
	}
}

sub user_info {
	$scr->at($USERINFOLINE, $infocol)->putcolored(($> ? 'normal' : 'red'), str_informatted($ident));
}

sub disk_info { # %disk{ total, used, avail }
	my @desc		= ('K tot','K usd','K avl');
	my @values		= %_pfm->state->disk{qw/total used avail/};
	my $startline	= $DISKINFOLINE;
	# I played with vt100 boxes once,      lqqqqk
	# but I hated it.                      x    x
	# In case someone wants to try:        mqqqqj
#	$scr->at($startline-1,$infocol)->puts("\cNlqq\cO Disk space");
	$scr->at($startline-1, $infocol)->puts(str_informatted('Disk space'));
	foreach (0..2) {
		while ($values[$_] > 99_999) {
			$values[$_] /= 1024;
			$desc[$_] =~ tr/KMGTPEZ/MGTPEZY/;
		}
		$scr->at($startline+$_, $infocol)
			->puts(data_informatted(int($values[$_]), $desc[$_]));
	}
}

sub dir_info {
	my @desc   = ('files','dirs ','symln','spec ');
	my @values = @total_nr_of{'-','d','l'};
	$values[3] = $total_nr_of{'c'} + $total_nr_of{'b'}
			   + $total_nr_of{'p'} + $total_nr_of{'s'}
			   + $total_nr_of{'D'} + $total_nr_of{'w'}
			   + $total_nr_of{'n'};
	my $startline = $DIRINFOLINE;
	$scr->at($startline-1, $infocol)
		->puts(str_informatted("Directory($sort_mode" . ($white_mode ? '' : '%') . ($dot_mode ? '' : '.') . ")"));
	foreach (0..3) {
		$scr->at($startline+$_, $infocol)
			->puts(data_informatted($values[$_],$desc[$_]));
	}
}

sub mark_info {
	my @desc = ('bytes','files','dirs ','symln','spec ');
	my @values = @selected_nr_of{'bytes','-','d','l'};
	$values[4] = $selected_nr_of{'c'} + $selected_nr_of{'b'}
			   + $selected_nr_of{'p'} + $selected_nr_of{'s'}
			   + $selected_nr_of{'D'} + $selected_nr_of{'w'}
			   + $selected_nr_of{'n'};
	my $startline = $MARKINFOLINE;
	my $total = 0;
	$values[0] = join ('', fit2limit($values[0], 9_999_999));
	$values[0] =~ s/ $//;
	$scr->at($startline-1, $infocol)->puts(str_informatted('Marked files'));
	foreach (0..4) {
		$scr->at($startline+$_, $infocol)
			->puts(data_informatted($values[$_], $desc[$_]));
		$total += $values[$_] if $_;
	}
	return $total;
}

sub clock_info {
	my ($date, $time);
	my $line = $DATEINFOLINE;
	($date, $time) = time2str(time, $TIME_CLOCK);
	if ($scr->rows() > 24) {
		$scr->at($line++, $infocol)->puts(str_informatted($date));
	}
	$scr->at($line++, $infocol)->puts(str_informatted($time));
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
