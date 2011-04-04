#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen::Frame 2010-03-27 v0.01
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

use base 'PFM::Abstract';

use PFM::Util;

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

my ($_pfm, $_currentpan);

##########################################################################
# private subs

=item _init()

Initializes new instances by storing the application object.
Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
}

=item _maxpan()

Determines how many times a banner (menu or footer) can be panned.

=cut

sub _maxpan {
	my ($self, $banner, $width) = @_;
	my $panspace;
	# this is an assignment on purpose
	if ($panspace = 2 * (length($banner) > $width)) {
		eval "
			\$banner =~ s/^((?:\\S+ )+?).{1,".($width - $panspace)."}\$/\$1/;
		";
		return $banner =~ tr/ //;
	} else {
		return 0;
	};
}

=item _fitbanner()

Chops off part of the "banner" (menu or footer), and returns the part that
will fit on the screen. Pan key marks B<E<lt>> and B<E<gt>> will be added.

=cut

sub _fitbanner {
	my ($self, $banner, $virtwidth) = @_;
	my ($maxwidth, $spcount);
	if (length($banner) > $virtwidth) {
		$spcount  = $self->_maxpan($banner, $virtwidth);
		$maxwidth = $virtwidth	- 2 * ($_currentpan > 0)
								- 2 * ($_currentpan < $spcount);
		$banner  .= ' ';
		eval "
			\$banner =~ s/^(?:\\S+ ){$_currentpan,}?(.{1,$maxwidth}) .*/\$1/;
		";
		if ($_currentpan > 0       ) { $banner  = '< ' . $banner; }
		if ($_currentpan < $spcount) { $banner .= ' >'; }
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
	my $self = shift;
	my %state = %{$_pfm->state};
	return	"F1-Help F2-Back F3-Redraw"
	.		" F4-Color[$state{color_mode}] F5-Reread"
	.		" F6-Sort[$state{sort_mode}]"
	.		" F7-Swap[$ONOFF{$state{swap_mode}}] F8-Include"
	.		" F9-Layout[$state{currentlayout}]" # $layoutname ?
	.		" F10-Multiple[$ONOFF{$state{multiple_mode}}] F11-Restat"
	.		" F12-Mouse[$ONOFF{$state{mouse_mode}}]"
	.		" !-Clobber[$ONOFF{$state{clobber_mode}}]"
	.		" .-Dotfiles[$ONOFF{$state{dot_mode}}]"
	# TODO white_cmd
	.		($white_cmd ? " %-Whiteouts[$ONOFF{$state{white_mode}}]" : '')
	.		" \"-Pathnames[$state{path_mode}]"
	.		" *-Radix[$state{radix_mode}]"
#	.		" =-Ident[$state{ident_mode}]"
	;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item draw()

Draws menu, footer and headings.

=cut

sub draw {
	my $self = shift;
	$self->draw_menu();
	# TODO @layoutfieldswithinfo
	$self->draw_headings($_pfm->state->{swap_mode}, HEADING_DISKINFO, @layoutfieldswithinfo);
	$self->draw_footer();
	return $self;
}

=item draw_menu()

Draws the menu, i.e., the top line on the screen.

=cut

sub draw_menu {
	my ($self, $mode) = @_;
	my ($pos, $menu, $menulength, $vscreenwidth, $color, $do_multi);
	$mode ||= ($_pfm->state->{multiple_mode} * MENU_MULTI);
	$do_multi = $mode & MENU_MULTI;
	$vscreenwidth = $_pfm->screen->screenwidth - 9 * $do_multi;
	$menu         = $self->_fitbanner($self->_getmenu($mode), $vscreenwidth);
	$menulength   = length($menu);
	if ($menulength < $vscreenwidth) {
		$menu .= ' ' x ($vscreenwidth - $menulength);
	}
	$_pfm->screen->at(0,0);
	if ($do_multi) {
		$color = $_pfm->config->{framecolors}{$_pfm->state->color_mode}{multi};
		$_pfm->screen->putcolored($color, 'Multiple');
	}
	$color = $_pfm->config->{framecolors}{$_pfm->state->color_mode}{menu};
	$_pfm->screen->color($color)->puts(' ' x $do_multi)->puts($menu)->bold();
	while ($menu =~ /[[:upper:]<>](?!nclude\?)/g) {
		$pos = pos($menu) -1;
		$_pfm->screen->at(0, $pos + 9*$do_multi)->puts(substr($menu, $pos, 1));
	}
	$_pfm->screen->reset()->normal();
	return $menulength;
}

=item draw_headings()

Draws the column headings.

=cut

# TODO move to Screen::Listing
sub draw_headings { # swap_mode, extra field, @layoutfieldswithinfo
	my ($self, $smode, $info, @fields) = @_;
	my ($linecolor, $diskinfo, $padding);
	# TODO $infolength
	$padding = ' ' x ($infolength - 14);
	for ($info) {
		$_ == HEADING_DISKINFO	and $diskinfo = "$padding     disk info";
		$_ == HEADING_SORT		and $diskinfo = "sort mode     $padding";
		$_ == HEADING_SIGNAL	and $diskinfo = "  nr signal   $padding";
		$_ == HEADING_YCOMMAND	and $diskinfo = "your commands $padding";
		$_ == HEADING_ESCAPE	and $diskinfo = "esc legend    $padding";
	}
	$FIELDHEADINGS{diskinfo} = $diskinfo;
#	$FIELDHEADINGS{display} = $FIELDHEADINGS{name} . ' (' . $sort_mode . ('%','')[$white_mode] . ('.','')[$dot_mode] . ')';
	$linecolor = $smode ? $_pfm->config->framecolors{$_pfm->state->color_mode}{swap}
						: $_pfm->config->framecolors{$_pfm->state->color_mode}{headings};
#	$screen->bold()			if ($linecolor =~ /bold/);
#	$screen->reverse()		if ($linecolor =~ /reverse/);
#	$screen->underline()	if ($linecolor =~ /under(line|score)/);
	$screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	$screen->at(2,0)
		->putcolored($linecolor, formatted($currentformatlinewithinfo, @FIELDHEADINGS{@fields}))
		->reset()->normal();
}

=item draw_footer()

Draws the footer, i.e. the last line on screen with the status info.

=cut

sub draw_footer {
	my $self	  = shift;
	my $screen	  = $_pfm->screen;
	my $width	  = $screen->screenwidth;
	my $footer	  = $self->_fitbanner($self->_getfooter(), $width);
	my $padding	  = ' ' x ($width - length $footer);
	my $linecolor =
		$_pfm->config->{framecolors}{$_pfm->state->color_mode}{footer};
#	$screen->bold()			if ($linecolor =~ /bold/);
#	$screen->reverse()		if ($linecolor =~ /reverse/);
#	$screen->underline()	if ($linecolor =~ /under(line|score)/);
	$screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	$screen->at($screen->BASELINE + $screen->screenheight + 1, 0)
		->putcolored($linecolor, $footer, $padding))->reset()->normal();
}

=item pan()

Pans the menu and footer according to the key pressed.

=cut

sub pan {
	my ($self, $key, $mode) = @_;
	my $screen = $_pfm->screen;
	my $width  = $screen->screenwidth - 9 * $_pfm->state->{multiple_mode};
	my $count  = max(
		$self->_maxpan($self->_getmenu($mode), $width),
		$self->_maxpan($self->_getfooter(), $width)
	);
	$_currentpan = $_currentpan - ($key eq '<' and $_currentpan > 0)
								+ ($key eq '>' and $_currentpan < $count);
	$screen->set_deferred_refresh($screen->R_MENU | $screen->R_FOOTER);
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
