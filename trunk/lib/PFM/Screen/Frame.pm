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
#				(menubar, footer and column headings)
#

##########################################################################
# declarations

package PFM::Screen::Frame;

use constant {
	MENU_SINGLE			=> 0,
	MENU_MULTI			=> 1,
	MENU_MORE			=> 2,
	MENU_SORT			=> 4,
	MENU_INCLUDE		=> 8,
	MENU_LNKTYPE		=> 16,
	HEADING_DISKINFO	=> 0,
	HEADING_YCOMMAND	=> 1,
	HEADING_SIGNAL		=> 2,
	HEADING_SORT		=> 3,
	HEADING_ESCAPE		=> 4,
};

my %ONOFF = ('' => 'off', 0 => 'off', 1 => 'on');

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my $self = shift;
}

=item _maxpan()

Determines how many times a banner (menu or footer) can be panned.

=cut

sub _maxpan {
	my ($self, $temp, $width) = @_;
	my $panspace;
	# this is an assignment on purpose
	if ($panspace = 2 * (length($temp) > $width)) {
		eval "
			\$temp =~ s/^((?:\\S+ )+?).{1,".($width - $panspace)."}\$/\$1/;
		";
		return $temp =~ tr/ //;
	} else {
		return 0;
	};
}

sub handlepan {
	my ($key, $mode) = @_;
	my $width = $screenwidth - 9 * $multiple_mode;
	my $count   = max(
		$self->_maxpan(header($mode), $width),
		$self->_maxpan(footer(), $width)
	);
	$currentpan = $currentpan - ($key =~ /</ and $currentpan > 0)
							  + ($key =~ />/ and $currentpan < $count);
	return $R_HEADER | $R_FOOTER;
}



=item _fitbanner()

Chops off part of the "banner" (menu or footer), so that its width
will fit on the screen.

=cut

sub _fitbanner {
	my ($self, $banner, $virtwidth) = @_;
	my ($maxwidth, $spcount);
	if (length($banner) > $virtwidth) {
#		$spcount  = maxpan($banner, $virtwidth);
#		$maxwidth = $virtwidth -2*($currentpan > 0) -2*($currentpan < $spcount);
#		$banner  .= ' ';
#		eval "
#			\$banner =~ s/^(?:\\S+ ){$currentpan,}?(.{1,$maxwidth}) .*/\$1/;
#		";
#		if ($currentpan > 0       ) { $banner  = '< ' . $banner; }
#		if ($currentpan < $spcount) { $banner .= ' >'; }
	}
	return $banner;
}

=item _getmenu()

Returns the menu for the current application mode.

=cut

sub _getmenu {
	my ($self, $mode) = @_;
	# do not take multiple mode into account at all
	if		($mode & MENU_SORT) {
		return	'Sort by: Name, Extension, Size, Date, Type, Inode '
		.		'(ignorecase, reverse):';
	} elsif ($mode & MENU_MORE) {
		return	'Bookmark Config Edit-new mkFifo sHell Kill-chld Mkdir '
		.		'Physical-path Show-dir sVn Write-hist alTscreen';
	} elsif ($mode & MENU_INCLUDE) {
		return	'Include? Every, Oldmarks, After, Before, User or Files only:';
	} elsif ($mode & MENU_LNKTYPE) {
		return	'Absolute, Relative symlink or Hard link:';
	} else {
		return	'Attribute Copy Delete Edit Find tarGet Include Link More Name'
		.		' cOmmand Print Quit Rename Show Time User sVn unWhiteout'
		.		' eXclude Your-command siZe';
	}
}

=item _getfooter()

Returns the footer for the current application state.

=cut

sub _getfooter {
	my ($self, $pfm) = @_;
	my %state = %{$pfm->state};
	return sprintf(
		'F1-Help F2-Back F3-Redraw F4-Color[%s] F5-Reread F6-Sort[%s]'
	.	' F7-Swap[%s] F8-Include F9-Layout[%s] F10-Multiple[%s]'
	.	' F11-Restat F12-Mouse[%s] !-Clobber[%s] .-Dotfiles[%s]%s'
	.	' "-Pathnames[%s] *-Radix[%s]',
		$state{color_mode},
		$state{sort_mode},
		$ONOFF{$state{swap_mode}},
		$state{currentlayout},
		$ONOFF{$state{multiple_mode}},
		$ONOFF{$state{mouse_mode}},
		$ONOFF{$state{clobber_mode}},
		$ONOFF{$state{dot_mode}},
	 	($white_cmd ? " %-Whiteouts[$ONOFF{$state{white_mode}}]" : ''),
		$state{path_mode},
		$state{radix_mode},
	);
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item draw()

Draws menu, footer and headings.

=cut

sub draw {
	my ($self, $pfm) = @_;
	$self->draw_menu($pfm);
	$self->draw_headings($swap_mode, HEADING_DISKINFO, @layoutfieldswithinfo);
	$self->draw_footer($pfm);
	return $self;
}

=item draw_menu()

Draws the menu, i.e., the top line on the screen.

=cut

sub draw_menu {
	my ($self, $pfm, $mode) = @_;
	my ($pos, $menu, $menulength, $vscreenwidth, $color, $do_multi);
	$mode ||= ($pfm->state->{multiple_mode} * MENU_MULTI);
	$do_multi = $mode & MENU_MULTI;
	$vscreenwidth = $pfm->screen->screenwidth - 9 * $do_multi;
	$menu         = $self->_fitbanner($self->_getmenu($mode), $vscreenwidth);
	$menulength   = length($menu);
	if ($menulength < $vscreenwidth) {
		$menu .= ' ' x ($vscreenwidth - $menulength);
	}
	$pfm->screen->at(0,0);
	if ($do_multi) {
		$color = $pfm->config->{framecolors}{$pfm->state->color_mode}{multi};
		$pfm->screen->putcolored($color, 'Multiple');
	}
	$color = $pfm->config->{framecolors}{$pfm->state->color_mode}{menu};
	$pfm->screen->color($color)->puts(' ' x $do_multi)->puts($menu)->bold();
	while ($menu =~ /[[:upper:]<>](?!nclude\?)/g) {
		$pos = pos($menu) -1;
		$pfm->screen->at(0, $pos + 9*$do_multi)->puts(substr($menu, $pos, 1));
	}
	$pfm->screen->reset()->normal();
	return $menulength;
}

=item draw_headings()

Draws the column headings.

=cut

sub draw_headings { # swap_mode, extra field, @layoutfieldswithinfo
	my ($smode, $info, @fields) = @_;
	my $linecolor;
#	for ($info) {
#		$_ == $HEADING_DISKINFO	and $FIELDHEADINGS{diskinfo} = ' ' x ($infolength-14) . '     disk info';
#		$_ == $HEADING_SORT		and $FIELDHEADINGS{diskinfo} = 'sort mode     ' . ' ' x ($infolength-14);
#		$_ == $HEADING_SIGNAL		and $FIELDHEADINGS{diskinfo} = '  nr signal   ' . ' ' x ($infolength-14);
#		$_ == $HEADING_YCOMMAND	and $FIELDHEADINGS{diskinfo} = 'your commands ' . ' ' x ($infolength-14);
#		$_ == $HEADING_ESCAPE		and $FIELDHEADINGS{diskinfo} = 'esc legend    ' . ' ' x ($infolength-14);
#	}
##	$FIELDHEADINGS{display} = $FIELDHEADINGS{name} . ' (' . $sort_mode . ('%','')[$white_mode] . ('.','')[$dot_mode] . ')';
#	$linecolor = $smode ? $framecolors{$color_mode}{swap}
#						: $framecolors{$color_mode}{headings};
#	$scr->bold()		if ($linecolor =~ /bold/);
#	$scr->reverse()		if ($linecolor =~ /reverse/);
##	$scr->underline()	if ($linecolor =~ /under(line|score)/);
#	$scr->term()->Tputs('us', 1, *STDOUT)
#						if ($linecolor =~ /under(line|score)/);
#	$scr->at(2,0)
#		->putcolored($linecolor, formatted($currentformatlinewithinfo, @FIELDHEADINGS{@fields}))
#		->reset()->normal();
}

=item draw_footer()

Draws the footer, i.e. the last line on screen with the status info.

=cut

sub draw_footer {
	my ($self, $pfm) = @_;
	my $screen = $pfm->screen;
	my $screenwidth = $screen->screenwidth;
	my $footer = $self->_fitbanner($self->_getfooter(), $screenwidth);
	my $padding = ' ' x ($screenwidth - length $footer);
	my $linecolor = $pfm->config->{framecolors}{$pfm->state->color_mode}{footer};
	$screen->bold()			if ($linecolor =~ /bold/);
	$screen->reverse()		if ($linecolor =~ /reverse/);
#	$screen->underline()	if ($linecolor =~ /under(line|score)/);
	$screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	$screen->at($screen->BASELINE + $screen->screenheight + 1,0)
		->putcolored($linecolor, $footer, $padding))->reset()->normal();
}
##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
