#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen::Listing 0.14
#
# Name:			PFM::Screen::Listing.pm
# Version:		0.14
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-10
#

##########################################################################

=pod

=head1 NAME

PFM::Screen::Listing

=head1 DESCRIPTION

PFM class for displaying a PFM::Directory object on the screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Screen::Listing;

use base 'PFM::Abstract';

use PFM::Util;

use locale;
use strict;

use constant {
	NAMETOOLONGCHAR => '+',
	HIGHLIGHT_OFF	=> 0,
	HIGHLIGHT_ON	=> 1,
	FILENAME_SHORT	=> 0,
	FILENAME_LONG	=> 1,
};

my %LAYOUTFIELDS = (
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
	'v' => 'svn',
	'f' => 'diskinfo',
);

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
	 # => '+', # Hidden directory (AIX only) or context dependent (HP/UX only)
};

my ($_pfm, $_screen,
	$_layout, $_cursorcol, @_layoutfields, @_layoutfieldswithinfo,
	$_filerecordcol, $_filenamecol,
	$_maxfilenamelength, $_maxfilesizelength, $_maxgrandtotallength,
	$_currentformatline, $_currentformatlinewithinfo,
	$_formatname,
);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen) = @_;
	$_pfm    = $pfm;
	$_screen = $screen;
}

=item _validate_layoutnum()

Checks if the configuration contains a valid layout with the given number.

=cut

sub _validate_layoutnum {
	my ($self, $num) = @_;
	my $columnlayouts = $_pfm->config->{columnlayouts};
	while ($num > $#$columnlayouts) {
		$num -= @$columnlayouts;
	}
	return $num;
}

=item _highlightline()

Turns highlight on/off on the line with the cursor.

=cut

sub _highlightline {
	my ($self, $on) = @_;
	my $screenline  = $_pfm->browser->currentline + $_screen->BASELINE;
	my $currentfile = $_pfm->browser->currentfile;
	my $linecolor;
	$_screen->at($screenline, $_filerecordcol);
	if ($on == HIGHLIGHT_ON) {
		$linecolor =
			$_pfm->config->{framecolors}{$_screen->color_mode}{highlight};
#		$_screen->bold()		if ($linecolor =~ /bold/);
#		$_screen->reverse()		if ($linecolor =~ /reverse/);
#		$_screen->underline()	if ($linecolor =~ /under(line|score)/);
		$_screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	}
	$_screen->putcolored($linecolor, $self->fileline($currentfile));
	$self->applycolor($screenline, FILENAME_SHORT, $currentfile);
	$_screen->reset()->normal()->at($screenline, $_cursorcol);
}

=item _decidecolor()

Decides which color should be used on a particular file.

=cut

sub _decidecolor {
	my $self =  $_[0];
	my %f   = %{$_[1]};
	my %dircolors  = %{$_pfm->config->{dircolors}{$_screen->color_mode}};
	$f{type}  eq 'w'			and return $dircolors{wh};
	$f{nlink} ==  0 			and return $dircolors{lo};
	$f{type}  eq 'd'			and return $dircolors{di};
	$f{type}  eq 'l'			and return $dircolors{
										isorphan($f{name}) ?'or':'ln' };
	$f{type}  eq 'b'			and return $dircolors{bd};
	$f{type}  eq 'c'			and return $dircolors{cd};
	$f{type}  eq 'p'			and return $dircolors{pi};
	$f{type}  eq 's'			and return $dircolors{so};
	$f{type}  eq 'D'			and return $dircolors{'do'};
	$f{type}  eq 'n'			and return $dircolors{nt};
	$f{mode}  =~ /[xst]/		and return $dircolors{ex};
	$f{name}  =~ /(\.\w+)$/		and return $dircolors{$1};
}

##########################################################################
# constructor, getters and setters

=item layout()

Getter/setter for the current layout number. If this is called to set
the current layout, it will do all the necessary changes.

=cut

sub layout {
	my ($self, $value) = @_;
	if (defined $value) {
		$_layout = $self->_validate_layoutnum($value);
		$self->makeformatlines();
		$self->reformat();
		$_screen->set_deferred_refresh($_screen->R_SCREEN);
	}
	return $_layout;
}

=item cursorcol()

Getter/setter for the column of the cursor in the current layout.

=cut

sub cursorcol {
	my ($self, $value) = @_;
	if (defined $value) {
		$_cursorcol = $value >= 0 ? $value : 0;
	}
	return $_cursorcol;
}

=item filerecordcol()

Getter/setter for the column of the file record in the current layout.

=cut

sub filerecordcol {
	my ($self, $value) = @_;
	if (defined $value) {
		$_filerecordcol = $value >= 0 ? $value : 0;
	}
	return $_filerecordcol;
}

=item filenamecol()

Getter/setter for the column of the filename in the current layout.

=cut

sub filenamecol {
	my ($self, $value) = @_;
	if (defined $value) {
		$_filenamecol = $value >= 0 ? $value : 0;
	}
	return $_filenamecol;
}

=item layoutfields()

Getter/setter for the array with layout fields.

=cut

sub layoutfields {
	my ($self, @value) = @_;
	@_layoutfields = @value if @value;
	return \@_layoutfields;
}

=item layoutfieldswithinfo()

Getter/setter for the array with layout fields, with the diskinfo
field included.

=cut

sub layoutfieldswithinfo {
	my ($self, @value) = @_;
	@_layoutfieldswithinfo = @value if @value;
	return \@_layoutfieldswithinfo;
}

=item currentformatline()

Getter/setter for the string defining the format of a file record.

=cut

sub currentformatline {
	my ($self, $value) = @_;
	$_currentformatline = $value if defined $value;
	return $_currentformatline;
}

=item currentformatlinewithinfo()

Getter/setter for the string defining the format of a file record,
with the diskinfo field included.

=cut

sub currentformatlinewithinfo {
	my ($self, $value) = @_;
	$_currentformatlinewithinfo = $value if defined $value;
	return $_currentformatlinewithinfo;
}

=item maxfilenamelength()

Getter/setter for the length of the filename field in the current layout.

=cut

sub maxfilenamelength {
	my ($self, $value) = @_;
	$_maxfilenamelength = $value if defined $value;
	return $_maxfilenamelength;
}

=item maxfilesizelength()

Getter/setter for the length of the filesize field in the current layout.

=cut

sub maxfilesizelength {
	my ($self, $value) = @_;
	$_maxfilesizelength = $value if defined $value;
	return $_maxfilesizelength;
}

=item maxgrandtotallength()

Getter/setter for the length of the 'siZe' (grand total) field in the
current layout.

=cut

sub maxgrandtotallength {
	my ($self, $value) = @_;
	$_maxgrandtotallength = $value if defined $value;
	return $_maxgrandtotallength;
}

##########################################################################
# public subs

=item highlight_off()

=item highlight_on()

Turns highlight on/off on the line with the cursor.

=cut

sub highlight_off() {
	$_[0]->_highlightline(HIGHLIGHT_OFF);
}

sub highlight_on() {
	$_[0]->_highlightline(HIGHLIGHT_ON);
}

=item select_next_layout()

Switch the directory listing to the next configured layout.

=cut

sub select_next_layout {
	return $_[0]->layout($_layout + 1);
}

=item show()

Displays the directory listing.

=cut

sub show {
	my $self = shift;
	my $contents  = $_pfm->state->directory->showncontents;
	my $baseindex = $_pfm->browser->baseindex;
	my $baseline  = $_screen->BASELINE;
	foreach my $i ($baseindex .. $baseindex+$_screen->screenheight) {
		$_screen->at($i+$baseline-$baseindex, $_filerecordcol);
		unless ($i > $#$contents) {
			$_screen->puts($self->fileline($$contents[$i]));
			$self->applycolor(
				$i+$baseline-$baseindex, FILENAME_SHORT, $$contents[$i]);
		} else {
			$_screen->puts(
				' 'x($_screen->screenwidth - $_screen->diskinfo->infolength));
		}
	}
}

=item applycolor()

Applies color to the current file line.

=cut

sub applycolor {
	my ($self, $line, $usemax, $fileref) = @_;
	my $maxlength = $usemax ? 255 : $_maxfilenamelength-1;
	$_screen->at($line, $_filenamecol)
		->putcolored(
			$self->_decidecolor($fileref),
			substr($fileref->{name}, 0, $maxlength));
}

=item fileline()

Formats the current file data according to the current layoutfields.

=cut

sub fileline {
	my ($self, $currentfile) = @_;
	return formatted($_currentformatline, @{$currentfile}{@_layoutfields});
}

=item makeformatlines()

Parses the configured layouts.

=cut

sub makeformatlines {
	my $self = shift;
	my ($squeezedlayoutline, $currentlayoutline, $firstwronglayout, $prev,
		$letter, $trans, $temp, $infocol, $infolength);
	my $columnlayouts = $_pfm->config->{columnlayouts};
	LAYOUT: {
		$currentlayoutline = $columnlayouts->[$self->_validate_layoutnum()];
		unless ($currentlayoutline =~ /n/o
		    and $currentlayoutline =~ /(^f|f$)/o
			and $currentlayoutline =~ /\*/o)
		{
			$firstwronglayout ||= $_layout || '0 but true';
			$_screen->at(0,0)->clreol()
				->display_error(
					"Bad layout #$_layout: a mandatory field is missing")
				->important_delay();
			$_layout++;
			if ($self->_validate_layoutnum() != $firstwronglayout) {
				redo LAYOUT;
			} else {
				$_screen
					->alternate_off()
					->clrscr()->at(0,0)
				    ->puts("Fatal error: No valid layout defined in "
						. $_pfm->config->give_location())
					->at(1,0)
					->stty_cooked()
					->mouse_disable();
				exit 2;
			}
		}
	}
	# layouts are all based on a screenwidth of 80: elongate filename field
	$currentlayoutline =~ s/n/'n' x ($_screen->screenwidth - 79)/e;
	# find out the length of the filename, filesize, grand total and info fields
	$infolength =
	$_screen->diskinfo->infolength($infolength = $currentlayoutline =~ tr/f//);
	$_maxfilenamelength =           ($currentlayoutline =~ tr/n//);
	$_maxfilesizelength =     10 ** ($currentlayoutline =~ tr/s// -1) -1;
	if ($_maxfilesizelength < 2)   { $_maxfilesizelength = 2 }
	$_maxgrandtotallength =   10 ** ($currentlayoutline =~ tr/z// -1) -1;
	if ($_maxgrandtotallength < 2) { $_maxgrandtotallength = 2 }
	# provide N, S and Z fields
	# N = overflow char for name
	# S = power of 1024 for size
	# Z = power of 1024 for grand total
	$currentlayoutline =~ s/n(?!n)/N/io;
	$currentlayoutline =~ s/s(?!s)/S/io;
	$currentlayoutline =~ s/z(?!z)/Z/io;
#	$currentlayoutline =~ s/(\s+)f/'F'x length($1) . 'f'/e;
#	$currentlayoutline =~ s/f(\s+)/'f' . 'F'x length($1)/e;
#	$gaplength = 
	($temp = $currentlayoutline) =~ s/[^f].*//;
	$self->filerecordcol(length $temp);
	$self->cursorcol(index($currentlayoutline, '*'));
	$self->filenamecol(index($currentlayoutline, 'n'));
	$_screen->diskinfo->infocol($infocol = index($currentlayoutline, 'f'));
#	$gapcol			= index($currentlayoutline, 'F');
	# determine the layout field set (no spaces)
	($squeezedlayoutline = $currentlayoutline) =~
		tr/*nNsSzZugpacmdilvf /*nNsSzZugpacmdilvf/ds;
	($_formatname = $squeezedlayoutline) =~ s/[*SNZ]//g;
	@_layoutfields         = map { $LAYOUTFIELDS{$_} } grep { !/f/ } (split //, $squeezedlayoutline);
	@_layoutfieldswithinfo = map { $LAYOUTFIELDS{$_} }               (split //, $squeezedlayoutline);
	# make the formatline
	$_currentformatlinewithinfo = $_currentformatline = $prev = '';
	foreach $letter (split //, $currentlayoutline) {
		if ($letter eq ' ') {
			$_currentformatlinewithinfo .= ' ';
		} elsif ($prev ne $letter) {
			$_currentformatlinewithinfo .= '@';
		} else {
			($trans = $letter) =~ tr{*nNsSzZugpacmdilvf}
									{<<<><><<<<<<<<>><<};
			$_currentformatlinewithinfo .= $trans;
		}
		$prev = $letter;
	}
	$_currentformatline = $_currentformatlinewithinfo;
	substr($_currentformatline, $infocol, $infolength, '');
	return $_currentformatline;
}

=item markcurrentline()

Shows the current command on the current file in the cursor column.

=cut

sub markcurrentline {
	my ($self, $letter) = @_;
	$_screen->at($_pfm->browser->currentline + $_screen->BASELINE, $_cursorcol)
		->puts($letter);
}

=item reformat()

Adjusts the visual representation of the directory contents according
to the new layout.

=cut

sub reformat {
#	my $self = shift;
	my $directory = $_pfm->state->directory;
	my $dircontents = $directory->dircontents;
	return unless @$dircontents; # may not have been initialized yet
	foreach (@$dircontents) {
		$_->{name_too_long} = length($_->{display}) > $_maxfilenamelength-1
			? NAMETOOLONGCHAR : ' ';
		unless ($_->{type} =~ /[bc]/) {
			@{$_}{qw(size_num size_power)} =
				fit2limit($_->{size}, $_maxfilesizelength);
		}
		@{$_}{qw(grand_num grand_power)} =
			fit2limit($_->{grand}, $_maxgrandtotallength);
		@{$_}{qw(atimestr ctimestr mtimestr)} =
			map { $directory->stamp2str($_) } @{$_}{qw(atime ctime mtime)};
	}
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
