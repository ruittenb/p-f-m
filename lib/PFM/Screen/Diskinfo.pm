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

my ($_pfm, $_screen,
	$_infocol, $_infolength, $_ident, $_ident_mode);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm    = $pfm;
	$_screen = $pfm->screen;
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
	$_infocol = $value if defined $value;
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
	$screen->set_deferred_refresh($screen->R_DISKINFO | $screen->R_FOOTER);
}

##########################################################################
# public subs

=item show()

Displays the entire diskinfo column.

=cut

# TODO too much
sub show {
	my $self = shift;
	my $spaces = ' ' x $_infolength;
	# gap is not filled in yet
	my $gap = ' ' x (max($_infocol-length($currentformatline)-$filerecordcol,
						 $filerecordcol-$_infolength));
	$self->disk_info(%disk);
	$_screen->at(DIRINFOLINE-2, $_infocol)->puts($spaces);
	$self->dir_info(%total_nr_of);
	$_screen->at(MARKINFOLINE-2, $_infocol)->puts($spaces);
	$self->mark_info(%selected_nr_of);
	$_screen->at(USERINFOLINE-1, $_infocol)->puts($spaces);
	user_info();
	clock_info();
	foreach (DATEINFOLINE+2 .. $BASELINE+$screenheight) {
		$scr->at($_, $_infocol)->puts($spaces);
	}
}

=item clearcolumn()

Clears the entire diskinfo column.

=cut

sub clearcolumn {
	my $spaces = ' ' x $_infolength;
	foreach (BASELINE .. BASELINE + $screen->screenheight) {
		$screen->at($_, $_infocol)->puts($spaces);
	}
}

=item user_info()

Displays the hostname, username or username@hostname.

=cut

sub user_info {
	$screen->at(USERINFOLINE, $_infocol)
		->putcolored(($> ? 'normal' : 'red'), $self->_str_informatted($_ident));
}

sub disk_info { # %disk{ total, used, avail }
	my @desc		= ('K tot','K usd','K avl');
	my @values		= %_pfm->state->disk{qw/total used avail/};
	my $startline	= $DISKINFOLINE;
	# I played with vt100 boxes once,      lqqqqk
	# but I hated it.                      x    x
	# In case someone wants to try:        mqqqqj
#	$scr->at($startline-1,$_infocol)->puts("\cNlqq\cO Disk space");
	$scr->at($startline-1, $_infocol)->puts($self->_str_informatted('Disk space'));
	foreach (0..2) {
		while ($values[$_] > 99_999) {
			$values[$_] /= 1024;
			$desc[$_] =~ tr/KMGTPEZ/MGTPEZY/;
		}
		$scr->at($startline+$_, $_infocol)
			->puts($self->_data_informatted(int($values[$_]), $desc[$_]));
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
	$scr->at($startline-1, $_infocol)
		->puts($self->_str_informatted("Directory($sort_mode" . ($white_mode ? '' : '%') . ($dot_mode ? '' : '.') . ")"));
	foreach (0..3) {
		$scr->at($startline+$_, $_infocol)
			->puts($self->_data_informatted($values[$_],$desc[$_]));
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
	$scr->at($startline-1, $_infocol)->puts($self->_str_informatted('Marked files'));
	foreach (0..4) {
		$scr->at($startline+$_, $_infocol)
			->puts($self->_data_informatted($values[$_], $desc[$_]));
		$total += $values[$_] if $_;
	}
	return $total;
}

=item clock_info()

Displays the clock in the diskinfo column.

=cut

sub clock_info {
	my ($date, $time);
	my $line = DATEINFOLINE;
	($date, $time) = time2str(time, TIME_CLOCK);
	if ($screen->rows() > 24) {
		$screen->at($line++, $_infocol)->puts($self->_str_informatted($date));
	}
	$screen->at($line++, $_infocol)->puts($self->_str_informatted($time));
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
