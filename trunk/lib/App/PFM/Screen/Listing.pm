#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen::Listing 1.07
#
# Name:			App::PFM::Screen::Listing
# Version:		1.07
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-13
#

##########################################################################

=pod

=head1 NAME

App::PFM::Screen::Listing

=head1 DESCRIPTION

PFM class for displaying a App::PFM::Directory object on the screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Screen::Listing;

use base 'App::PFM::Abstract';

use App::PFM::Util qw(formatted);

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
	'*' => 'selected',
	'n' => 'display',
	'N' => 'name_too_long',
	's' => 'size_num',
	'S' => 'size_power',
	'z' => 'grand_num',
	'Z' => 'grand_power',
	'u' => 'uid',
	'g' => 'gid',
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

use constant FILETYPEFLAGS => {
	 # ls(1)
	 x => '*',
	 d => '/',
	 l => '@',
	 p => '|',
	's'=> '=',
	 D => '>',
	 w => '%',
	 # tcsh(1)
	 b => '#',
	 c => '%',
	 n => ':',
	 # => '+', # Hidden directory (AIX only) or context dependent (HP-UX only)
};

our ($_pfm, $_screen);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm, App::PFM::Screen $screen)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen) = @_;
	$_pfm    = $pfm;
	$_screen = $screen;
	$self->{_layout}               = 0;
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
}

=item _validate_layoutnum(int $layoutnr)

Checks if the layout number does not exceed the total number of layouts.

=cut

sub _validate_layoutnum {
	my ($self, $num) = @_;
	my $columnlayouts = $_pfm->config->{columnlayouts};
	while ($num > $#$columnlayouts) {
		$num -= @$columnlayouts;
	}
	return $num;
}

=item _highlightline(bool $onoff [, int $currentline,
App::PFM::File $currentfile ] )

Turns highlight on/off on the line with the cursor.

=cut

sub _highlightline {
	my ($self, $onoff, $currentline, $currentfile) = @_;
	$currentfile  ||= $_pfm->browser->currentfile;
	my $screenline  = $currentline || $_pfm->browser->currentline;
	$screenline    += $_screen->BASELINE;
	my $linecolor;
	$_screen->at($screenline, $self->{_filerecordcol});
	if ($onoff) {
		$linecolor =
			$_pfm->config->{framecolors}{$_screen->color_mode}{highlight};
		# in case colorizable() is off:
		$_screen->bold()		if ($linecolor =~ /bold/);
		$_screen->reverse()		if ($linecolor =~ /reverse/);
#		$_screen->underline()	if ($linecolor =~ /under(line|score)/);
		$_screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	}
	$_screen->putcolored($linecolor, $self->fileline($currentfile));
	$self->applycolor($screenline, FILENAME_SHORT, $currentfile, $onoff);
	$_screen->reset()->normal()->at($screenline, $self->{_cursorcol});
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
		$self->reformat();
		$_screen->set_deferred_refresh($_screen->R_SCREEN);
	}
	return $self->{_layout};
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
	my $currentlayoutline = $_pfm->config->{columnlayouts}->[$self->{_layout}];
	$currentlayoutline =~ s/n/'n' x ($_screen->screenwidth - 79)/e;
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

=item highlight_off( [ int $currentline, App::PFM::File $currentfile ] )

=item highlight_on( [ int $currentline, App::PFM::File $currentfile ] )

Turns highlight on/off on the line with the cursor.

=cut

sub highlight_off {
	my ($self, @args) = @_;
	$self->_highlightline(FALSE, @args);
}

sub highlight_on {
	my ($self, @args) = @_;
	$self->_highlightline(TRUE, @args);
}

=item select_next_layout()

Switch the directory listing to the next configured layout.

=cut

sub select_next_layout {
	my ($self) = @_;
	return $self->layout($self->{_layout} + 1);
}

=item show()

Displays the directory listing.

=cut

sub show {
	my ($self) = @_;
	my $contents  = $_pfm->state->directory->showncontents;
	my $baseindex = $_pfm->browser->baseindex;
	my $baseline  = $_screen->BASELINE;
	my $file;
	foreach my $i ($baseindex .. $baseindex+$_screen->screenheight) {
		$_screen->at($i+$baseline-$baseindex, $self->{_filerecordcol});
		unless ($i > $#$contents) {
			$file = $$contents[$i];
			$_screen->puts($self->fileline($file));
			# file manager operations may change the orphan status of
			# a symlink; therefore, update a symlink's color every time
			if ($file->{type} eq 'l') {
				$file->{color} = $file->_decidecolor();
			}
			$self->applycolor(
				$i + $baseline - $baseindex, FILENAME_SHORT, $file);
		} else {
			$_screen->puts(
				' 'x($_screen->screenwidth - $_screen->diskinfo->infolength));
		}
	}
	return $_screen;
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
	my $linecolor;
	my $maxlength = $usemax ? 255 : $self->{_maxfilenamelength} - 1;
	if ($highlight and $_pfm->config->{highlightname}) {
		# only bold, reverse and underscore are copied
		$linecolor =
			$_pfm->config->{framecolors}{$_screen->color_mode}{highlight};
		$_screen->bold()		if ($linecolor =~ /bold/);
		$_screen->reverse()		if ($linecolor =~ /reverse/);
#		$_screen->underline()	if ($linecolor =~ /under(line|score)/);
		$_screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	}
	$_screen->at($line, $self->{_filenamecol})
		->putcolored(
			$file->{color} || $linecolor,
			substr($file->{name}, 0, $maxlength));
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

=item makeformatlines()

Parses the configured layouts.

=cut

sub makeformatlines {
	my ($self) = @_;
	my ($squeezedlayoutline, $currentlayoutline, $firstwronglayout, $prev,
		$letter, $trans, $temp, $infocol, $infolength, $miss, $error);
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
			$_screen->at(0,0)->clreol()->display_error(
				"Bad layout #" . $self->{_layout} .
				": mandatory field '$miss' $error");
			$_screen->important_delay();
			$self->{_layout} = $self->_validate_layoutnum($self->{_layout}+1);
			if ($self->{_layout} != $firstwronglayout) {
				redo LAYOUT;
			} else {
				$_screen
					->alternate_off()
					->clrscr()->at(0,0)
					->cooked_echo()
					->mouse_disable();
				die "No valid layout defined in " .
					$_pfm->config->location() . "\n";
			}
		}
	}
	# layouts are all based on a screenwidth of 80: elongate filename field
#	$currentlayoutline =~ s/n/'n' x ($_screen->screenwidth - 79)/e;
	# find out the length of the filename, filesize, grand total and info fields
	$infolength =
	$_screen->diskinfo->infolength($infolength = $currentlayoutline =~ tr/f//);
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
	$_screen->diskinfo->infocol($infocol = index($currentlayoutline, 'f'));
	$self->{_gapcol}	= index($currentlayoutline, '_');
	# determine the layout field set (no spaces)
	($squeezedlayoutline = $currentlayoutline) =~
		tr/*nNsSzZugpacmdilvf_ /*nNsSzZugpacmdilvf_/ds;
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
	foreach $letter (split //, $currentlayoutline) {
		if ($letter eq ' ') {
			$self->{_currentformatlinewithinfo} .= ' ';
		} elsif ($prev ne $letter) {
			$self->{_currentformatlinewithinfo} .= '@';
		} else {
			($trans = $letter) =~ tr{*nNsSzZugpacmdilvf_}
									{<<<><><<<<<<<<>><<<};
			$self->{_currentformatlinewithinfo} .= $trans;
		}
		$prev = $letter;
	}
	$self->{_currentformatline} = $self->{_currentformatlinewithinfo};
	substr($self->{_currentformatline}, $infocol, $infolength, '');
	return $self->{_currentformatline};
}

=item markcurrentline(string $letter)

Shows the current command letter on the current file in the cursor column.

=cut

sub markcurrentline {
	my ($self, $letter) = @_;
	$_screen->at(
			$_pfm->browser->currentline + $_screen->BASELINE,
			$self->{_cursorcol})
		->puts($letter);
}

=item reformat()

Adjusts the visual representation of the directory contents according
to the new layout.

=cut

sub reformat {
	my ($self)      = @_;
	my $directory   = $_pfm->state->directory;
	my $dircontents = $directory->dircontents;
	return unless @$dircontents; # may not have been initialized yet
	foreach (@$dircontents) {
		$_->format();
	}
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
