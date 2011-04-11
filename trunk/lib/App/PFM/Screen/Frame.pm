#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen::Frame 0.04
#
# Name:			App::PFM::Screen::Frame
# Version:		0.04
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-03
#

##########################################################################

=pod

=head1 NAME

App::PFM::Screen::Frame

=head1 DESCRIPTION

PFM class for drawing a frame (menubar, footer and column headings)
and panning it.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Screen::Frame;

use base 'App::PFM::Abstract';

use App::PFM::Util;

use locale;
use strict;

use constant {
	MENU_SINGLE			=> 0,
	MENU_MULTI			=> 1,
	MENU_MORE			=> 2,
	MENU_SORT			=> 4,
	MENU_INCLUDE		=> 8,
	MENU_EXCLUDE		=> 16,
	MENU_LNKTYPE		=> 32,
	HEADING_DISKINFO	=> 0,
	HEADING_YCOMMAND	=> 1,
	HEADING_SORT		=> 2,
	HEADING_ESCAPE		=> 3,
};

my %ONOFF = ('' => 'off', 0 => 'off', 1 => 'on');

my %_fieldheadings = (
	selected		=> ' ',
	name			=> 'filename',
	display			=> 'filename',
	name_too_long	=> ' ',
	size			=> 'size',
	size_num		=> 'size',
	size_power		=> ' ',
	grand			=> 'total',
	grand_num		=> 'total',
	grand_power		=> ' ',
	inode			=> 'inode',
	mode			=> 'perm',
	atime			=> 'date/atime',
	mtime			=> 'date/mtime',
	ctime			=> 'date/ctime',
	atimestring		=> 'date/atime',
	mtimestring		=> 'date/mtime',
	ctimestring		=> 'date/ctime',
	uid				=> 'userid',
	gid				=> 'groupid',
	nlink			=> 'lnks',
	rdev			=> 'dev',
	rcs				=> 'vers',
	diskinfo		=> 'disk info',
);

my ($_pfm, $_screen,
	$_currentpan);

##########################################################################
# private subs

=item _init()

Initializes new instances by storing the application object.
Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen) = @_;
	$_pfm        = $pfm;
	$_screen     = $screen;
	$_currentpan = 0;
}

=item _maxpan()

Determines how many times a banner (menu or footer) can be panned.

=cut

sub _maxpan {
	my ($self, $banner, $width) = @_;
	my $panspace;
	# the next line is an assignment on purpose
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
		return	'Sort by: Name, Extension, Size, Date, Type, Inode, Vers '
		.		'(ignorecase, reverse):';
	} elsif ($mode & MENU_MORE) {
		return	'Bookmark Config Edit-any mkFifo Go sHell Mkdir '
		.		'Phys-path Show-dir alTscreen Version Write-hist';
	} elsif ($mode & MENU_EXCLUDE) {
		return	'Exclude? Every, Oldmarks, Newmarks, '
		.		'After, Before, User or Files only:';
	} elsif ($mode & MENU_INCLUDE) {
		return	'Include? Every, Oldmarks, Newmarks, '
		.		'After, Before, User or Files only:';
	} elsif ($mode & MENU_LNKTYPE) {
		return	'Absolute, Relative symlink or Hard link:';
	} else {
		return	'Attribute Copy Delete Edit Find tarGet Include Link More Name'
		.		' cOmmand Print Quit Rename Show Time User Version unWhiteout'
		.		' eXclude Your-command siZe';
	}
}

=item _getfooter()

Returns the footer for the current application state.

=cut

sub _getfooter {
	my $self = shift;
	my %state = %{$_pfm->state};
	my $f =	"F1-Help F2-Prev F3-Redraw"
	.		" F4-Color[".$_screen->color_mode."] F5-Reread"
	.		" F6-Sort[$state{sort_mode}]"
	.		" F7-Swap[".$ONOFF{$_pfm->browser->swap_mode}."] F8-In/Exclude"
	.		" F9-Layout[".$_screen->listing->layout."]" # $layoutname ?
	.		" F10-Multiple[$ONOFF{$state{multiple_mode}}] F11-Restat"
	.		" F12-Mouse[".$ONOFF{$_pfm->browser->mouse_mode}."]"
	.		" !-Clobber[".$ONOFF{$_pfm->commandhandler->clobber_mode}."]"
	.		" .-Dotfiles[$ONOFF{$state{dot_mode}}]"
	.		($_pfm->commandhandler->whitecommand
				? " %-Whiteouts[$ONOFF{$state{white_mode}}]" : '')
	.		" \"-Pathnames[".$_pfm->state->directory->path_mode."]"
	.		" *-Radix[$state{radix_mode}]"
#	.		" =-Ident[$state{ident_mode}]"
	;
	return $f;
}

##########################################################################
# constructor, getters and setters

=item fieldheadings()

Getter for the hash that defines the column headings to be printed.

=cut

sub fieldheadings {
	return \%_fieldheadings;
}

##########################################################################
# public subs

=item show()

Displays menu, footer and headings.

=cut

sub show {
	my $self = shift;
	$self->show_menu();
	$self->show_headings($_pfm->browser->swap_mode, HEADING_DISKINFO);
	$self->show_footer();
	return $self;
}

=item show_menu()

Displays the menu, i.e., the top line on the screen.

=cut

sub show_menu {
	my ($self, $mode) = @_;
	my ($pos, $menu, $menulength, $vscreenwidth, $color, $do_multi);
	$mode ||= ($_pfm->state->{multiple_mode} * MENU_MULTI);
	$do_multi = $mode & MENU_MULTI;
	$vscreenwidth = $_screen->screenwidth - 9 * $do_multi;
	$menu         = $self->_fitbanner($self->_getmenu($mode), $vscreenwidth);
	$menulength   = length($menu);
	if ($menulength < $vscreenwidth) {
		$menu .= ' ' x ($vscreenwidth - $menulength);
	}
	$_screen->at(0,0);
	if ($do_multi) {
		$color = $_pfm->config->{framecolors}{$_screen->color_mode}{multi};
		$_screen->putcolored($color, 'Multiple');
	}
	$color = $_pfm->config->{framecolors}{$_screen->color_mode}{menu};
	$_screen->color($color)->puts(' ' x $do_multi)->puts($menu)->bold();
	while ($menu =~ /[[:upper:]<>](?![xn]clude\?)/g) {
		$pos = pos($menu) -1;
		$_screen->at(0, $pos + 9*$do_multi)->puts(substr($menu, $pos, 1));
	}
	$_screen->reset()->normal();
	return $menulength;
}

=item show_headings()

Displays the column headings.

=cut

sub show_headings {
	my ($self, $swapmode, $info) = @_;
	my ($linecolor, $diskinfo, $padding, $filters);
	my @fields = @{$_screen->listing->layoutfieldswithinfo};
	my $state  = $_pfm->state;
	$padding = ' ' x ($_screen->diskinfo->infolength - 14);
	for ($info) {
		$_ == HEADING_DISKINFO	and $diskinfo = "$padding     disk info";
		$_ == HEADING_SORT		and $diskinfo = "sort mode     $padding";
		$_ == HEADING_YCOMMAND	and $diskinfo = "your commands $padding";
		$_ == HEADING_ESCAPE	and $diskinfo = "esc legend    $padding";
	}
	$_fieldheadings{diskinfo} = $diskinfo;
	$filters = ($state->{white_mode} ? '' : '%')
			 . ($state->{dot_mode}   ? '' : '.');
	$_fieldheadings{display} = $_fieldheadings{name} .
		($filters ? " (filtered)" : '');
	$linecolor = $swapmode
		? $_pfm->config->{framecolors}->{$_screen->color_mode}{swap}
		: $_pfm->config->{framecolors}->{$_screen->color_mode}{headings};
	# in case colorizable() is off:
	$_screen->bold()		if ($linecolor =~ /bold/);
	$_screen->reverse()		if ($linecolor =~ /reverse/);
#	$_screen->underline()	if ($linecolor =~ /under(line|score)/);
	$_screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	$_screen->at(2,0)
		->putcolored($linecolor, formatted(
			$_screen->listing->currentformatlinewithinfo,
			@_fieldheadings{@fields}))
		->reset()->normal();
}

=item show_footer()

Displays the footer, i.e. the last line on screen with the status info.

=cut

sub show_footer {
	my $self	  = shift;
	my $width	  = $_screen->screenwidth;
	my $footer	  = $self->_fitbanner($self->_getfooter(), $width);
	my $padding	  = ' ' x ($width - length $footer);
	my $linecolor =
		$_pfm->config->{framecolors}{$_screen->color_mode}{footer};
	# in case colorizable() is off:
	$_screen->bold()		if ($linecolor =~ /bold/);
	$_screen->reverse()		if ($linecolor =~ /reverse/);
#	$_screen->underline()	if ($linecolor =~ /under(line|score)/);
	$_screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	$_screen->at($_screen->BASELINE + $_screen->screenheight + 1, 0)
		->putcolored($linecolor, $footer, $padding)->reset()->normal();
}

=item clear_footer()

Clears the footer.

=cut

sub clear_footer {
	my $self	  = shift;
	my $padding	  = ' ' x ($_screen->screenwidth);
	my $linecolor =
		$_pfm->config->{framecolors}{$_screen->color_mode}{footer};
#	$_screen->term()->Tputs('us', 1, *STDOUT)
#							if ($linecolor =~ /under(line|score)/);
	$_screen->at($_screen->BASELINE + $_screen->screenheight + 1, 0)
		->putcolored($linecolor, $padding)->reset()->normal();
}

=item pan()

Pans the menu and footer according to the key pressed.

=cut

sub pan {
	my ($self, $key, $mode) = @_;
	my $width = $_screen->screenwidth - 9 * $_pfm->state->{multiple_mode};
	my $count = max(
		$self->_maxpan($self->_getmenu($mode), $width),
		$self->_maxpan($self->_getfooter(), $width)
	);
	$_currentpan = $_currentpan - ($key eq '<' and $_currentpan > 0)
								+ ($key eq '>' and $_currentpan < $count);
	$_screen->set_deferred_refresh($_screen->R_MENU | $_screen->R_FOOTER);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
