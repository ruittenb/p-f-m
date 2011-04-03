#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Frame 2010-03-27 v0.01
#
# Name:			PFM::Screen::Frame.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	Subclass of PFM::Screen, used for drawing a frame
#				(header, footer and column headings)
#

##########################################################################
# declarations

package PFM::Screen::Frame;

use constant {
	HEADER_SINGLE	=> 0,
	HEADER_MULTI	=> 1,
	HEADER_MORE		=> 2,
	HEADER_SORT		=> 4,
	HEADER_INCLUDE	=> 8,
	HEADER_LNKTYPE	=> 16,
	TITLE_DISKINFO	=> 0,
	TITLE_YCOMMAND	=> 1,
	TITLE_SIGNAL	=> 2,
	TITLE_SORT		=> 3,
	TITLE_ESCAPE	=> 4,
};

#my ();

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
}

sub _fitbanner { # $header/footer, $screenwidth
	my ($banner, $virtwidth) = @_;
	my ($maxwidth, $spcount);
	if (length($banner) > $virtwidth) {
		$spcount  = maxpan($banner, $virtwidth);
		$maxwidth = $virtwidth -2*($currentpan > 0) -2*($currentpan < $spcount);
		$banner  .= ' ';
		eval "
			\$banner =~ s/^(?:\\S+ ){$currentpan,}?(.{1,$maxwidth}) .*/\$1/;
		";
		if ($currentpan > 0       ) { $banner  = '< ' . $banner; }
		if ($currentpan < $spcount) { $banner .= ' >'; }
	}
	return $banner;
}

sub _getheader {
	my ($self, $mode) = @_;
	# do not take multiple mode into account at all
	if		($mode & $HEADER_SORT) {
		return	'Sort by: Name, Extension, Size, Date, Type, Inode '
		.		'(ignorecase, reverse):';
	} elsif ($mode & $HEADER_MORE) {
		return	'Bookmark Config Edit-new mkFifo sHell Kill-chld Mkdir '
		.		'Physical-path Show-dir sVn Write-hist alTscreen';
	} elsif ($mode & $HEADER_INCLUDE) {
		return	'Include? Every, Oldmarks, After, Before, User or Files only:';
	} elsif ($mode & $HEADER_LNKTYPE) {
		return	'Absolute, Relative symlink or Hard link:';
	} else {
		return	'Attribute Copy Delete Edit Find tarGet Include Link More Name'
		.		' cOmmand Print Quit Rename Show Time User sVn unWhiteout'
		.		' eXclude Your-command siZe';
	}
}

sub _getfooter {
	return	"F1-Help F2-Back F3-Redraw F4-Color[$color_mode]"
	.		" F5-Reread F6-Sort[$sort_mode] F7-Swap[$ONOFF{$swap_mode}]"
	.		" F8-Include F9-Layout[$currentlayout]" # $formatname ?
	.		" F10-Multiple[$ONOFF{$multiple_mode}]"
	.		" F11-Restat F12-Mouse[$ONOFF{$mouse_mode}]"
	.		" !-Clobber[$ONOFF{$clobber_mode}]"
	.		" .-Dotfiles[$ONOFF{$dot_mode}]"
	.		($white_cmd ? " %-Whiteouts[$ONOFF{$white_mode}]" : '')
	.		" \"-Pathnames[$path_mode]"
	.		" *-Radix[$radix_mode]"
#	.		" =-Ident"
	;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

sub draw {
	my ($self, $pfm) = @_;
	$self->draw_header($pfm);
	$self->draw_title($swap_mode, TITLE_DISKINFO, @layoutfieldswithinfo);
	$self->draw_footer();
	return $self;
}

sub draw_title { # swap_mode, extra field, @layoutfieldswithinfo
	my ($smode, $info, @fields) = @_;
	my $linecolor;
	for ($info) {
		$_ == $TITLE_DISKINFO	and $FIELDHEADINGS{diskinfo} = ' ' x ($infolength-14) . '     disk info';
		$_ == $TITLE_SORT		and $FIELDHEADINGS{diskinfo} = 'sort mode     ' . ' ' x ($infolength-14);
		$_ == $TITLE_SIGNAL		and $FIELDHEADINGS{diskinfo} = '  nr signal   ' . ' ' x ($infolength-14);
		$_ == $TITLE_YCOMMAND	and $FIELDHEADINGS{diskinfo} = 'your commands ' . ' ' x ($infolength-14);
		$_ == $TITLE_ESCAPE		and $FIELDHEADINGS{diskinfo} = 'esc legend    ' . ' ' x ($infolength-14);
	}
#	$FIELDHEADINGS{display} = $FIELDHEADINGS{name} . ' (' . $sort_mode . ('%','')[$white_mode] . ('.','')[$dot_mode] . ')';
	$linecolor = $smode ? $framecolors{$color_mode}{swap}
						: $framecolors{$color_mode}{title};
	$scr->bold()		if ($linecolor =~ /bold/);
	$scr->reverse()		if ($linecolor =~ /reverse/);
#	$scr->underline()	if ($linecolor =~ /under(line|score)/);
	$scr->term()->Tputs('us', 1, *STDOUT)
						if ($linecolor =~ /under(line|score)/);
	$scr->at(2,0)
		->putcolored($linecolor, formatted($currentformatlinewithinfo, @FIELDHEADINGS{@fields}))
		->reset()->normal();
}

sub draw_header { # <special header mode>
	my ($self, $pfm, $mode) = @_;
	my $mode ||= ($multiple_mode * $HEADER_MULTI);
	my $domulti = $mode & $HEADER_MULTI;
	my ($pos, $header, $headerlength, $vscreenwidth);
	$vscreenwidth = $screenwidth - 9 * $domulti;
	$header       = $self->_fitbanner($self->_getheader($mode), $vscreenwidth);
	$headerlength = length($header);
	if ($headerlength < $vscreenwidth) {
		$header .= ' ' x ($vscreenwidth - $headerlength);
	}
	$scr->at(0,0);
	if ($domulti) {
		$scr->putcolored($framecolors{$color_mode}{multi}, 'Multiple');
	}
	$scr->color($framecolors{$color_mode}{header})->puts(' ' x $domulti)->puts($header)->bold();
	while ($header =~ /[[:upper:]<>](?!nclude\?)/g) {
		$pos = pos($header) -1;
		$scr->at(0, $pos + 9 * $domulti)->puts(substr($header, $pos, 1));
	}
	$scr->reset()->normal();
	return $headerlength;
}

sub draw_footer {
	my $footer = $self->_fitbanner(footer(), $screenwidth);
	my $linecolor;
	$linecolor = $framecolors{$color_mode}{footer};
	$scr->bold()		if ($linecolor =~ /bold/);
	$scr->reverse()		if ($linecolor =~ /reverse/);
#	$scr->underline()	if ($linecolor =~ /under(line|score)/);
	$scr->term()->Tputs('us', 1, *STDOUT)
						if ($linecolor =~ /under(line|score)/);
	$scr->at($BASELINE+$screenheight+1,0)
		->putcolored($linecolor, $footer, ' ' x ($screenwidth - length $footer))
		->reset()->normal();
}
##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
