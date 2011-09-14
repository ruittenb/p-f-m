#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen::Frame 0.32
#
# Name:			App::PFM::Screen::Frame
# Version:		0.32
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-24
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

use App::PFM::Util qw(formatted max);

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
	MENU_NONE			=> 65536,
	HEADING_DISKINFO	=> 0,
	HEADING_YCOMMAND	=> 1,
	HEADING_SORT		=> 2,
	HEADING_ESCAPE		=> 3,
	HEADING_CRITERIA	=> 4,
	HEADING_BOOKMARKS	=> 8,
	FOOTER_SINGLE       => 0,
	FOOTER_MULTI        => 1,
	FOOTER_NONE         => 65536,
};

my %ONOFF = ('' => 'off', 0 => 'off', 1 => 'on');

our %_fieldheadings = (
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
	mode			=> 'mode',
	atime			=> 'date/atime',
	mtime			=> 'date/mtime',
	ctime			=> 'date/ctime',
	atimestring		=> 'date/atime',
	mtimestring		=> 'date/mtime',
	ctimestring		=> 'date/ctime',
	uid				=> 'user',
	gid				=> 'group',
	nlink			=> 'lnks',
	rdev			=> 'dev',
	rcs				=> 'rcs',
	diskinfo		=> 'disk info',
);

our ($_pfm, $_screen);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm, App::PFM::Screen $screen)

Initializes new instances by storing the application object.
Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen) = @_;
	$_pfm	 = $pfm;
	$_screen = $screen;
	$self->{_currentpan} = 0;
	$self->{_rcsrunning} = 0;
}

=item _maxpan(string $banner, int $width)

Determines how many times a I<banner> (menu or footer) can be panned.

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

=item _fitbanner(string $banner, int $width)

Chops off part of the I<banner> (menu or footer), and returns the part that
will fit on the screen, as indicated by I<width>. Pan key marks B<E<lt>>
and B<E<gt>> will be added.

=cut

sub _fitbanner {
	my ($self, $banner, $virtwidth) = @_;
	my ($maxwidth, $spcount);
	my $currentpan = $self->{_currentpan};
	if (length($banner) > $virtwidth) {
		$spcount  = $self->_maxpan($banner, $virtwidth);
		$maxwidth = $virtwidth	- 2 * ($currentpan > 0)
								- 2 * ($currentpan < $spcount);
		$banner  .= ' ';
		eval "
			\$banner =~ s/^(?:\\S+ ){$currentpan,}?(.{1,$maxwidth}) .*/\$1/;
		";
		if ($currentpan > 0       ) { $banner  = '< ' . $banner; }
		if ($currentpan < $spcount) { $banner .= ' >'; }
	}
	return $banner;
}

=item _getmenu( [ int $menu_mode ] )

Returns the menu for the given menu mode.
This uses the B<MENU_> constants as defined in App::PFM::Screen::Frame.

=cut

sub _getmenu {
	my ($self, $mode) = @_;
	$mode ||= MENU_SINGLE;
	# disregard multiple mode: show_menu will take care of it
	if		($mode == MENU_SORT) {
		return	'Sort by: Name, Extension, Size, Date, Type, Version '
		.		'(or see below):';
	} elsif ($mode == MENU_MORE) {
		return	'Acl Bookmark Config Edit-any mkFifo Go sHell Mkdir '
		.		'Phys-path Show-dir alTscreen Version Write-hist';
	} elsif ($mode == MENU_EXCLUDE) {
		return	"Exclude? Every, Old-/Newmarks, After/Before, "
		.		"Greater/Smaller, User, Files only:";
	} elsif ($mode == MENU_INCLUDE) {
		return	"Include? Every, Old-/Newmarks, After/Before, "
		.		"Greater/Smaller, User, Files only:";
	} elsif ($mode == MENU_LNKTYPE) {
		return	'Absolute, Relative symlink or Hard link:';
	} elsif ($mode == MENU_NONE) {
		return	'';
	} else { # SINGLE or MULTI
		return	'Attribute Copy Delete Edit Find tarGet Include Link More Name'
		.		' cOmmand Print Quit Rename Show Time User Version unWhiteout'
		.		' eXclude Your-command siZe';
	}
}

=item _getfooter( [ int $footer_mode ] )

Returns the footer for the current application state.
The I<footer_mode> parameter indicates the type of footer that is shown,
using the B<FOOTER_> constants as defined in App::PFM::Screen::Frame.

=cut

sub _getfooter {
	my ($self, $footer_mode) = @_;
	my %state = %{$_pfm->state};
	if ($footer_mode != FOOTER_SINGLE and $footer_mode != FOOTER_MULTI) {
		return '';
	}
	my $f =	"F1-Help F2-Prev F3-Redraw"
	.		" F4-Color[" . $_screen->color_mode . "] F5-Reread"
	.		" F6-Sort[$state{sort_mode}]"
	.		" F7-Swap[$ONOFF{$_pfm->browser->swap_mode}] F8-In/Exclude"
	.		" F9-Layout[" . $_screen->listing->layout . "]" # $layoutname ?
	.		" F10-Multiple[$ONOFF{$state{multiple_mode}}] F11-Restat"
	.		" F12-Mouse[$ONOFF{$_pfm->browser->mouse_mode}]"
	.		" !-Clobber[$ONOFF{$_pfm->commandhandler->clobber_mode}]"
	.		" .-Dotfiles[$ONOFF{$state{dot_mode}}]"
	.		" %-Whiteouts[$ONOFF{$state{white_mode}}]"
	.		" \"-Pathnames[" . $_pfm->state->directory->path_mode . "]"
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

=item currentpan( [ int $pan_value ] )

Getter/setter for the amount by which the menu and footer are currently
panned.

=cut

sub currentpan {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_currentpan} = $value;
		$self->pan(); # $key, $mode both undef
	}
	return $self->{_currentpan};
}

=item bookmark_headings()

Getter for the correct bookmark headings for the current screenwidth
and format.

=cut

sub bookmark_headings {
	my ($self) = @_;
	my $infolength = $_screen->diskinfo->infolength;
	my @headings =
		(" %1s%1s %-" . ($_screen->screenwidth - 5 - $infolength) . 's',
		 "%${infolength}s",
		$_screen->screenwidth - 5 - $infolength);
#		(' @@ @' . '<' x ($_screen->screenwidth - 6 - $infolength),
#		 '@'    . '>' x ($infolength - 1));
#	if ($_screen->diskinfo->infocol < $_screen->listing->filerecordcol) {
#		@headings = reverse @headings;
#	}
	return @headings;
	#  |--------------screenwidth---------------|
	#  11111                     11 (infolength-1)
	# ' A* @<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>'
}

=item rcsrunning( [ bool $rcsrunning_value ] )

Getter/setter for the flag that indicates whether an rcs command is running.

=cut

sub rcsrunning {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_rcsrunning} = $value;
		$self->update_headings($value);
	}
	return $self->{_rcsrunning};
}

##########################################################################
# public subs

=item show( { menu => int $menu_mode, footer => int $footer_mode,
headings => int $heading_mode, prompt => string $prompt } )

Displays menu, footer and headings according to the specified modes.
If a prompt is specified, no menu is shown, but a prompt is shown instead.

=cut

sub show {
	my ($self, $options) = @_;
	my $menulength;
	my $prompt       = $options->{prompt};
	my $menu_mode    = $options->{menu}     || MENU_SINGLE;
	my $heading_mode = $options->{headings} || HEADING_DISKINFO;
	my $footer_mode  = $options->{footer};
	$footer_mode   ||=
		$menu_mode == MENU_SINGLE
			? FOOTER_SINGLE
			: $menu_mode == MENU_MULTI
				? FOOTER_MULTI
				: FOOTER_NONE;
	$self->show_headings($_pfm->browser->swap_mode, $heading_mode);
	$self->show_footer($footer_mode);
	if ($prompt) {
#        $_screen->at(0,0)->clreol()->putcolored(
#			$_pfm->config->{framecolors}{$_screen->color_mode}{message},
#			$prompt);
        $_screen->at(0,0)->clreol()->putmessage($prompt);
		$menulength = length $prompt;
	} else {
		$menulength = $self->show_menu($menu_mode);
	}
	return $menulength;
}

=item show_menu(int $menu_mode)

Displays the menu, i.e., the top line on the screen.
The I<menu_mode> argument indicates which kind of menu is to be shown,
using the B<MENU_> constants as defined in App::PFM::Screen::Frame.

=cut

sub show_menu {
	my ($self, $menu_mode) = @_;
	my ($pos, $menu, $menulength, $vscreenwidth, $color, $do_multi);
	$menu_mode ||= ($_pfm->state->{multiple_mode} * MENU_MULTI);
	$do_multi = $menu_mode & MENU_MULTI;
	$vscreenwidth = $_screen->screenwidth - 9 * $do_multi;
	$menu         = $self->_fitbanner(
		$self->_getmenu($menu_mode), $vscreenwidth);
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

=item show_headings(bool $swapmode, int $heading_mode)

Displays the column headings.
The I<heading_mode> argument indicates which kind of information
is shown in the diskinfo column, using the B<HEADING_> constants as
defined in App::PFM::Screen::Frame.

=cut

sub show_headings {
	my ($self, $swapmode, $heading_mode) = @_;
	my $linecolor = $swapmode
		? $_pfm->config->{framecolors}->{$_screen->color_mode}{swap}
		: $_pfm->config->{framecolors}->{$_screen->color_mode}{headings};
	# in case colorizable() is off:
	$_screen->bold()		if ($linecolor =~ /bold/);
	$_screen->reverse()		if ($linecolor =~ /reverse/);
	$_screen->underline()	if ($linecolor =~ /underline/);
#	$_screen->term()->Tputs('us', 1, *STDOUT)
#							if ($linecolor =~ /under(line|score)/);

	if ($heading_mode == HEADING_BOOKMARKS) {
		my @headline  = $self->bookmark_headings;
		$_screen->at($_screen->HEADINGLINE, $_screen->listing->filerecordcol)
			->putcolored($linecolor, sprintf($headline[0], ' ', ' ', 'path'));
		$_screen->at($_screen->HEADINGLINE, $_screen->diskinfo->infocol)
			->putcolored($linecolor, sprintf($headline[1], 'disk info'))
			->reset()->normal();
	} else {
		my ($diskinfo, $padding);
		my @fields = @{$_screen->listing->layoutfieldswithinfo};
		my $state  = $_pfm->state;
		$padding = ' ' x ($_screen->diskinfo->infolength - 14);
		for ($heading_mode) {
			$_ == HEADING_DISKINFO	and $diskinfo = "$padding     disk info";
			$_ == HEADING_SORT		and $diskinfo = "sort mode     $padding";
			$_ == HEADING_YCOMMAND	and $diskinfo = "your commands $padding";
			$_ == HEADING_ESCAPE	and $diskinfo = "esc legend    $padding";
			$_ == HEADING_CRITERIA	and $diskinfo = "criteria      $padding";
		}
		$_fieldheadings{diskinfo} = $diskinfo;
		$self->update_headings();
		my $heading = formatted(
			$_screen->listing->currentformatlinewithinfo,
			@_fieldheadings{@fields});
		$_screen->at($_screen->HEADINGLINE, 0)
			->putcolored($linecolor, $heading)
			->reset()->normal();
	}
}

=item show_footer( [ int $footer_mode ] )

Displays the footer, i.e. the last line on screen with the status info.

=cut

sub show_footer {
	my ($self, $footer_mode) = @_;
	$footer_mode ||= ($_pfm->state->{multiple_mode} * FOOTER_MULTI);
	my $width	   = $_screen->screenwidth;
	my $footer	   = $self->_fitbanner($self->_getfooter($footer_mode), $width);
	my $padding	   = ' ' x ($width - length $footer);
	my $linecolor  =
		$_pfm->config->{framecolors}{$_screen->color_mode}{footer};
	# in case colorizable() is off:
	$_screen->bold()		if ($linecolor =~ /bold/);
	$_screen->reverse()		if ($linecolor =~ /reverse/);
	$_screen->underline()	if ($linecolor =~ /underline/);
#	$_screen->term()->Tputs('us', 1, *STDOUT)
#							if ($linecolor =~ /under(line|score)/);
	$_screen->at($_screen->BASELINE + $_screen->screenheight + 1, 0)
		->putcolored($linecolor, $footer, $padding)->reset()->normal();
}

=item update_headings()

Updates the column headings in case of a mode change.

=cut

sub update_headings {
	my ($self) = @_;
	my $state = $_pfm->state;
	my $filters = ($state->{white_mode} ? '' : '%')
				. ($state->{dot_mode}   ? '' : '.');
	$_fieldheadings{display} = $_fieldheadings{name} .
		($filters ? " (filtered)" : '');
	if ($self->{_rcsrunning} or $state->directory->{_rcsjob}) {
		$_fieldheadings{rcs} =~  s/!*$/!/;
	} else {
		$_fieldheadings{rcs} =~ s/!+$//;
	}
}

=item pan(string $key, $string $menu_mode)

Pans the menu and footer according to the key pressed.
The I<menu_mode> parameter indicates the type of menu that should be shown,
using the B<MENU_> constants as defined in App::PFM::Screen::Frame.

=cut

sub pan {
	my ($self, $key, $menu_mode) = @_;
	my $width = $_screen->screenwidth - 9 * $_pfm->state->{multiple_mode};
	my $count = max(
		$self->_maxpan($self->_getmenu($menu_mode), $width),
		$self->_maxpan($self->_getfooter($menu_mode), $width)
	);
	$self->{_currentpan} += ($key eq '>' and $self->{_currentpan} < $count)
						  - ($key eq '<' and $self->{_currentpan} > 0);
	$_screen->set_deferred_refresh($_screen->R_MENU | $_screen->R_FOOTER);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
