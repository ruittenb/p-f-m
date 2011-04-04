#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen 2010-03-27 v0.01
#
# Name:			PFM::Screen.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Requires:		Term::ScreenColor
# Description:	PFM class used for controlling the screen.
#

##########################################################################
# declarations

package PFM::Screen;

use base qw(PFM::Abstract Term::ScreenColor);

use PFM::Screen::Frame;
use PFM::Screen::Listing;

use constant {
	ERRORDELAY		=> 1,	# in seconds (fractions allowed)
	IMPORTANTDELAY	=> 2,	# extra time for important errors
	PATHLINE		=> 1,
	BASELINE		=> 3,
	DISKINFOLINE	=> 4,
	DIRINFOLINE		=> 9,
	MARKINFOLINE	=> 15,
	USERINFOLINE	=> 21,
	DATEINFOLINE	=> 22,
	R_NOP			=> 0,		# no action was required, wait for new key
	R_STRIDE		=> 1,		# refresh currentfile, validate cursor position (always done)
	R_MENU			=> 2,		# reprint the menu (header)
	R_PATHINFO		=> 4,		# reprint the pathinfo
	R_HEADINGS		=> 8,		# reprint the headings
	R_FOOTER		=> 16,		# reprint the footer
#	R_FRAME						# combines R_MENU, R_PATHINFO, R_HEADINGS and R_FOOTER
	R_DISKINFO		=> 32,		# reprint the disk- and directory info column
	R_DIRLIST		=> 64,		# redisplay directory listing
	R_DIRFILTER		=> 128,		# decide which entries to display (init @showncontents)
#	R_SCREEN					# combines R_DIRFILTER, R_DIRLIST, R_DISKINFO and R_FRAME
	R_CLEAR			=> 256,		# clear the screen
#	R_CLRSCR					# combines R_CLEAR and R_SCREEN
	R_DIRSORT		=> 512,		# resort @dircontents
	R_DIRCONTENTS	=> 1024,	# reread directory contents
#	R_CHDIR						# re-init directory-specific vars
	R_NEWDIR		=> 2048,	# combines R_NEWDIR, R_DIRCONTENTS, R_DIRSORT, R_SCREEN
	R_INIT_SWAP		=> 4096,	# after reading the directory, we should be swapped immediately
	R_QUIT			=> 1048576,	# exit from program
};

# needs new invocations because of the calculations
use constant R_FRAME  => R_MENU | R_PATHINFO | R_HEADINGS | R_FOOTER;
use constant R_SCREEN => R_DIRFILTER | R_DIRLIST | R_DISKINFO | R_FRAME;
use constant R_CLRSCR => R_CLEAR | R_SCREEN;
use constant R_CHDIR  => R_NEWDIR | R_DIRCONTENTS | R_DIRSORT | R_SCREEN | R_STRIDE;

my ($_pfm, $_frame, $_listing,
	$_screenwidth, $_screenheight, $_deferred_refresh, $_wasresized,
);

##########################################################################
# private subs

=item _init()

Called from the constructor. Initializes new instances. Stores the
application object for later use and instantiates a PFM::Screen::Frame
and PFM::Screen::Listing object.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm		= $pfm;
	$_frame		= new PFM::Screen::Frame($pfm);
	$_listing	= new PFM::Screen::Listing($pfm);
	$SIG{WINCH} = \&_resizecatcher;
}

=item _resizecatcher()

Catches window resize signals (WINCH).

=cut

sub _resizecatcher {
	$_wasresized = 1;
	$SIG{WINCH} = \&_resizecatcher;
}

##########################################################################
# constructor, getters and setters

=item screenwidth()

=item screenheight()

Getters/setters for the dimensions of the screen.

=cut

sub screenwidth {
	my ($self, $value) = @_;
	$_screenwidth = $value if defined $value;
	return $_screenwidth;
}

sub screenheight {
	my ($self, $value) = @_;
	$_screenheight = $value if defined $value;
	return $_screenheight;
}

=item frame()

Getter for the PFM::Screen::Frame object.

=cut

sub frame {
	return $_frame;
}

=item listing()

Getter for the PFM::Screen::Listing object.

=cut

sub listing {
	return $_listing;
}

##########################################################################
# public subs

sub stty_raw {
	my $self = shift;
	system qw(stty raw -echo);
	$self->noecho();
}

sub stty_cooked {
	my $self = shift;
	system qw(stty -raw echo);
	$self->echo();
}

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

sub recalculate_dimensions {
	my $self = shift;
	if ($self->rows()) { $_screenheight = $self->rows() - BASELINE - 2 }
	if ($self->cols()) { $_screenwidth  = $self->cols() }
	return $self;
}

=item draw_frame()

Dispatches a request to redraw the frame to the PFM::Screen::Frame object.

=cut

sub draw_frame {
	my $self = shift;
	$_frame->draw();
	return $self;
}

=item putcentered()

Displays a message on the current screen line, vertically centered.

=cut

sub putcentered {
	my ($self, $string) = @_;
	$self->puts(' ' x (($_screenwidth - length $string)/2) . $string);
}

=item putmessage()

Displays a message in the configured message color.

=cut

sub putmessage {
	my $self = shift;
	$self->putcolored(
		$_pfm->config->{framecolors}{$_pfm->state->{color_mode}}{message},
		@_
	);
}

=item display_error()

Displays an error and waits for a key to be pressed.
Returns the keypress.

=cut

sub display_error {
	my $self = shift;
	$self->putmessage(@_);
	return $self->error_delay();
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
	$_deferred_refresh |= $bits;
	return $self;
}

=item refresh()

Redraws all screen elements that need to be redrawn.

=cut

sub refresh {
	my $self = shift;
	# TODO
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
