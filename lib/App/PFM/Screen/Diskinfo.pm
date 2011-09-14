#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen::Diskinfo 0.11
#
# Name:			App::PFM::Screen::Diskinfo
# Version:		0.12
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-24
#

##########################################################################

=pod

=head1 NAME

App::PFM::Screen::Diskinfo

=head1 DESCRIPTION

PFM class for displaying disk usage information, directory information,
a count of marked files, identity and clock.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Screen::Diskinfo;

use base qw(App::PFM::Abstract Exporter);

use App::PFM::Util qw(formatted fit2limit max);
use POSIX qw(strftime);

use locale;
use strict;

use constant {
	LINE_DISKINFO	=> 4,
	LINE_DIRINFO	=> 9,
	LINE_MARKINFO	=> 15,
	LINE_USERINFO	=> 21,
	LINE_DATEINFO	=> 22,
};

use constant IDENTMODES => { user => 0, host => 1, 'user@host' => 2 };

our %EXPORT_TAGS = (
	constants => [ qw(
		LINE_DISKINFO
		LINE_DIRINFO
		LINE_MARKINFO
		LINE_USERINFO
		LINE_DATEINFO
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{constants}};

our ($_pfm, $_screen);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm, App::PFM::Screen $screen)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen) = @_;
	$_pfm        = $pfm;
	$_screen     = $screen;
	$self->{_ident}      = '';
	$self->{_ident_mode} = 0;
	$self->{_infolength} = 0;
	$self->{_infocol}	 = 0;
}

=item _str_informatted(string $info)

=item _data_informatted(int $data, string $info)

Formats lines for printing in the diskinfo area.

=cut

sub _str_informatted {
	my ($self, @args) = @_;
	return formatted('@' . '>' x ($self->{_infolength}-1), @args);
}

sub _data_informatted {
	my ($self, @args) = @_;
	return formatted('@' . '>' x ($self->{_infolength}-7) . ' @<<<<<', @args);
}

##########################################################################
# constructor, getters and setters

=item infocol( [ int $column ] )

Getter/setter for the infocol variable, that controls in which terminal
column the diskinfo area starts.

=cut

sub infocol {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_infocol} = $value >= 0 ? $value : 0;
	}
	return $self->{_infocol};
}

=item infolength( [ int $infolength ] )

Getter/setter for the infolength variable, that indicates the width
of the diskinfo area, in characters.

=cut

sub infolength {
	my ($self, $value) = @_;
	$self->{_infolength} = $value if defined $value;
	return $self->{_infolength};
}

=item ident_mode( [ int $ident_mode ] )

Getter/setter for the ident_mode variable, which controls whether
to display just the username, just the hostname or both.

=cut

sub ident_mode {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_ident_mode} = $value;
		$self->initident();
	}
	return $self->{_ident_mode};
}

=item initident()

Translates the ident mode to the actual ident string
displayed on screen.

=cut

sub initident {
	my ($self) = @_;
	chomp ($self->{_ident}  = getpwuid($>)  ) unless $self->{_ident_mode} == 1;
	chomp ($self->{_ident}  = `hostname`    )     if $self->{_ident_mode} == 1;
	chomp ($self->{_ident} .= '@'.`hostname`)     if $self->{_ident_mode} == 2;
	$_screen->set_deferred_refresh($_screen->R_DISKINFO | $_screen->R_FOOTER);
}

=item select_next_ident()

Cycles through showing the username, hostname or both.

=cut

sub select_next_ident {
	my ($self) = @_;
	if (++$self->{_ident_mode} > 2) {
		$self->{_ident_mode} = 0;
	}
	$self->initident();
	return $self->{_ident_mode};
}

##########################################################################
# public subs

=item show()

Displays the entire diskinfo column.

=cut

sub show {
	my ($self) = @_;
	my $spaces            = ' ' x $self->{_infolength};
	my $infocol           = $self->{_infocol};
	my $filerecordcol     = $_screen->listing->filerecordcol;
	my $currentformatline = $_screen->listing->currentformatline;
	# gap is not filled in yet
	my $gap = ' ' x (max(
		$infocol - length($currentformatline)-$filerecordcol,
		$filerecordcol - $self->{_infolength}));
	$self->disk_info();
	$_screen->at(LINE_DIRINFO-2, $infocol)->puts($spaces);
	$self->dir_info();
	$_screen->at(LINE_MARKINFO-2, $infocol)->puts($spaces);
	$self->mark_info();
	$_screen->at(LINE_USERINFO-1, $infocol)->puts($spaces);
	$self->user_info();
	$self->clock_info();
	foreach (LINE_DATEINFO+2 .. $_screen->BASELINE + $_screen->screenheight) {
		$_screen->at($_, $infocol)->puts($spaces);
	}
	return $_screen;
}

=item clearcolumn()

Clears the entire diskinfo column.

=cut

sub clearcolumn {
	my ($self) = @_;
	my $spaces = ' ' x $self->{_infolength};
	foreach ($_screen->BASELINE .. $_screen->BASELINE+$_screen->screenheight) {
		$_screen->at($_, $self->{_infocol})->puts($spaces);
	}
	return $_screen;
}

=item user_info()

Displays the hostname, username or username@hostname.

=cut

sub user_info {
	my ($self) = @_;
	$_screen->at(LINE_USERINFO, $self->{_infocol})->putcolored(
		($> ? 'normal' : 'red'), $self->_str_informatted($self->{_ident})
	);
}

=item disk_info()

Displays the filesystem usage.

=cut

sub disk_info {
	my ($self) = @_;
	my @desc      = ('K tot','K usd','K avl');
	my @values    = @{$_pfm->state->directory->disk}{qw/total used avail/};
	my $startline = LINE_DISKINFO;
	$_screen->at($startline-1, $self->{_infocol})
		->puts($self->_str_informatted('Disk space'));
	foreach (0..2) {
		while ($values[$_] > 99_999) {
			$values[$_] /= 1024;
			$desc[$_] =~ tr/KMGTPEZ/MGTPEZY/;
		}
		$_screen->at($startline + $_, $self->{_infocol})
				->puts($self->_data_informatted(int($values[$_]), $desc[$_]));
	}
}

=item dir_info()

Displays the number of directory entries of different types.

=cut

sub dir_info {
	my ($self) = @_;
	my @desc   = ('files','dirs ','symln','spec ');
	my %total_nr_of = %{$_pfm->state->directory->total_nr_of};
	my @values = @total_nr_of{'-','d','l'};
	$values[3] = $total_nr_of{'c'} + $total_nr_of{'b'}
			   + $total_nr_of{'p'} + $total_nr_of{'s'}
			   + $total_nr_of{'D'} + $total_nr_of{'w'}
			   + $total_nr_of{'n'};
	my $startline = LINE_DIRINFO;
	my $heading = 'Directory';
	# pfm1 style
#	my $heading = 'Directory'
#				. '('
#				.  $_pfm->state->{sort_mode}
#				. ($_pfm->state->{white_mode} ? '' : '%')
#				. ($_pfm->state->{dot_mode} ? '' : '.') . ')';
	$_screen->at($startline-1, $self->{_infocol})
			->puts($self->_str_informatted($heading));
	foreach (0..3) {
		$_screen->at($startline + $_, $self->{_infocol})
				->puts($self->_data_informatted($values[$_], $desc[$_]));
	}
}

=item mark_info()

Displays the number of directory entries that have been marked.

=cut

sub mark_info {
	my ($self) = @_;
	my @desc = ('bytes','files','dirs ','symln','spec ');
	my %selected_nr_of = %{$_pfm->state->directory->selected_nr_of};
	my @values = @selected_nr_of{'bytes','-','d','l'};
	$values[4] = $selected_nr_of{'c'} + $selected_nr_of{'b'}
			   + $selected_nr_of{'p'} + $selected_nr_of{'s'}
			   + $selected_nr_of{'D'} + $selected_nr_of{'w'}
			   + $selected_nr_of{'n'};
	my $startline = LINE_MARKINFO;
	my $heading = 'Marked files';
	my $total = 0;
	$values[0] = join ('', fit2limit($values[0], 9_999_999));
	$values[0] =~ s/ $//;
	$_screen->at($startline-1, $self->{_infocol})
			->puts($self->_str_informatted($heading));
	foreach (0..4) {
		$_screen->at($startline + $_, $self->{_infocol})
				->puts($self->_data_informatted($values[$_], $desc[$_]));
		$total += $values[$_] if $_;
	}
	return $total;
}

=item clock_info()

Displays the clock in the diskinfo column.

=cut

sub clock_info {
	my ($self) = @_;
	my $line = LINE_DATEINFO;
	my $now = time;
	my $date = strftime($_pfm->config->{clockdateformat}, localtime $now),
	my $time = strftime($_pfm->config->{clocktimeformat}, localtime $now);
	$date = $self->_str_informatted($date);
	$time = $self->_str_informatted($time);
	if ($_screen->rows() > 24) {
		$_screen->at($line++, $self->{_infocol})->puts($date);
	}
	$_screen->at($line, $self->{_infocol})->puts($time);
}

##########################################################################

=back

=head1 CONSTANTS

This package provides the several constants defining screen line numbers
for blocks of information.
They can be imported with C<use App::PFM::Screen::Frame qw(:constants)>.

=over

=item LINE_DISKINFO

The screenline of the start of the disk info block.

=item LINE_DIRINFO

The screenline of the start of the directory info block.

=item LINE_MARKINFO

The screenline of the start of the marked file info block.

=item LINE_USERINFO

The screenline of the start of the ident information.

=item LINE_DATEINFO

The screenline of the start of the date/time block.

=back

=head1 SEE ALSO

pfm(1), App::PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
