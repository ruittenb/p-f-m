#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen::Listing 1.16
#
# Name:			App::PFM::Screen::Listing
# Version:		1.16
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2011-05-27
#

##########################################################################

=pod

=head1 NAME

App::PFM::Screen::Listing

=head1 DESCRIPTION

PFM class for displaying an App::PFM::Directory object on the screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Screen::Listing;

use base 'App::PFM::Abstract';

use App::PFM::Util qw(formatted maxdatetimelen);

use locale;
use strict;

use constant {
	NAMETOOLONGCHAR => '+',
	FALSE			=> 0,
	TRUE			=> 1,
	FILENAME_SHORT	=> 0,
	FILENAME_LONG	=> 1,
};

use constant LAYOUTFIELDS => {
	'*' => 'mark',
	'n' => 'display',
	'N' => 'name_too_long',
	's' => 'size_num',
	'S' => 'size_power',
	'z' => 'grand_num',
	'Z' => 'grand_power',
	'u' => 'user',
	'g' => 'group',
	'w' => 'uid',
	'h' => 'gid',
	'p' => 'mode',
	'a' => 'atimestring',
	'c' => 'ctimestring',
	'm' => 'mtimestring',
	'l' => 'nlink',
	'i' => 'inode',
	'd' => 'rdev',
	'v' => 'rcs',
	'f' => 'diskinfo',
	'_' => 'gap',
};

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
	$_pfm               = $pfm;
	$self->{_screen}    = $screen;
	$self->{_config}    = $config; # undefined, see on_after_parse_config
	$self->{_layout}               = undef;
	$self->{_layoutname}           = '';
	$self->{_layoutfields}         = [];
	$self->{_layoutfieldswithinfo} = [];
	$self->{_maxfilenamelength}    = 0;
	$self->{_maxfilesizelength}    = 0;
	$self->{_maxgrandtotallength}  = 0;
	$self->{_gaplength}            = 0;
	$self->{_gapcol}               = 0;
	$self->{_cursorcol}            = 0;
	$self->{_filerecordcol}        = 0;
	$self->{_filenamecol}          = 0;
	return;
}

=item _validate_layoutnum(int $layoutnr)

Checks if the layout number does not exceed the total number of layouts.

=cut

sub _validate_layoutnum {
	my ($self, $num) = @_;
	# convert to numeric
	$num = 0 + $num;
	my $columnlayouts = $self->{_config}{columnlayouts};
	if ($num > $#$columnlayouts) {
		$num %= @$columnlayouts;
	}
	while ($num < 0) {
		$num += @$columnlayouts;
	}
	return $num;
}

=item _highlightline(bool $onoff [, int $currentline,
App::PFM::File $currentfile ] )

Turns highlight on/off on the line with the cursor.

=cut

sub _highlightline {
	my ($self, $onoff, $currentline, $currentfile) = @_;
	my $screen = $self->{_screen};
	$currentfile  ||= $_pfm->browser->currentfile;
	my $screenline  = defined($currentline)
		? $currentline : $_pfm->browser->currentline;
	$screenline    += $screen->BASELINE;
	my $linecolor;
	$screen->at($screenline, $self->{_filerecordcol});
	if ($onoff) {
		$linecolor =
			$self->{_config}{framecolors}{$screen->color_mode}{highlight};
	}
	$screen->putcolored($linecolor, $self->fileline($currentfile));
	$self->applycolor($screenline, FILENAME_SHORT, $currentfile, $onoff);
	$screen->reset()->normal()->at($screenline, $self->{_cursorcol});
	return $screen;
}

##########################################################################
# constructor, getters and setters

=item layout( [ int $layoutnr ] )

Getter/setter for the current layout number. If this is called to set
the current layout, it will do all the necessary changes.

=cut

sub layout {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_layout} = $self->_validate_layoutnum($value);
		$self->makeformatlines();
		$self->{_screen}->set_deferred_refresh($self->{_screen}->R_SCREEN);
	}
	return $self->{_layout};
}

=item bookmarkpathcol( [ int $column ] )

Getter for the column of the bookmark path in the current layout.
This is normally the same as the I<filerecordcol>, except when the
diskinfo is on the left side of the screen, in which case I<filerecordcol>
includes the gap, and I<bookmarkpathcol> does not.

=cut

sub bookmarkpathcol {
	my ($self) = @_;
	my $bookmarkpathcol = $self->{_filerecordcol} +
		($self->{_screen}->diskinfo->infocol < $self->{_filerecordcol}
			? $self->{_gaplength} : 0);
	return $bookmarkpathcol;
}

=item cursorcol( [ int $column ] )

Getter/setter for the column of the cursor in the current layout.

=cut

sub cursorcol {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_cursorcol} = $value >= 0 ? $value : 0;
	}
	return $self->{_cursorcol};
}

=item filerecordcol( [ int $column ] )

Getter/setter for the column where the file record starts in the
current layout.
This is normally the same as the I<bookmarkpathcol>, except when the
diskinfo is on the left side of the screen, in which case I<filerecordcol>
includes the gap, and I<bookmarkpathcol> does not.

=cut

sub filerecordcol {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_filerecordcol} = $value >= 0 ? $value : 0;
	}
	return $self->{_filerecordcol};
}

=item filenamecol( [ int $column ] )

Getter/setter for the column where the filename starts in the
current layout.

=cut

sub filenamecol {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_filenamecol} = $value >= 0 ? $value : 0;
	}
	return $self->{_filenamecol};
}

=item layoutfields( [ string $layoutfield1, ... ] )

Getter/setter for the array with layout fields.

=cut

sub layoutfields {
	my ($self, @value) = @_;
	$self->{_layoutfields} = [ @value ] if @value;
	return $self->{_layoutfields};
}

=item layoutfieldswithinfo( [ string $layoutfield1, ... ] )

Getter/setter for the array with layout fields, with the diskinfo
field included.

=cut

sub layoutfieldswithinfo {
	my ($self, @value) = @_;
	$self->{_layoutfieldswithinfo} = [ @value ] if @value;
	return $self->{_layoutfieldswithinfo};
}

=item currentlayoutline()

Getter for the string defining the layout of a file record.

=cut

sub currentlayoutline {
	my ($self) = @_;
	my $currentlayoutline = $self->{_config}{columnlayouts}->[$self->{_layout}];
	# layouts are all based on a screenwidth of 80: adjust filename field
	$currentlayoutline =~ s/n/'n' x ($self->{_screen}->screenwidth - 79)/e;
	return $currentlayoutline;
}

=item currentformatline( [ string $formatline ] )

Getter/setter for the string defining the format of a file record.

=cut

sub currentformatline {
	my ($self, $value) = @_;
	$self->{_currentformatline} = $value if defined $value;
	return $self->{_currentformatline};
}

=item currentformatlinewithinfo( [ string $formatline ] )

Getter/setter for the string defining the format of a file record,
with the diskinfo field included.

=cut

sub currentformatlinewithinfo {
	my ($self, $value) = @_;
	$self->{_currentformatlinewithinfo} = $value if defined $value;
	return $self->{_currentformatlinewithinfo};
}

=item maxfilenamelength( [ int $fieldlength ] )

Getter/setter for the length of the filename field in the current layout.

=cut

sub maxfilenamelength {
	my ($self, $value) = @_;
	$self->{_maxfilenamelength} = $value if defined $value;
	return $self->{_maxfilenamelength};
}

=item maxfilesizelength( [ int $fieldlength ] )

Getter/setter for the length of the filesize field in the current layout.

=cut

sub maxfilesizelength {
	my ($self, $value) = @_;
	$self->{_maxfilesizelength} = $value if defined $value;
	return $self->{_maxfilesizelength};
}

=item maxgrandtotallength( [ int $fieldlength ] )

Getter/setter for the length of the 'siZe' (grand total) field in the
current layout.

=cut

sub maxgrandtotallength {
	my ($self, $value) = @_;
	$self->{_maxgrandtotallength} = $value if defined $value;
	return $self->{_maxgrandtotallength};
}

##########################################################################
# public subs

=item on_after_parse_config(App::PFM::Event $event)

Applies the config settings when the config file has been read and parsed.

=cut

sub on_after_parse_config {
	my ($self, $event) = @_;
	# only now can we set _config in $self
	$self->{_config} = $event->{origin};
	$self->layout(defined($self->{_layout})
		? $self->{_layout}
		: $self->{_config}{currentlayout}
	);
	return;
}

=item highlight_off( [ int $currentline, App::PFM::File $currentfile ] )

=item highlight_on( [ int $currentline, App::PFM::File $currentfile ] )

Turns highlight on/off on the line with the cursor.

=cut

sub highlight_off {
	my ($self, @args) = @_;
	$self->_highlightline(FALSE, @args);
	return $self->{_screen};
}

sub highlight_on {
	my ($self, @args) = @_;
	$self->_highlightline(TRUE, @args);
	return $self->{_screen};
}

=item select_next_layout(bool $direction)

Switch the directory listing to the next configured layout.
If I<direction> is true, cycle forward; else backward.

=cut

sub select_next_layout {
	my ($self, $direction) = @_;
	my $result;
	if ($direction) {
		$result = $self->layout($self->{_layout} + 1);
	} else {
		$result = $self->layout($self->{_layout} - 1);
	}
	return $result;
}

=item show()

Displays the directory listing.

=cut

sub show {
	my ($self) = @_;
	my $screen    = $self->{_screen};
	my $contents  = $_pfm->state->directory->showncontents;
	my $baseindex = $_pfm->browser->baseindex;
	my $baseline  = $screen->BASELINE;
	my $file;
	foreach my $i ($baseindex .. $baseindex + $screen->screenheight) {
		$screen->at($i + $baseline - $baseindex, $self->{_filerecordcol});
		unless ($i > $#$contents) {
			$file = $$contents[$i];
			$screen->puts($self->fileline($file));
			# file manager operations may change the orphan status of
			# a symlink; therefore, update a symlink's color every time
			if ($file->{type} eq 'l') {
				$file->{color} = $file->_decidecolor();
			}
			$self->applycolor(
				$i + $baseline - $baseindex, FILENAME_SHORT, $file);
		} else {
			$screen->puts(
				' ' x ($screen->screenwidth - $screen->diskinfo->infolength));
		}
	}
	return $screen;
}

=item applycolor(int $line, bool $usemax, App::PFM::File $file
[, bool $highlight ] )

Applies color to the provided file at the provided screenline.
The I<usemax> parameter indicates if the name should be shown
entirely (true) or just the width of the filename field (false).
The I<highlight> parameter indicates if the line is currently
highlighted. For the filename to become highlighted, the config
option 'highlightname' must be 'yes' as well.

=cut

sub applycolor {
	my ($self, $line, $usemax, $file, $highlight) = @_;
	my $screen = $self->{_screen};
	my $hlcolor;
	my $maxlength = $usemax ? 255 : $self->{_maxfilenamelength} - 1;
	if ($highlight and $self->{_config}{highlightname}) {
		# this doesn't seem to work right, why?
#		$screen->putcolor($hlcolor);
		# only bold, reverse, underscore and on_* are applied
		$hlcolor =
			$self->{_config}{framecolors}{$screen->color_mode}{highlight};
		if ($hlcolor =~ /(on[ _]\w+)/) {
			$screen->putcolor($1);
		}
	}
	$screen->at($line, $self->{_filenamecol})
		->putcolored(
			$file->{color} || $hlcolor,
			substr($file->{name}, 0, $maxlength));
	return $screen;
}

=item fileline(App::PFM::File $file)

Formats the current file data according to the current layoutfields.

=cut

sub fileline {
	my ($self, $currentfile) = @_;
	return formatted(
		$self->{_currentformatline},
		@{$currentfile}{@{$self->{_layoutfields}}}
	);
}

=item get_first_valid_layout()

Gets the first layout (counting starts at the current one) that
meets all the requirements, which are:

=over 2

=item *

The fields B<n> (filename), B<f> (diskinfo) and B<*> (cursor/mark)
are mandatory.

=item *

The B<f> field (diskinfo) must be the first or the last field on
the line.

=back

=cut

sub get_first_valid_layout {
	my ($self) = @_;
	my ($miss, $error, $firstwronglayout, $currentlayoutline);
	LAYOUT: {
		$currentlayoutline = $self->currentlayoutline;
		$error = '';
		$miss =
			$currentlayoutline !~ /n/o
			? 'n'
			: $currentlayoutline !~ /f/o
			  ? 'f'
			  : $currentlayoutline !~ /\*/o
			    ? '*'
				: '';
		if ($miss) {
			$error = 'is missing';
		} elsif ($currentlayoutline !~ /(^f|f$)/o) {
			$miss = 'f';
			$error = 'should be the first or last field';
		}
		if ($error) {
			$firstwronglayout ||= $self->{_layout} || '0 but true';
			$self->{_screen}->at(0,0)->clreol()->display_error(
				"Bad layout #" . $self->{_layout} .
				": mandatory field '$miss' $error");
			$self->{_layout} = $self->_validate_layoutnum($self->{_layout}+1);
			if ($self->{_layout} != $firstwronglayout) {
				redo LAYOUT;
			} else {
				$self->{_screen}->at(0,0)->clreol()->display_error(
					"No valid layout defined in " .
					$self->{_config}->location());
				# overwrite everything
				$self->{_config}{columnlayouts} = [
					$self->{_config}->DEFAULTFORMAT
				];
				$self->{_layout} = 0;
				$currentlayoutline = $self->currentlayoutline;
			}
		}
	}
	return $currentlayoutline;
}

=item makeformatlines()

Parses the current layout line and transforms it to a perl-style
formatline which can be used with the formline() function.

=cut

sub makeformatlines {
	my ($self) = @_;
	my ($squeezedlayoutline, $prev, $trans, $temp, $infocol, $infolength,
		$maxdatetimelen, %timestampcharcount, $lendiff);
	my $currentlayoutline = $self->get_first_valid_layout();
	# determine the correct width of the timestamp fields if stretching
	# is selected.
	if ($self->{_config}{timefieldstretch}) {
		# calculate needed width (maximum needed by locale)
		$maxdatetimelen = maxdatetimelen($self->{_config}{timestampformat});
		# available field widths
		$timestampcharcount{'a'} = $currentlayoutline =~ tr/a//;
		$timestampcharcount{'c'} = $currentlayoutline =~ tr/c//;
		$timestampcharcount{'m'} = $currentlayoutline =~ tr/m//;
		for my $field (qw(a c m)) {
			# if field is present, but is too short, make adjustments
			if ($timestampcharcount{$field} and
				$maxdatetimelen > $timestampcharcount{$field}
			) {
				$lendiff = $maxdatetimelen - $timestampcharcount{$field} + 1;
				$currentlayoutline =~ s/n{$lendiff}/n/; # remove 'n'
				$currentlayoutline =~ s/$field/$field x $lendiff/e;
			}
		}
	}
	# The filename field has been adjusted in currentlayoutline(). Find out
	# the length of the filename, filesize, grand total and info fields.
	$self->{_screen}
		->diskinfo->infolength($infolength = $currentlayoutline =~ tr/f//);
	$self->{_maxfilenamelength}   = ($currentlayoutline =~ tr/n//);
	$self->{_maxfilesizelength}   = 10 ** ($currentlayoutline =~ tr/s// -1) -1;
	if ($self->{_maxfilesizelength} < 2) {
		$self->{_maxfilesizelength} = 2;
	}
	$self->{_maxgrandtotallength} = 10 ** ($currentlayoutline =~ tr/z// -1) -1;
	if ($self->{_maxgrandtotallength} < 2) {
		$self->{_maxgrandtotallength} = 2;
	}
	# provide N, S and Z fields
	# N = overflow char for name
	# S = power of 1024 for size
	# Z = power of 1024 for grand total
	$currentlayoutline =~ s/n(?!n)/N/io;
	$currentlayoutline =~ s/s(?!s)/S/io;
	$currentlayoutline =~ s/z(?!z)/Z/io;
	$currentlayoutline =~ s/(\s+)f/'_' x length($1) . 'f'/e;
	$currentlayoutline =~ s/f(\s+)/'f' . '_' x length($1)/e;
	$self->{_gaplength} = ($currentlayoutline =~ tr/_//);
	($temp = $currentlayoutline) =~ s/[^f].*//;
	$self->filerecordcol(length $temp);
	$self->cursorcol(index($currentlayoutline, '*'));
	$self->filenamecol(index($currentlayoutline, 'n'));
	$self->{_screen}
		->diskinfo->infocol($infocol = index($currentlayoutline, 'f'));
	$self->{_gapcol} = index($currentlayoutline, '_');
	# determine the layout field set (no spaces)
	($squeezedlayoutline = $currentlayoutline) =~
		tr/*nNsSzZugwhpacmdilvf_ /*nNsSzZugwhpacmdilvf_/ds;
	($self->{_layoutname} = $squeezedlayoutline) =~ s/[*SNZ]//g;
	$self->{_layoutfields}         = [
		map { LAYOUTFIELDS->{$_} } grep { !/f/ } (split //,$squeezedlayoutline)
	];
	$self->{_layoutfieldswithinfo} = [
		map { LAYOUTFIELDS->{$_} }               (split //,$squeezedlayoutline)
	];
	# make the formatline
	$self->{_currentformatlinewithinfo}	= '';
	$self->{_currentformatline}			= '';
	$prev = '';
	foreach my $letter (split //, $currentlayoutline) {
		if ($letter eq ' ') {
			$self->{_currentformatlinewithinfo} .= ' ';
		} elsif ($prev ne $letter) {
			$self->{_currentformatlinewithinfo} .= '@';
		} else {
			($trans = $letter) =~ tr{*nNsSzZugwhpacmdilvf_}
									{<<<><><<<>><<<<<>><<<};
			$self->{_currentformatlinewithinfo} .= $trans;
		}
		$prev = $letter;
	}
	$self->{_currentformatline} = $self->{_currentformatlinewithinfo};
	substr($self->{_currentformatline}, $infocol, $infolength, '');
	$self->fire(App::PFM::Event->new({
		name   => 'after_change_formatlines',
		type   => 'soft',
		origin => $self,
	}));
	return $self->{_currentformatline};
}

=item markcurrentline(string $letter)

Shows the current command letter on the current file in the cursor column.

=cut

sub markcurrentline {
	my ($self, $letter) = @_;
	$self->{_screen}->at(
			$_pfm->browser->currentline + $self->{_screen}->BASELINE,
			$self->{_cursorcol})
		->puts($letter);
	return $self->{_screen};
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
