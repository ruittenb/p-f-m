#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen 0.31
#
# Name:			App::PFM::Screen
# Version:		0.31
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-24
# Requires:		Term::ScreenColor
#

##########################################################################

=pod

=head1 NAME

App::PFM::Screen

=head1 DESCRIPTION

PFM class used for coordinating how all elements are displayed on screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Screen;

use base qw(App::PFM::Abstract Term::ScreenColor Exporter);

use App::PFM::Screen::Frame;
use App::PFM::Screen::Listing;
use App::PFM::Screen::Diskinfo;
use App::PFM::Util qw(fitpath max);
use POSIX qw(getcwd);

use strict;

use constant {
	PATH_PHYSICAL	=> 1,
	ERRORDELAY		=> 1,	 # in seconds (fractions allowed)
	IMPORTANTDELAY	=> 2,	 # extra time for important errors
	PATHLINE		=> 1,
	HEADINGLINE		=> 2,
	BASELINE		=> 3,
	R_NOP			=> 0,	 # no action was required, wait for new key
	R_STRIDE		=> 1,	 # validate cursor position (always done)
	R_MENU			=> 2,	 # reprint the menu (header)
	R_PATHINFO		=> 4,	 # reprint the pathinfo
	R_HEADINGS		=> 8,	 # reprint the headings
	R_FOOTER		=> 16,	 # reprint the footer
#	R_FRAME					 # R_FOOTER + R_HEADINGS + R_PATHINFO + R_MENU
	R_DISKINFO		=> 32,	 # reprint the disk- and directory info column
	R_DIRLIST		=> 64,	 # redisplay directory listing
	R_DIRFILTER		=> 128,	 # decide what to display (init @showncontents)
#	R_SCREEN				 # R_DIRFILTER + R_DIRLIST + R_DISKINFO + R_FRAME
	R_CLEAR			=> 256,	 # clear the screen
#	R_CLRSCR				 # R_CLEAR and R_SCREEN
	R_ALTERNATE		=> 512,	 # switch screens according to 'altscreen_mode'
	R_DIRSORT		=> 1024, # resort @dircontents
	R_DIRCONTENTS	=> 2048, # reread directory contents
	R_NEWDIR		=> 4096, # re-init directory-specific vars
#	R_CHDIR					 # R_NEWDIR + R_DIRCONTENTS + R_DIRSORT + R_SCREEN
};

# needs new invocations because of the calculations
use constant R_FRAME  => R_MENU | R_PATHINFO | R_HEADINGS | R_FOOTER;
use constant R_SCREEN => R_DIRFILTER | R_DIRLIST | R_DISKINFO | R_FRAME;
use constant R_CLRSCR => R_CLEAR | R_SCREEN;
use constant R_CHDIR  =>
					R_NEWDIR | R_DIRCONTENTS | R_DIRSORT | R_SCREEN | R_STRIDE;

our @EXPORT = qw(R_NOP R_STRIDE R_MENU R_PATHINFO R_HEADINGS R_FOOTER R_FRAME
	R_DISKINFO R_DIRLIST R_DIRFILTER R_SCREEN R_CLEAR R_CLRSCR R_DIRSORT
	R_DIRCONTENTS R_CHDIR R_NEWDIR
);

# _wasresized needs to be a package global because it is accessed by a
# signal handler.
# This is no problem as this class is supposed to be singleton anyway.
our ($_pfm, $_frame, $_listing, $_diskinfo, $_wasresized);

##########################################################################
# private subs

=item _init()

Called from the constructor. Initializes new instances. Stores the
application object for later use and instantiates a App::PFM::Screen::Frame
and App::PFM::Screen::Listing object.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm		= $pfm;
	$_frame		= new App::PFM::Screen::Frame(   $pfm, $self);
	$_listing	= new App::PFM::Screen::Listing( $pfm, $self);
	$_diskinfo	= new App::PFM::Screen::Diskinfo($pfm, $self);
	$self->{_winheight}        = 0;
	$self->{_winwidth}         = 0;
	$self->{_screenheight}     = 0;
	$self->{_screenwidth}      = 0;
	$self->{_deferred_refresh} = 0;
	$self->{_color_mode}       = '';
	$SIG{WINCH} = \&_catch_resize;
}

=item _catch_resize()

Catches window resize signals (WINCH).

=cut

sub _catch_resize {
	$_wasresized = 1;
	$SIG{WINCH} = \&_catch_resize;
}

##########################################################################
# constructor, getters and setters

=item new()

Specific constructor for App::PFM::Screen. Constructs an object based on
Term::ScreenColor.

=cut

sub new {
	my ($type, @args) = @_;
	$type = ref($type) || $type;
	my $self = new Term::ScreenColor();
	bless($self, $type);
	$self->_init(@args);
	return $self;
}

=item screenwidth()

=item screenheight()

Getters/setters for the dimensions of the screen.

=cut

sub screenwidth {
	my ($self, $value) = @_;
	$self->{_screenwidth} = $value if defined $value;
	return $self->{_screenwidth};
}

sub screenheight {
	my ($self, $value) = @_;
	$self->{_screenheight} = $value if defined $value;
	return $self->{_screenheight};
}

=item frame()

=item listing()

=item diskinfo()

Getters for the App::PFM::Screen::Frame, App::PFM::Screen::Listing
and App::PFM::Screen::Diskinfo objects.

=cut

sub frame {
	return $_frame;
}

sub listing {
	return $_listing;
}

sub diskinfo {
	return $_diskinfo;
}

=item wasresized()

Getter/setter for the flag that indicates that the window was resized
and needs to be updated.

=cut

sub wasresized {
	my ($self, $value) = @_;
	$_wasresized = $value if defined $value;
	return $_wasresized;
}

=item color_mode()

Getter/setter for the choice of color mode (I<e.g.> 'dark', 'light',
'ls_colors'). Schedules a screen refresh if the color mode is set.

=cut

sub color_mode {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_color_mode} = $value;
		$self->set_deferred_refresh(R_SCREEN);
	}
	return $self->{_color_mode};
}

##########################################################################
# public subs

=item raw_noecho()

=item cooked_echo()

Sets the terminal to I<raw> or I<cooked> mode.

=cut

sub raw_noecho {
	my $self = shift;
	$self->raw()->noecho();
}

sub cooked_echo {
	my $self = shift;
	$self->cooked()->echo();
}

=item mouse_enable()

=item mouse_disable()

Tells the terminal to start/stop receiving information about the mouse.

=cut

sub mouse_enable {
	my $self = shift;
	print "\e[?9h";
	return $self;
}

sub mouse_disable {
	my $self = shift;
	print "\e[?9l";
	return $self;
}

=item alternate_on()

=item alternate_off()

Switches to alternate terminal screen and back.

=cut

sub alternate_on {
	my $self = shift;
	print "\e[?47h";
	return $self;
}

sub alternate_off {
	my $self = shift;
	print "\e[?47l";
	return $self;
}

=item calculate_dimensions()

Calculates the height and width of the screen.

=cut

sub calculate_dimensions {
	my $self = shift;
	my $newheight = $self->rows();
	my $newwidth  = $self->cols();
	if ($newheight || $newwidth) {
#		$ENV{ROWS}    = $newheight;
#		$ENV{COLUMNS} = $newwidth;
		$self->{_winheight}    = $newheight;
		$self->{_winwidth}     = $newwidth;
		$self->{_screenheight} = $newheight - BASELINE - 2;
		$self->{_screenwidth}  = $newwidth;
	}
	return $self;
}

=item check_minimum_size()

Tests whether the terminal size is smaller than the minimum supported
24 rows or 80 columns.  If so, sends an escape sequence to adjust the
terminal size.

=cut

sub check_minimum_size {
	my ($self) = @_;
	my ($newwidth, $newheight);
	return if ($self->{_winwidth} >= 80 and $self->{_winheight} >= 24);
	if ($_pfm->config->{force_minimum_size}) {
		$newwidth  = $self->{_winwidth}  < 80 ? 80 : $self->{_winwidth};
		$newheight = $self->{_winheight} < 24 ? 24 : $self->{_winheight};
		$self->puts("\e[8;$newheight;${newwidth}t");
		return 1;
	}
	return 0;
}

=item fit()

Recalculates the screen size and adjust the layouts.

=cut

sub fit {
	my ($self) = @_;
	$self->resize();
	$self->calculate_dimensions();
	if ($self->check_minimum_size()) {
		# the size was smaller than the minimum supported and has been adjusted.
		$self->resize();
		$self->calculate_dimensions();
	}
	$self->listing->makeformatlines();
	$self->listing->reformat();
	$self->set_deferred_refresh(R_CLRSCR);
	# be careful here because the Screen object is instantiated
	# before the browser and history objects.
	$_pfm->browser and $_pfm->browser->validate_position();
	$_pfm->history and $_pfm->history->handleresize();
}

=item handleresize()

Makes the contents fit on the screen again after a resize. Validates
the cursor position.

=cut

sub handleresize {
	my $self = shift;
	$_wasresized = 0;
	$self->fit();
	return $self;
}

=item pending_input()

Returns a boolean indicating that there is input ready to be processed.

=cut

sub pending_input {
	my ($self, $delay) = @_;
	my $input_ready =
		length($self->{IN}) || $_wasresized || $self->key_pressed($delay);
	while ($input_ready == -1 and $! == 4) {
		# 'Interrupted system call'
		$input_ready = $self->key_pressed(0.1);
	}
	return $input_ready;
}

=item show_frame( { menu => int $menu_mode, footer => int $footer_mode,
headings => int $heading_mode, prompt => string $prompt } )

Uses the App::PFM::Screen::Frame object to redisplay the frame.

=cut

sub show_frame {
	my ($self, $options) = @_;
	return $_frame->show($options);
}

=item clear_footer()

Calls App::PFM::Screen::Frame::clear_footer() and schedules a refresh
for the footer.

=cut

sub clear_footer {
	my $self = shift;
	$_frame->show_footer($_frame->FOOTER_NONE);
	$self->set_deferred_refresh(R_FOOTER);
	return $self;
}

=item select_next_color()

Finds the next colorset to use.

=cut

sub select_next_color {
	my $self = shift;
	my @colorsetnames = @{$_pfm->config->{colorsetnames}};
	my $index = $#colorsetnames;
	while ($self->{_color_mode} ne $colorsetnames[$index] and $index > 0) {
		$index--;
	}
	if ($index-- <= 0) { $index = $#colorsetnames }
	$self->{_color_mode} = $colorsetnames[$index];
	$self->color_mode($self->{_color_mode});
	$_pfm->history->setornaments();
	$self->listing->reformat();

}

=item putcentered()

Displays a message on the current screen line, vertically centered.

=cut

sub putcentered {
	my ($self, $string) = @_;
	$self->puts(' ' x (($self->{_screenwidth} - length $string)/2) . $string);
}

=item putmessage()

Displays a message in the configured message color.
Accepts an array with message fragments.

=cut

sub putmessage {
	my ($self, @message) = @_;
	my $framecolors = $_pfm->config->{framecolors};
	if ($framecolors) {
		$self->putcolored(
			$framecolors->{$self->{_color_mode}}{message},
			join '', @message);
	} else {
		$self->puts(join '', @message);
	}
}

=item pressanykey()

Displays a message and waits for a key to be pressed.

=cut

sub pressanykey {
	my $self = shift;
	$self->putmessage("\r\n*** Hit any key to continue ***");
	$self->raw_noecho();
	if ($_pfm->browser->mouse_mode && $_pfm->config->{clickiskeypresstoo}) {
		$self->mouse_enable();
	} else {
		$self->mouse_disable();
	}
	if ($self->getch() eq 'kmous') {
		$self->getch(); # discard mouse info: co-ords and button
		$self->getch();
		$self->getch();
	};
	# the output of the following command should start on a new line.
	# does this work correctly in TERM_RAW mode?
	$self->puts("\n");
	$self->mouse_enable() if $_pfm->browser->{mouse_mode};
	$self->alternate_on() if $_pfm->config->{altscreen_mode};
	$self->handleresize() if $_wasresized;
}

=item ok_to_remove_marks()

Prompts the user for confirmation since they are about to lose
their marks in the current directory.

=cut

sub ok_to_remove_marks {
	my $self = shift;
	my $sure;
	if ($_pfm->config->{remove_marks_ok} or $_diskinfo->mark_info() <= 0) {
		return 1;
	}
	$_diskinfo->show();
	$self->clear_footer()
		->at(0,0)->clreol()
		->putmessage('OK to remove marks [Y/N]? ');
	$sure = $self->getch();
#	$_frame->show_menu();
	$self->set_deferred_refresh(R_FRAME);
	return ($sure =~ /y/i);
}

=item display_error()

Displays an error which may be passed as an array with message
fragments. Waits for a key to be pressed and returns the keypress.

=cut

sub display_error {
	my $self = shift;
	$self->putmessage(@_);
	return $self->error_delay();
}

=item neat_error()

Displays an error which may be passed as an array with message
fragments. Waits for a key to be pressed and returns the keypress.
Flags screen elements for refreshing.

=cut

sub neat_error {
	my $self = shift;
	$self->at(0,0)->clreol()->display_error(@_);
	if ($_pfm->state->{multiple_mode}) {
		$self->set_deferred_refresh(R_PATHINFO);
	} else {
		$self->set_deferred_refresh(R_FRAME);
	}
	return $self;
}

=item error_delay()

=item important_delay()

Waits for a key to be pressed. Returns the keypress.

=cut

sub error_delay {
	return $_[0]->key_pressed(ERRORDELAY);
}

sub important_delay {
	return $_[0]->key_pressed(IMPORTANTDELAY);
}

=item set_deferred_refresh()

Flags a screen element as 'needs to be redrawn'.

=cut

sub set_deferred_refresh {
	my ($self, $bits) = @_;
	$self->{_deferred_refresh} |= $bits;
	return $self;
}

=item unset_deferred_refresh()

Flags a screen element as 'does not need to be redrawn'.

=cut

sub unset_deferred_refresh {
	my ($self, $bits) = @_;
	$self->{_deferred_refresh} &= ~$bits;
	return $self;
}

=item refresh_headings()

Redisplays the headings if they have been flagged as 'needs to be redrawn'.

=cut

sub refresh_headings {
	my ($self) = @_;
	if ($self->{_deferred_refresh} & R_HEADINGS) {
		$_frame->show_headings(
			$_pfm->browser->swap_mode, $_frame->HEADING_DISKINFO);
		$self->{_deferred_refresh} &= ~R_HEADINGS;
	}
	return $self;
}

=item refresh()

Redisplays all screen elements that have been flagged as 'needs to be redrawn'.

=cut

sub refresh {
	my ($self)           = @_;
	my $directory        = $_pfm->state->directory;
	my $browser          = $_pfm->browser;
	my $deferred_refresh = $self->{_deferred_refresh};
	$self->{_deferred_refresh} = 0;
	
	if ($deferred_refresh & R_ALTERNATE) {
		if ($_pfm->config->{altscreen_mode}) {
			$self->alternate_on()->at(0,0);
		} else {
			$self->alternate_off()->at(0,0);
		}
	}
	# show frame as soon as possible: this looks better on slow terminals
	if ($deferred_refresh & R_CLEAR) {
		$self->clrscr();
	}
	if ($deferred_refresh & R_FRAME) {
		$_frame->show();
	}
	# now in order of severity
	if ($deferred_refresh & R_NEWDIR) {
		# it's dangerous to leave multiple_mode on when changing directories
		# ('autoexitmultiple' is only for leaving it on between commands)
		$_pfm->state->{multiple_mode} = 0;
	}
	if ($deferred_refresh & R_DIRCONTENTS or
		$deferred_refresh & R_DIRSORT)
	{
		# first time round 'currentfile' is undefined
		if (defined $browser->currentfile) {
			$browser->position_at($browser->currentfile->{name});
		}
	}
	if ($deferred_refresh & R_DIRCONTENTS) {
		$directory->init_dircount();
		$directory->readcontents();
	}
	if ($deferred_refresh & R_DIRSORT) {
		$directory->sortcontents();
	}
	if ($deferred_refresh & R_DIRFILTER) {
		$directory->filtercontents();
	}
	if ($deferred_refresh & R_STRIDE) {
		$browser->position_cursor_fuzzy();
		$browser->position_cursor('.') unless defined $browser->currentfile;
	}
	if ($deferred_refresh & R_DIRLIST) {
		$_listing->show();
	}
	if ($deferred_refresh & R_DISKINFO) {
		$_pfm->screen->diskinfo->show();
	}
	if ($deferred_refresh & R_MENU) {
		$_frame->show_menu();
	}
	if ($deferred_refresh & R_PATHINFO) {
		$self->path_info();
	}
	if ($deferred_refresh & R_HEADINGS) {
		$_frame->show_headings(
			$_pfm->browser->swap_mode, $_frame->HEADING_DISKINFO);
	}
	if ($deferred_refresh & R_FOOTER) {
		$_frame->show_footer();
	}
	return $self;
}

=item path_info()

Redisplays information about the current directory path and the current
filesystem.

=cut

sub path_info {
	my ($self, $physical) = @_;
	my $directory = $_pfm->state->directory;
	my $path = $physical ? getcwd() : $directory->path;
	$self->at(PATHLINE, 0)
		 ->puts($self->pathline($path, $directory->device));
}

=item pathline()

Formats the information about the current directory path and the current
filesystem.

=cut

sub pathline {
	my ($self, $path, $dev, $p_baselen, $p_ellipssize) = @_;
	my $normaldevlen = 12;
	my $actualdevlen = max($normaldevlen, length($dev));
	# the three in the next exp is the length of the overflow char plus the '[]'
	my $maxpathlen   = $self->{_screenwidth} - $actualdevlen -3;
	$dev = $dev . ' 'x max($actualdevlen -length($dev), 0);
	# fit the path
	my ($disppath, $spacer, $overflow, $baselen, $ellipssize) =
		fitpath($path, $maxpathlen);
	# process the results
	$$p_baselen    = $baselen;
	$$p_ellipssize = $ellipssize;
	return $disppath . $spacer
		. ($overflow ? $_listing->NAMETOOLONGCHAR : ' ') . "[$dev]";
}

##########################################################################

=back

=head1 CONSTANTS

This package provides the B<R_*> constants which indicate which part of
the terminal screen needs to be redrawn. They are:

=over

=item R_NOP

No refresh action is required.

=item R_STRIDE

The cursor position needs to be validated.

=item R_MENU

Redisplay the menu.

=item R_PATHINFO

Redisplay the pathinfo (current directory and current device).

=item R_HEADINGS

Redisplay the column headings.

=item R_FOOTER

Redisplay the footer.

=item R_FRAME

A combination of R_FOOTER, R_HEADINGS, R_PATHINFO and R_MENU.

=item R_DISKINFO

Redisplay the disk- and directory info column.

=item R_DIRLIST

Redisplay the directory listing.

=item R_DIRFILTER

Decide which entries to display and apply the filter.

=item R_SCREEN

A combination of R_DIRFILTER, R_DIRLIST, R_DISKINFO and R_FRAME.

=item R_CLEAR

Clear the screen.

=item R_CLRSCR

A combination of R_CLEAR and R_SCREEN.

=item R_DIRSORT

The internal array with directory contents needs to be sorted again.

=item R_DIRCONTENTS

The current directory contents need to be read from disk again.

=item R_NEWDIR

Reinitialize directory-specific variables.

=item R_CHDIR

A combination of R_NEWDIR, R_DIRCONTENTS, R_DIRSORT and R_SCREEN.

=back

A refresh for a screen element may be requested by providing one or more of
these constants to set_deferred_refresh(), I<e.g.>

    $self->set_deferred_refresh(R_MENU | R_FOOTER);

=head1 SEE ALSO

pfm(1), App::PFM::Screen::Diskinfo(3pm), App::PFM::Screen::Frame(3pm),
App::PFM::Screen::Listing(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
