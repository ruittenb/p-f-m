#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen::Diskinfo 0.16
#
# Name:			App::PFM::Screen::Diskinfo
# Version:		0.16
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-18
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

use Sys::Hostname;
use POSIX qw(strftime ttyname);

use locale;
use strict;

use constant {
	LINE_DISKINFO				=> 4,
	LINE_DIRINFO				=> 9,
	LINE_MARKINFO				=> 15,
	LINE_USERINFO				=> 21,
	LINE_DATEINFO				=> 22,
	HEIGHT_EXTENDED_DATEINFO	=> 25,
	HEIGHT_EXTENDED_USERINFO	=> 26,
};

# Ident definitions must pairwise have the same initial field
# (see select_next_ident()).
use constant IDENTMODES => [
	'user,host',
	'user,tty',
	'host,tty',
	'host,user',
	'tty,user',
	'tty,host',
];

our %EXPORT_TAGS = (
	# don't export LINE_DATEINFO: use line_dateinfo() instead.
	constants => [ qw(
		LINE_DISKINFO
		LINE_DIRINFO
		LINE_MARKINFO
		LINE_USERINFO
		HEIGHT_EXTENDED_DATEINFO
		HEIGHT_EXTENDED_USERINFO
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{constants}};

our ($_pfm);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm, App::PFM::Screen $screen
[, App::PFM::Config $config ] )

Initializes new instances. Called from the constructor.

Note that at the time of instantiation, the config file has normally
not yet been read.

=cut

sub _init {
	my ($self, $pfm, $screen, $config) = @_;
	$_pfm                = $pfm;
	$self->{_screen}     = $screen;
	$self->{_config}     = $config; # undefined, see on_after_parse_config
	$self->{_ident}      = [];
	$self->{_ident_mode} = undef;
	$self->{_infolength} = 0;
	$self->{_infocol}	 = 0;
	$self->_initident();
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

=item _initident()

Figures out the current username, hostname, and ttyname.

=cut

sub _initident {
	my ($self) = @_;
	my $user  = getpwuid($>);
	my $host  = hostname();
	my $tty   = ttyname(*STDIN);
	$host =~ s/\..*//; # host part of hostname
	$tty  =~ s!/dev/!!;
	$self->{_ident_elements} = {
		user => $user,
		host => $host,
		tty  => $tty,
	};
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
		$self->setident();
	}
	return $self->{_ident_mode};
}

=item setident()

Translates the ident mode to the symbolic ident strings
displayed on screen.

=cut

sub setident {
	my ($self) = @_;
	my @ident_mode = split /,/, IDENTMODES()->[$self->{_ident_mode}];
	$self->{_ident} = [ map { $self->{_ident_elements}{$_}; } @ident_mode ];
	$self->{_screen}->set_deferred_refresh(
		$self->{_screen}->R_DISKINFO | $self->{_screen}->R_FOOTER);
}

=item select_next_ident()

Cycles through showing any two of username, hostname or ttyname.

=cut

sub select_next_ident {
	my ($self) = @_;
	unless ($self->extended_userinfo) {
		# This assumes that ident definitions pairwise have the
		# same initial field.
		$self->{_ident_mode}++;
	}
	if (++$self->{_ident_mode} > $#{IDENTMODES()}) {
		$self->{_ident_mode} -= scalar @{IDENTMODES()};
	}
	$self->setident();
	return $self->{_ident_mode};
}

=item line_dateinfo()

Returns LINE_DATEINFO, incremented by one if the ident field is
extended because the screen has enough rows.

=cut

sub line_dateinfo {
	my ($self) = @_;
	return LINE_DATEINFO + $self->extended_userinfo();
}

=item extended_userinfo()

Returns if the screen has enough rows to allow for an extended
ident field.

=cut

sub extended_userinfo {
	my ($self) = @_;
	return $self->{_screen}->rows >= HEIGHT_EXTENDED_USERINFO;
}

=item extended_dateinfo()

Returns if the screen has enough rows to allow for an extended
datetime field.

=cut

sub extended_dateinfo {
	my ($self) = @_;
	return $self->{_screen}->rows >= HEIGHT_EXTENDED_DATEINFO;
}

##########################################################################
# public subs

=item on_after_parse_config(App::PFM::Event $event)

Applies the config settings when the config file has been read and parsed.

=cut

sub on_after_parse_config {
	my ($self, $event) = @_;
	my $i = 0;
	# only now can we set _config in $self
	$self->{_config} = $event->{origin};
	unless (defined $self->{_ident_mode}) {
		my %identmodes = map { $_, $i++ } @{IDENTMODES()};
		$self->ident_mode(
			$identmodes{$self->{_config}{ident_mode}} || 0
		);
	}
}

=item show()

Displays the entire diskinfo column.

=cut

sub show {
	my ($self) = @_;
	my $screen            = $self->{_screen};
	my $spaces            = ' ' x $self->{_infolength};
	my $infocol           = $self->{_infocol};
	my $filerecordcol     = $screen->listing->filerecordcol;
	my $currentformatline = $screen->listing->currentformatline;

	$self->disk_info();
	$screen->at(LINE_DIRINFO-2, $infocol)->puts($spaces);
	$self->dir_info();
	$screen->at(LINE_MARKINFO-2, $infocol)->puts($spaces);
	$self->mark_info();
	$screen->at(LINE_USERINFO-1, $infocol)->puts($spaces);
	$self->user_info();
	$self->clock_info();
	foreach ($self->line_dateinfo+2 ..
			$screen->BASELINE + $screen->screenheight)
	{
		$screen->at($_, $infocol)->puts($spaces);
	}
	return $screen;
}

=item clearcolumn()

Clears the entire diskinfo column.

=cut

sub clearcolumn {
	my ($self) = @_;
	my $screen = $self->{_screen};
	my $spaces = ' ' x $self->{_infolength};
	foreach ($screen->BASELINE .. $screen->BASELINE+$screen->screenheight) {
		$screen->at($_, $self->{_infocol})->puts($spaces);
	}
	return $screen;
}

=item user_info()

Displays the hostname, username, ttyname or a combination, as defined by
'identmode'

=cut

sub user_info {
	my ($self) = @_;
	my $screen = $self->{_screen};
	my $config = $self->{_config};
	my $line   = LINE_USERINFO;
	my $color  = ($> ? 'normal'
		: $config->{framecolors}{$screen->color_mode}{rootuser});
	$screen->at($line++, $self->{_infocol})
		->putcolored($color, $self->_str_informatted($self->{_ident}[0]));
	if ($self->extended_userinfo()) {
		$screen->at($line++, $self->{_infocol})
			->putcolored($color, $self->_str_informatted($self->{_ident}[1]));
	}
}

=item disk_info()

Displays the filesystem usage.

=cut

sub disk_info {
	my ($self) = @_;
	my @desc      = ('K tot','K usd','K avl');
	my @values    = @{$_pfm->state->directory->disk}{qw/total used avail/};
	my $line = LINE_DISKINFO;
	$self->{_screen}->at($line-1, $self->{_infocol})
		->puts($self->_str_informatted('Disk space'));
	foreach (0 .. 2) {
		while ($values[$_] > 99_999) {
			$values[$_] /= 1024;
			$desc[$_] =~ tr/KMGTPEZ/MGTPEZY/;
		}
		$self->{_screen}->at($line + $_, $self->{_infocol})
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
	my $line = LINE_DIRINFO;
	my $heading = 'Directory';
	$self->{_screen}->at($line-1, $self->{_infocol})
			->puts($self->_str_informatted($heading));
	foreach (0 .. 3) {
		$self->{_screen}->at($line + $_, $self->{_infocol})
				->puts($self->_data_informatted($values[$_], $desc[$_]));
	}
}

=item mark_info()

Displays the number of directory entries that have been marked.

=cut

sub mark_info {
	my ($self) = @_;
	my @desc = ('bytes','files','dirs ','symln','spec ');
	my %marked_nr_of = %{$_pfm->state->directory->marked_nr_of};
	my @values = @marked_nr_of{'bytes','-','d','l'};
	$values[4] = $marked_nr_of{'c'} + $marked_nr_of{'b'}
			   + $marked_nr_of{'p'} + $marked_nr_of{'s'}
			   + $marked_nr_of{'D'} + $marked_nr_of{'w'}
			   + $marked_nr_of{'n'};
	my $line = LINE_MARKINFO;
	my $heading = 'Marked files';
	my $total = 0;
	$values[0] = join ('', fit2limit($values[0], 9_999_999));
	$values[0] =~ s/ $//;
	$self->{_screen}->at($line-1, $self->{_infocol})
			->puts($self->_str_informatted($heading));
	foreach (0 .. 4) {
		$self->{_screen}->at($line + $_, $self->{_infocol})
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
	my $screen = $self->{_screen};
	my $now    = time; # fetch once to prevent overflow anomalies
	my $line   = $self->line_dateinfo();
	my $date   = strftime($_pfm->config->{clockdateformat}, localtime $now),
	my $time   = strftime($_pfm->config->{clocktimeformat}, localtime $now);
	$date = $self->_str_informatted($date);
	$time = $self->_str_informatted($time);
	if ($self->extended_dateinfo()) {
		$self->{_screen}->at($line++, $self->{_infocol})->puts($date);
	}
	$self->{_screen}->at($line, $self->{_infocol})->puts($time);
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
