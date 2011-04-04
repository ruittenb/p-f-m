#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen::Diskinfo 0.04
#
# Name:			PFM::Screen::Diskinfo.pm
# Version:		0.04
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
#

##########################################################################

=pod

=head1 NAME

PFM::Screen::Diskinfo

=head1 DESCRIPTION

PFM class for displaying disk usage information, directory information,
a count of marked files, identity and clock.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Screen::Diskinfo;

use base 'PFM::Abstract';

use locale;
use strict;

use constant {
	DISKINFOLINE	=> 4,
	DIRINFOLINE		=> 9,
	MARKINFOLINE	=> 15,
	USERINFOLINE	=> 21,
	DATEINFOLINE	=> 22,
};

use constant IDENTMODES => { user => 0, host => 1, 'user@host' => 2 };

my ($_pfm, $_screen,
	$_infocol, $_infolength, $_ident, $_ident_mode);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen) = @_;
	$_pfm        = $pfm;
	$_screen     = $screen;
	$_ident_mode = 0;
}

=item _str_informatted()

=item _data_informatted()

Formats lines for printing in the diskinfo area.

=cut

sub _str_informatted {
	my $self = shift;
	return formatted('@' . '>' x ($_infolength-1), @_);
}

sub _data_informatted {
	my $self = shift;
	return formatted('@' . '>' x ($_infolength-7) . ' @<<<<<', @_);
}

##########################################################################
# constructor, getters and setters

=item infocol()

Getter/setter for the infocol variable, that controls in which terminal
column the diskinfo area starts.

=cut

sub infocol {
	my ($self, $value) = @_;
	if (defined $value) {
		$_infocol = $value >= 0 ? $value : 0;
	}
	return $_infocol;
}

=item infolength()

Getter/setter for the infolength variable, that indicates the width
of the diskinfo area, in characters.

=cut

sub infolength {
	my ($self, $value) = @_;
	$_infolength = $value if defined $value;
	return $_infolength;
}

=item ident_mode()

Getter/setter for the ident_mode variable, which controls whether
to display just the username, just the hostname or both.

=cut

sub ident_mode {
	my ($self, $value) = @_;
	if (defined $value) {
		$_ident_mode = $value;
		$self->initident();
	}
	return $_ident_mode;
}

=item initident()

Translates the ident mode to the actual ident string
displayed on screen.

=cut

sub initident {
	my ($self) = @_;
	chomp ($_ident  = getpwuid($>)  ) unless $_ident_mode == 1;
	chomp ($_ident  = `hostname`    )     if $_ident_mode == 1;
	chomp ($_ident .= '@'.`hostname`)     if $_ident_mode == 2;
	$_screen->set_deferred_refresh($_screen->R_DISKINFO | $_screen->R_FOOTER);
}

##########################################################################
# public subs

=item show()

Displays the entire diskinfo column.

=cut

sub show {
	my $self = shift;
	my $spaces = ' ' x $_infolength;
	my $filerecordcol     = $_screen->listing->filerecordcol;
	my $currentformatline = $_screen->listing->currentformatline;
	# gap is not filled in yet
	my $gap = ' ' x (max(
		$_infocol-length($currentformatline)-$filerecordcol,
		$filerecordcol-$_infolength));
	$self->disk_info();
	$_screen->at(DIRINFOLINE-2, $_infocol)->puts($spaces);
	$self->dir_info();
	$_screen->at(MARKINFOLINE-2, $_infocol)->puts($spaces);
	$self->mark_info();
	$_screen->at(USERINFOLINE-1, $_infocol)->puts($spaces);
	$self->user_info();
	$self->clock_info();
	foreach (DATEINFOLINE+2 .. $_screen->BASELINE + $_screen->screenheight) {
		$_screen->at($_, $_infocol)->puts($spaces);
	}
}

=item clearcolumn()

Clears the entire diskinfo column.

=cut

sub clearcolumn {
	my $self = shift;
	my $spaces = ' ' x $_infolength;
	foreach ($_screen->BASELINE .. $_screen->BASELINE+$_screen->screenheight) {
		$_screen->at($_, $_infocol)->puts($spaces);
	}
}

=item user_info()

Displays the hostname, username or username@hostname.

=cut

sub user_info {
	my $self = shift;
	$_screen->at(USERINFOLINE, $_infocol)
		->putcolored(($> ? 'normal' : 'red'), $self->_str_informatted($_ident));
}

=item disk_info()

Displays the filesystem usage.

=cut

sub disk_info {
	my $self = shift;
	my @desc		= ('K tot','K usd','K avl');
	my @values		= @{$_pfm->state->directory->disk}{qw/total used avail/};
	my $startline	= DISKINFOLINE;
	# I played with vt100 boxes once,      lqqqqk
	# but I hated it.                      x    x
	# In case someone wants to try:        mqqqqj
#	$_screen->at($startline-1,$_infocol)->puts("\cNlqq\cO Disk space");
	$_screen->at($startline-1, $_infocol)->puts($self->_str_informatted('Disk space'));
	foreach (0..2) {
		while ($values[$_] > 99_999) {
			$values[$_] /= 1024;
			$desc[$_] =~ tr/KMGTPEZ/MGTPEZY/;
		}
		$_screen->at($startline + $_, $_infocol)
				->puts($self->_data_informatted(int($values[$_]), $desc[$_]));
	}
}

=item dir_info()

Displays the number of directory entries of different types.

=cut

sub dir_info {
	my $self = shift;
	my @desc   = ('files','dirs ','symln','spec ');
	my %total_nr_of = %{$_pfm->state->directory->total_nr_of};
	my @values = @total_nr_of{'-','d','l'};
	$values[3] = $total_nr_of{'c'} + $total_nr_of{'b'}
			   + $total_nr_of{'p'} + $total_nr_of{'s'}
			   + $total_nr_of{'D'} + $total_nr_of{'w'}
			   + $total_nr_of{'n'};
	my $startline = DIRINFOLINE;
	my $heading = 'Directory('
				.  $_pfm->state->sort_mode
				. ($_pfm->state->white_mode ? '' : '%')
				. ($_pfm->state->dot_mode ? '' : '.') . ')';
	$_screen->at($startline-1, $_infocol)
			->puts($self->_str_informatted($heading));
	foreach (0..3) {
		$_screen->at($startline + $_, $_infocol)
				->puts($self->_data_informatted($values[$_], $desc[$_]));
	}
}

=item mark_info()

Displays the number of directory entries that have been marked.

=cut

sub mark_info {
	my $self = shift;
	my @desc = ('bytes','files','dirs ','symln','spec ');
	my %selected_nr_of = %{$_pfm->state->directory->selected_nr_of};
	my @values = @selected_nr_of{'bytes','-','d','l'};
	$values[4] = $selected_nr_of{'c'} + $selected_nr_of{'b'}
			   + $selected_nr_of{'p'} + $selected_nr_of{'s'}
			   + $selected_nr_of{'D'} + $selected_nr_of{'w'}
			   + $selected_nr_of{'n'};
	my $startline = MARKINFOLINE;
	my $heading = 'Marked files';
	my $total = 0;
	$values[0] = join ('', fit2limit($values[0], 9_999_999));
	$values[0] =~ s/ $//;
	$_screen->at($startline-1, $_infocol)
			->puts($self->_str_informatted($heading));
	foreach (0..4) {
		$_screen->at($startline + $_, $_infocol)
				->puts($self->_data_informatted($values[$_], $desc[$_]));
		$total += $values[$_] if $_;
	}
	return $total;
}

=item clock_info()

Displays the clock in the diskinfo column.

=cut

sub clock_info {
	my $self = shift;
	my $line = DATEINFOLINE;
	my $now = time;
	my $date = strftime($_pfm->config->{clockdateformat}, localtime $now),
	my $time = strftime($_pfm->config->{clocktimeformat}, localtime $now);
	if ($_screen->rows() > 24) {
		$_screen->at($line++, $_infocol)->puts($self->_str_informatted($date));
	}
	$_screen->at($line, $_infocol)->puts($self->_str_informatted($time));
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
