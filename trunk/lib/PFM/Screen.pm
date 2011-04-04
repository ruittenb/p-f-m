#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen 0.03
#
# Name:			PFM::Screen.pm
# Version:		0.03
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
# Requires:		Term::ScreenColor
#

##########################################################################

=pod

=head1 NAME

PFM::Screen

=head1 DESCRIPTION

PFM class used for coordinating how all elements are displayed on screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Screen;

use base qw(PFM::Abstract Term::ScreenColor);

use PFM::Screen::Frame;
use PFM::Screen::Listing;
use PFM::Screen::Diskinfo;

use constant {
	NAMETOOLONGCHAR => '+',
	ERRORDELAY		=> 1,		# in seconds (fractions allowed)
	IMPORTANTDELAY	=> 2,		# extra time for important errors
	PATHLINE		=> 1,
	BASELINE		=> 3,
	R_NOP			=> 0,		# no action was required, wait for new key
	R_STRIDE		=> 1,		# validate cursor position (always done)
	R_MENU			=> 2,		# reprint the menu (header)
	R_PATHINFO		=> 4,		# reprint the pathinfo
	R_HEADINGS		=> 8,		# reprint the headings
	R_FOOTER		=> 16,		# reprint the footer
#	R_FRAME						# combines R_MENU, R_PATHINFO, R_HEADINGS and R_FOOTER
	R_DISKINFO		=> 32,		# reprint the disk- and directory info column
	R_DIRLIST		=> 64,		# redisplay directory listing
	R_DIRFILTER		=> 128,		# decide which entries to display (init @showncontents)
#	R_SCREEN					# combines R_DIRFILTER, R_DIRLIST, R_DISKINFO and R_FRAME
	R_CLEAR			=> 255,		# clear the screen
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

my ($_pfm, $_frame, $_listing, $_diskinfo,
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
	$_diskinfo	= new PFM::Screen::Diskinfo($pfm);
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

=item new()

Specific constructor for PFM::Screen. Constructs an object based on
Term::ScreenColor.

=cut

sub new {
	my $type = shift;
	$type = ref($type) || $type;
	my $self = new Term::ScreenColor();
	bless($self, $type);
	$self->_init(@_);
	return $self;
}

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

=item listing()

=item diskinfo()

Getters for the PFM::Screen::Frame, PFM::Screen::Listing
and PFM::Screen::Diskinfo objects.

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

##########################################################################
# public subs

=item stty_raw()

=item stty_cooked()

Set the terminal to I<raw> or I<cooked> mode.

=cut

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

=item mouse_enable()

=item mouse_disable()

Tell the terminal to start/stop receiving information about the mouse.

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

Switch to alternate terminal screen and back.

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
		$_screenheight = $newheight - BASELINE - 2;
		$_screenwidth  = $newwidth;
	}
	return $self;
}

=item fit()

Recalculates the screen size and adjust the layouts.

=cut

sub fit {
	my $self = shift;
	$self->resize();
	$self->calculate_dimensions();
	$self->listing->makeformatlines();
	$self->listing->reformat();
	$self->set_deferred_refresh(R_CLRSCR);
}

=item handleresize()

Makes the contents fit on the screen again after a resize. Validates
the cursor position.

=cut

sub handleresize {
	my $self = shift;
	$_wasresized = 0;
	$self->fit();
	$_pfm->browser->validate_position();
	return $self;
}

=item pending_input()

Returns a boolean indicating that there is input ready to be processed.

=cut

sub pending_input {
	my ($self, $delay) = @_;
	return (length($self->{IN}) || $_wasresized || $self->key_pressed($delay));
}

=item show_frame()

Uses the PFM::Screen::Frame object to redisplay the frame.

=cut

sub show_frame {
	my $self = shift;
	$_frame->show();
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

=item pressanykey()

Displays a message and waits for a key to be pressed.

=cut

sub pressanykey {
	my $self = shift;
	$self->putmessage("\r\n*** Hit any key to continue ***");
	$self->stty_raw();
	if ($_pfm->state->{mouse_mode} && $_pfm->config->{clickiskeypresstoo}) {
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
	$self->mouse_enable() if $_pfm->state->{mouse_mode};
	$self->alternate_on() if $_pfm->config->{altscreen_mode};
	$self->handleresize() if $_wasresized;
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

=item unset_deferred_refresh()

Flags a screen element as 'does not need to be redrawn'.

=cut

sub unset_deferred_refresh {
	my ($self, $bits) = @_;
	$_deferred_refresh &= ~$bits;
	return $self;
}

=item refresh()

Redisplays all screen elements that have been flagged as 'needs to be redrawn'.

=cut

sub refresh {
	my $self      = shift;
	my $directory = $_pfm->state->directory;
	my $browser   = $_pfm->browser;
	
	# show frame as soon as possible: this looks better on slow terminals
	if ($_deferred_refresh & R_CLEAR) {
		$self->clrscr();
	}
	if ($_deferred_refresh & R_FRAME) {
		$_frame->show();
	}
	# now in order of severity
	if ($_deferred_refresh & R_DIRCONTENTS or
		$_deferred_refresh & R_DIRSORT)
	{
		$directory->init_dircount();
		$browser->position_at($browser->currentfile->{name});
	}
	if ($_deferred_refresh & R_DIRCONTENTS) {
		$directory->readcontents();
	}
	if ($_deferred_refresh & R_DIRSORT) {
		$directory->sortcontents();
	}
	if ($_deferred_refresh & R_DIRFILTER) {
		$directory->filtercontents();
	}
	if ($_deferred_refresh & R_STRIDE) {
		$browser->position_cursor();
		$browser->position_cursor('.') unless defined $browser->currentfile;
	}
	if ($_deferred_refresh & R_DIRLIST) {
		$_listing->show();
	}
	if ($_deferred_refresh & R_DISKINFO) {
		$_pfm->diskinfo->show();
	}
	if ($_deferred_refresh & R_MENU) {
		$_frame->show_menu();
	}
	if ($_deferred_refresh & R_PATHINFO) {
		$self->path_info();
	}
	if ($_deferred_refresh & R_HEADINGS) {
		$_frame->show_headings(
			$_pfm->state->{swap_mode}, $_frame->HEADING_DISKINFO);
	}
	if ($_deferred_refresh & R_FOOTER) {
		$_frame->show_footer();
	}
	$_deferred_refresh = 0;
}

=item path_info()

Redisplays information about the current directory path and the current
filesystem.

=cut

sub path_info {
	my $self = shift;
	my $directory = $_pfm->state->directory;
	$self->at(PATHLINE, 0)
		 ->puts($self->pathline($directory->path, $directory->device));
}

=item pathline()

Formats the information about the current directory path and the current
filesystem.

=cut

sub pathline {
	my ($path, $dev, $displen, $ellipssize) = @_;
	my $overflow	 = ' ';
	my $ELLIPSIS	 = '..';
	my $normaldevlen = 12;
	my $actualdevlen = max($normaldevlen, length($dev));
	# the three in the next exp is the length of the overflow char plus the '[]'
	my $maxpathlen   = $_screenwidth - $actualdevlen -3;
	my ($restpathlen, $disppath);
	$dev = $dev . ' 'x max($actualdevlen -length($dev), 0);
	FIT: {
		# the next line is supposed to contain an assignment
		unless (length($path) <= $maxpathlen and $disppath = $path) {
			# no fit: try to replace (part of) the name with ..
			# we will try to keep the first part e.g. /usr1/ because this often
			# shows the filesystem we're on; and as much as possible of the end
			unless ($path =~ /^(\/[^\/]+?\/)(.+)/) {
				# impossible to replace; just truncate
				# this is the case for e.g. /some_ridiculously_long_directory_name
				$disppath = substr($path, 0, $maxpathlen);
				$$displen = $maxpathlen;
				$overflow = $NAMETOOLONGCHAR;
				last FIT;
			}
			($disppath, $path) = ($1, $2);
			$$displen = length($disppath);
			# the one being subtracted is for the '/' char in the next match
			$restpathlen = $maxpathlen -length($disppath) -length($ELLIPSIS) -1;
			unless ($path =~ /(.*?)(\/.{1,$restpathlen})$/) {
				# impossible to replace; just truncate
				# this is the case for e.g. /usr/some_ridiculously_long_directory_name
				$disppath = substr($disppath.$path, 0, $maxpathlen);
				$overflow = $_listing->NAMETOOLONGCHAR;
				last FIT;
			}
			# pathname component candidate for replacement found; name will fit
			$disppath .= $ELLIPSIS . $2;
			$$ellipssize = length($1) - length($ELLIPSIS);
		}
	}
	return $disppath . ' 'x max($maxpathlen -length($disppath), 0)
		 . $overflow . "[$dev]";
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
