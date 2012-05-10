#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Screen 0.61
#
# Name:			App::PFM::Screen
# Version:		0.61
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2012-05-10
# Requires:		Term::ScreenColor
#

##########################################################################

=pod

=head1 NAME

App::PFM::Screen

=head1 DESCRIPTION

PFM class used for coordinating how all elements are displayed on screen.
This class extends B<Term::ScreenColor>.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Screen;

use base qw(App::PFM::Abstract Term::ScreenColor Exporter);

use App::PFM::Screen::Listing;
use App::PFM::Screen::Diskinfo qw(:constants);  # imports the LINE_* constants
use App::PFM::Screen::Frame    qw(:constants);  # imports the MENU_*, HEADING_*
												#         and FOOTER_* constants
use App::PFM::Util qw(fitpath max);
use App::PFM::Event;

use POSIX qw(getcwd);

use strict;
use locale;

use constant {
	BRACKETED_PASTE_START  => 'kpaste[',
	BRACKETED_PASTE_END    => 'kpaste]',
	BRACKETED_SCRAP        => 'kpaste[]',
	MOUSE_BUTTON_LEFT      =>  0,
	MOUSE_BUTTON_MIDDLE    =>  1,
	MOUSE_BUTTON_RIGHT     =>  2,
	MOUSE_BUTTON_UP        =>  3,
	MOUSE_BUTTON_MOTION    =>  32,
	MOUSE_MODIFIER_SHIFT   =>  4,
	MOUSE_MODIFIER_META    =>  8,
	MOUSE_MODIFIER_CONTROL => 16,
	MOUSE_WHEEL_UP         => 64,
	MOUSE_WHEEL_DOWN       => 65,
	DEVICE_SPEC_START      => '[',
	DEVICE_SPEC_END        => ']',
	PATH_PHYSICAL	=> 1,
	ERRORDELAY		=> 1,	 # in seconds (fractions allowed)
	IMPORTANTDELAY	=> 2,	 # extra time for important errors
	PATHLINE		=> 1,
	HEADINGLINE		=> 2,
	BASELINE		=> 3,
	R_NOP			=> 0,	 # no action was required, wait for new key
	R_STRIDE		=> 1,	 # validate cursor position (always done)
	R_MENU			=> 2,	 # reprint the menu
	R_PATHINFO		=> 4,	 # reprint the pathinfo
	R_HEADINGS		=> 8,	 # reprint the headings
	R_FOOTER		=> 16,	 # reprint the footer
#	R_FRAME					 # R_MENU + R_PATHINFO + R_HEADINGS + R_FOOTER
	R_DISKINFO		=> 32,	 # reprint the disk- and directory info column
	R_LISTING		=> 128,	 # redisplay directory listing
#	R_SCREEN				 # R_LISTING + R_DISKINFO + R_FRAME
	R_CLEAR			=> 512,	 # clear the screen
#	R_CLRSCR				 # R_CLEAR + R_SCREEN
	R_ALTERNATE		=> 1024, # switch screens according to 'altscreen_mode'
	R_NEWDIR		=> 8192, # re-init directory-specific vars
#	R_CHDIR					 # R_NEWDIR + R_SCREEN + R_STRIDE
};

# needs new invocations because of the calculations
use constant R_FRAME  => R_MENU | R_PATHINFO | R_HEADINGS | R_FOOTER;
use constant R_SCREEN => R_LISTING | R_DISKINFO | R_FRAME;
use constant R_CLRSCR => R_CLEAR | R_SCREEN;
use constant R_CHDIR  => R_NEWDIR | R_SCREEN | R_STRIDE;

use constant MOUSE_MODIFIER_ANY =>
		MOUSE_MODIFIER_SHIFT | MOUSE_MODIFIER_META | MOUSE_MODIFIER_CONTROL;

use constant CMDESCAPE_BREAK => 10;
use constant CMDESCAPES      => [
	'1 name',
	'2 name.ext',
	'3 curr path',
	'4 mountpoint',
	'5 swap path',
	'6 base path',
	'7 extension',
	'8 selection',
	'9 prev path',
	'0 ln target',
	'',
	'',
	'e editor',
	'E fg editor',
	'p pager',
	'v viewer',
#	'',
#	'{#prefix}',
#	'{%suffix}',
#	'{/find/repl}',
#	'{^} toupper',
#	'{,} tolower',
];

our %EXPORT_TAGS = (
	constants => [ qw(
		R_NOP
		R_STRIDE
		R_MENU
		R_PATHINFO
		R_HEADINGS
		R_FOOTER
		R_FRAME
		R_DISKINFO
		R_LISTING
		R_SCREEN
		R_CLEAR
		R_CLRSCR
		R_ALTERNATE
		R_NEWDIR
		R_CHDIR
		MOUSE_BUTTON_LEFT
		MOUSE_BUTTON_MIDDLE
		MOUSE_BUTTON_RIGHT
		MOUSE_BUTTON_UP
		MOUSE_MODIFIER_SHIFT
		MOUSE_MODIFIER_META
		MOUSE_MODIFIER_CONTROL
		MOUSE_MODIFIER_ANY
		MOUSE_WHEEL_UP
		MOUSE_WHEEL_DOWN
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{constants}};

our ($_pfm);

##########################################################################
# private subs

=item I<_init(App::PFM::Application $pfm [, App::PFM::Config $config ] )>

Called from the constructor. Initializes new instances. Stores the
application object for later use and instantiates a App::PFM::Screen::Frame
and App::PFM::Screen::Listing object.

Note that at the time of instantiation, the config file has probably
not yet been read.

=cut

sub _init {
	my ($self, $pfm, $config) = @_;
	$_pfm              = $pfm;
	$self->{_config}   = $config; # undefined, see on_after_parse_config
	$self->{_frame}    = App::PFM::Screen::Frame->new(   $pfm, $self, $config);
	$self->{_listing}  = App::PFM::Screen::Listing->new( $pfm, $self, $config);
	$self->{_diskinfo} = App::PFM::Screen::Diskinfo->new($pfm, $self, $config);
	$self->{_winheight}        = 0;
	$self->{_winwidth}         = 0;
	$self->{_screenheight}     = 0;
	$self->{_screenwidth}      = 0;
	$self->{_deferred_refresh} = 0;
	$self->{_color_mode}       = '';
	$self->{_chooser}          = undef;
	$self->{_on_resize}        = sub {
		$self->_catch_resize();
	};
	$SIG{WINCH} = $self->{_on_resize};
	# special key bindings for bracketed paste
	$self->def_key(BRACKETED_PASTE_START, "\e[200~");
	$self->def_key(BRACKETED_PASTE_END,   "\e[201~");
	# we cannot check the minimum size of the terminal yet, because the
	# config option 'force_minimum_size' is not yet known.
	return;
}

=item I<_catch_resize()>

Catches window resize signals (WINCH).

=cut

sub _catch_resize {
	my ($self) = @_;
	$self->{_wasresized} = 1;
	$SIG{WINCH} = $self->{_on_resize};
	return;
}

##########################################################################
# constructor, getters and setters

=item I<new(array @args)>

Specific constructor for App::PFM::Screen. Constructs an object based on
Term::ScreenColor.

=cut

sub new {
	my ($type, @args) = @_;
	$type = ref($type) || $type;
	my $self = Term::ScreenColor->new();
	$self->{_event_handlers} = {};
	bless($self, $type);
	$self->_init(@args);
	return $self;
}

=item I<screenwidth( [ int $screenwidth ] )>

=item I<screenheight( [ int $screenheight ] )>

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

=item I<frame()>

=item I<listing()>

=item I<diskinfo()>

Getters for the App::PFM::Screen::Frame, App::PFM::Screen::Listing
and App::PFM::Screen::Diskinfo objects.

=cut

sub frame {
	my ($self) = @_;
	return $self->{_frame};
}

sub listing {
	my ($self) = @_;
	return $self->{_listing};
}

sub diskinfo {
	my ($self) = @_;
	return $self->{_diskinfo};
}

=item I<wasresized( [ bool $wasresized ] )>

Getter/setter for the flag that indicates that the window was resized
and needs to be updated.

=cut

sub wasresized {
	my ($self, $value) = @_;
	$self->{_wasresized} = $value if defined $value;
	return $self->{_wasresized};
}

=item I<color_mode( [ string $colormodename ] )>

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

=item I<chooser( [ App:PFM::Browser $chooser ] )>

Getter/setter for a I<chooser> object for which this screen object
should perform refreshes. This alters the behavior of the refresh()
method based on the I<chooser>'s SCREENTYPE.

To undefine the I<chooser>, call this method with a zero argument.

=cut

sub chooser {
	my ($self, $value) = @_;
	if (ref $value) {
		$self->{_chooser} = $value;
	} elsif (defined $value) {
		$self->{_chooser} = undef;
	}
	return $self->{_chooser};
}

##########################################################################
# public subs

=item I<raw_noecho()>

=item I<cooked_echo()>

Sets the terminal to I<raw> or I<cooked> mode.

=cut

sub raw_noecho {
	my ($self) = @_;
	$self->raw()->noecho();
	return $self;
}

sub cooked_echo {
	my ($self) = @_;
	$self->cooked()->echo();
	return $self;
}

=item I<mouse_enable()>

=item I<mouse_disable()>

Tells the terminal to start/stop receiving information about the mouse.

=cut

sub mouse_enable {
	my ($self) = @_;
#	print "\e[?1002h"; # cell motion tracking: mouse-down, mouse-up and motion
#	print "\e[?1000h"; # normal tracking     : mouse-down, mouse-up
	print "\e[?9h";    # X10 compatibility   : mouse-down only
	return $self;
}

sub mouse_disable {
	my ($self) = @_;
#	print "\e[?1002l";
#	print "\e[?1000l";
	print "\e[?9l";
	return $self;
}

=item I<bracketed_paste_on()>

=item I<bracketed_paste_off()>

Switches bracketed paste mode on and off. Bracketed paste mode is used
to intercept paste actions when C<pfm> is expecting a single command key.

=cut

sub bracketed_paste_on {
	my ($self) = @_;
	print "\e[?2004h";
	return $self;
}

sub bracketed_paste_off {
	my ($self) = @_;
	print "\e[?2004l";
	return $self;
}

=item I<alternate_on()>

=item I<alternate_off()>

Switches to alternate terminal screen and back.

=cut

sub alternate_on {
	my ($self) = @_;
	print "\e[?47h";
	return $self;
}

sub alternate_off {
	my ($self) = @_;
	print "\e[?47l";
	return $self;
}

=item I<getch()>

Overrides the Term::ScreenColor version of getch().
If a bracketed paste is received, it is returned as one unit.

=cut

sub getch {
	my ($self) = @_;
	my $key = $self->SUPER::getch();
	my $buffer = '';
	if ($key eq BRACKETED_PASTE_START) {
		while (1) {
			$key = $self->SUPER::getch();
			last if $key eq BRACKETED_PASTE_END;
			$buffer .= $key;
		}
		# flag that a paste was received
		$key = BRACKETED_SCRAP;
	}
	return wantarray ? ($key, $buffer) : $key;
}

=item I<calculate_dimensions()>

Calculates the height and width of the screen.

=cut

sub calculate_dimensions {
	my ($self) = @_;
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

=item I<check_minimum_size()>

Tests whether the terminal size is smaller than the minimum supported
24 rows or 80 columns.  If so, sends an escape sequence to adjust the
terminal size.

=cut

sub check_minimum_size {
	my ($self) = @_;
	my ($newwidth, $newheight);
	return if ($self->{_winwidth} >= 80 and $self->{_winheight} >= 24);
	if ($self->{_config}->{force_minimum_size}) {
		$newwidth  = $self->{_winwidth}  < 80 ? 80 : $self->{_winwidth};
		$newheight = $self->{_winheight} < 24 ? 24 : $self->{_winheight};
		print "\e[8;$newheight;${newwidth}t";
		return 1;
	}
	return 0;
}

=item I<fit()>

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
	$self->set_deferred_refresh(R_CLRSCR); # D_FILTER necessary?
	# History is interested (wants to set terminal object's terminal width)
	# Browser is interested (wants to validate cursor position)
	$self->fire(App::PFM::Event->new({
		name   => 'after_resize_window',
		type   => 'soft',
		origin => $self,
	}));
	return $self;
}

=item I<handleresize()>

Makes the contents fit on the screen again after a resize. Validates
the cursor position.

=cut

sub handleresize {
	my ($self) = @_;
	$self->{_wasresized} = 0;
	$self->fit();
	return $self;
}

=item I<pending_input(float $delay)>

Returns a boolean indicating that there is input ready to be processed.
The delay indicates how long should be waited for input.

=cut

sub pending_input {
	my ($self, $delay) = @_;
	my $input_ready = length($self->{IN}) ||
		$self->{_wasresized} || $self->key_pressed($delay);
	while ($input_ready == -1 and $! == 4) {
		# 'Interrupted system call'
		$input_ready = $self->key_pressed(0.1);
	}
	return $input_ready;
}

=item I<get_event()>

Returns an App::PFM::Event object of type B<mouse>, B<key> or B<resize>,
containing the event that was currently pending (as determined by
pending_input()).

=cut

sub get_event {
	my ($self) = @_;
	# resize event
	if ($self->{_wasresized}) {
		$self->{_wasresized} = 0;
		return App::PFM::Event->new({
			name   => 'resize_window',
			origin => $self,
			type   => 'resize',
		});
	}
	# must be keyboard/mouse/paste input here
	my ($key, $buffer) = $self->getch();
	my $event = App::PFM::Event->new({
		name   => 'after_receive_user_input',
		origin => $self,
	});
	# paste event
	if ($key eq BRACKETED_SCRAP) {
		$event->{type} = 'paste';
		$event->{data} = $buffer;
		return $event;
	}
	# key event
	if ($key ne 'kmous') {
		$event->{type} = 'key';
		$event->{data} = $key;
		return $event;
	}
	
	# mouse event
	$event->{type} = 'mouse';
	$event->{data} = $key; # 'kmous'

	$self->noecho();
	$event->{mousebutton} = ord($self->getch()) - oct(40);
	$event->{mousecol}    = ord($self->getch()) - oct(41);
	$event->{mouserow}    = ord($self->getch()) - oct(41);
	$self->echo();

	$event->{mousemodifier} = $event->{mousebutton} &  MOUSE_MODIFIER_ANY;
	$event->{mousebutton}   = $event->{mousebutton} & ~MOUSE_MODIFIER_ANY;

	return $event;
}

=item I<< show_frame(hashref { menu => int $menu_mode, >>
I<< footer => int $footer_mode, headings => int $heading_mode, >>
I<< prompt => string $prompt } ) >>

Uses the App::PFM::Screen::Frame object to redisplay the frame.

=cut

sub show_frame {
	my ($self, $options) = @_;
	$self->{_frame}->show($options);
	return $self;
}

=item I<clear_footer()>

Calls App::PFM::Screen::Frame::clear_footer() and schedules a refresh
for the footer.

=cut

sub clear_footer {
	my ($self) = @_;
	$self->{_frame}->show_footer(FOOTER_NONE);
	$self->set_deferred_refresh(R_FOOTER);
	return $self;
}

=item I<select_next_color(bool $direction)>

Finds the next colorset to use. If I<direction> is true, cycle forward;
else backward.

=cut

sub select_next_color {
	my ($self, $direction) = @_;
	my @colorsetnames = @{$self->{_config}->{colorsetnames}};
	my $index = $#colorsetnames;
	while ($self->{_color_mode} ne $colorsetnames[$index] and $index > 0) {
		$index--;
	}
	if ($direction) {
		if ($index-- <= 0) { $index = $#colorsetnames }
	} else {
		if ($index++ >= $#colorsetnames) { $index = 0 }
	}
	$self->{_color_mode} = $colorsetnames[$index];
	$self->color_mode($self->{_color_mode});
	# Directory is interested (wants to reformat files)
	# History is interested (wants to set ornaments).
	$self->fire(App::PFM::Event->new({
		name   => 'after_set_color_mode',
		type   => 'soft',
		origin => $self,
	}));
	return $self;
}

=item I<putcentered(string $message)>

Displays a message on the current screen line, horizontally centered.

=cut

sub putcentered {
	my ($self, $string) = @_;
	$self->puts(' ' x (($self->{_screenwidth} - length $string)/2) . $string);
	return $self;
}

=item I<putmessage(string $message_part1 [, string $message_part2 ... ] )>

Displays a message in the configured message color.
Accepts an array with message fragments.

=cut

sub putmessage {
	my ($self, @message) = @_;
	my $framecolors = $self->{_config}->{framecolors};
	if ($framecolors) {
		$self->putcolored(
			$framecolors->{$self->{_color_mode}}{message},
			join '', @message);
	} else {
		$self->puts(join '', @message);
	}
	return $self;
}

=item I<pressanykey()>

Displays a message and waits for a key to be pressed.

=cut

sub pressanykey {
	my ($self) = @_;
	$self->putmessage("\r\n*** Hit any key to continue ***");
	$self->raw_noecho();
	if ($_pfm->browser->mouse_mode &&
		$self->{_config}->{clickiskeypresstoo}
	) {
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
	$self->cooked_echo()->puts("\n")->raw_noecho();
	$self->mouse_enable() if $_pfm->browser->{mouse_mode};
	$self->alternate_on() if $self->{_config}->{altscreen_mode};
	$self->handleresize() if $self->{_wasresized};
	return $self;
}

=item I<ok_to_remove_marks()>

Prompts the user for confirmation since they are about to lose
their marks in the current directory.

=cut

sub ok_to_remove_marks {
	my ($self) = @_;
	my $sure;
	if ($self->{_config}{remove_marks_ok} or
		$self->{_diskinfo}->mark_info() <= 0)
	{
		return 1;
	}
	$self->{_diskinfo}->show();
	$self->clear_footer()
		->at(0,0)->clreol()
		->putmessage('OK to remove marks [Y/N]? ');
	$sure = $self->getch();
	$self->set_deferred_refresh(R_FRAME);
	return ($sure =~ /y/i);
}

=item I<display_error(string $message_part1 [, string $message_part2 ... ] )>

Displays an error which may be passed as an array with message
fragments. Waits for a key to be pressed and returns the keypress.

=cut

sub display_error {
	my $self = shift;
	$self->putmessage(@_);
	return $self->error_delay();
}

=item I<neat_error(string $message_part1 [, string $message_part2 ... ] )>

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

=item I<error_delay()>

=item I<important_delay()>

Waits for a key to be pressed. Returns the keypress.

=cut

sub error_delay {
	return $_[0]->key_pressed(ERRORDELAY);
}

sub important_delay {
	return $_[0]->key_pressed(IMPORTANTDELAY);
}

=item I<set_deferred_refresh(int $elements)>

Flags screen elements as 'need to be redrawn'. The B<R_*> constants
(see below) may be used to indicate which elements should be redrawn.

=cut

sub set_deferred_refresh {
	my ($self, $elements) = @_;
	$self->{_deferred_refresh} |= $elements;
	return $self;
}

=item I<unset_deferred_refresh(int $elements)>

Flags screen elements as 'do not need to be redrawn'. The B<R_*>
constants (see below) may be used here.

=cut

sub unset_deferred_refresh {
	my ($self, $elements) = @_;
	$self->{_deferred_refresh} &= ~$elements;
	return $self;
}

=item I<refresh_headings()>

Redisplays the headings if they have been flagged as 'needs to be redrawn'.

=cut

sub refresh_headings {
	my ($self) = @_;
	my $headingtype = HEADING_DISKINFO;
	if ($self->{_deferred_refresh} & R_HEADINGS) {
		if ($self->{_chooser}) {
			$headingtype = $self->{_chooser}->HEADINGTYPE;
		}
		$self->{_frame}->show_headings(
			$_pfm->browser->swap_mode, $headingtype);
		$self->{_deferred_refresh} &= ~R_HEADINGS;
	}
	return $self;
}

=item I<refresh()>

Redisplays all screen elements that have been flagged as 'need to be redrawn'.

=cut

sub refresh {
	my ($self)           = @_;
	my $browser          = $_pfm->browser;
	my $chooser          = $self->{_chooser};
	my $deferred_refresh = $self->{_deferred_refresh};
	my $headingtype      = HEADING_DISKINFO;
	my $footertype       = undef;
	my $prompt           = $chooser ? $chooser->prompt : undef;
	
	if ($deferred_refresh & R_ALTERNATE) {
		if ($self->{_config}->{altscreen_mode}) {
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
		$self->{_frame}->show({ prompt => $prompt });
	}
	# now in order of severity
	if ($deferred_refresh & R_NEWDIR) {
		# it's dangerous to leave multiple_mode on when changing directories
		# ('autoexitmultiple' is only for leaving it on between commands)
		$_pfm->state->{multiple_mode} = 0;
	}

	# refresh the directory, which may request more refreshing
	$_pfm->state->directory->refresh();
	$deferred_refresh = $self->{_deferred_refresh};

	# refresh the filelisting
	if ($deferred_refresh & R_STRIDE) {
		if ($chooser) {
			$chooser->validate_position();
		} else {
			$browser->position_cursor_fuzzy();
			$browser->position_cursor('.') unless defined $browser->currentfile;
		}
	}

	# validations may have requested more refreshing
	$deferred_refresh = $self->{_deferred_refresh};

	if ($deferred_refresh & R_LISTING) {
		if ($chooser and $chooser->SCREENTYPE == R_LISTING) {
			$chooser->list_items();
		} else {
			$self->{_listing}->show();
		}
	}
	if ($deferred_refresh & R_DISKINFO) {
		if ($chooser and $chooser->SCREENTYPE == R_DISKINFO) {
			$chooser->list_items();
		} else {
			$self->{_diskinfo}->show();
		}
	}
	if ($deferred_refresh & R_MENU) {
		$self->{_frame}->show_menu_or_prompt({ prompt => $prompt });
	}
	if ($deferred_refresh & R_PATHINFO) {
		$self->path_info();
	}
	if ($deferred_refresh & R_HEADINGS) {
		if ($chooser) {
			$headingtype = $chooser->HEADINGTYPE;
		}
		$self->{_frame}->show_headings(
			$_pfm->browser->swap_mode, $headingtype);
	}
	if ($deferred_refresh & R_FOOTER) {
		if ($chooser) {
			$footertype = $chooser->FOOTERTYPE;
		}
		$self->{_frame}->show_footer($footertype);
	}
	$self->{_deferred_refresh} = 0;
	return $self;
}

=item I<path_info(bool $physical)>

Redisplays information about the current directory path and the current
filesystem. If the argument flag I<physical> is set, the physical
pathname of the current directory is shown.

=cut

sub path_info {
	my ($self, $physical) = @_;
	my $directory = $_pfm->state->directory;
	my $path = $physical ? getcwd() : $directory->path;
	$self->at(PATHLINE, 0)
		 ->puts($self->pathline($path, $directory->device));
	 return $self;
}

=item I<pathline(string $path, string $device [, ref $baselen, ref $ellipssize ] )>

Formats the information about the current directory path and the current
filesystem.  The reference arguments are used by the CommandHandler for
finding out where in the pathline the mouse was clicked. I<baselen> is
set to the length of the pathline before the ellipsis string.
I<ellipssize> is the length of the ellipsis string.

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
		. ($overflow ? $self->{_listing}->NAMETOOLONGCHAR : ' ')
		. DEVICE_SPEC_START . $dev . DEVICE_SPEC_END;
}

=item I<list_escapes()>

List the user-available recognized escapes.

=cut

sub list_escapes
{
	my ($self) = @_;
	my $printline  = $self->BASELINE;
	my $infocol    = $self->diskinfo->infocol;
	my $e          = $self->{_config}{e};
	my @cmdescapes = @{CMDESCAPES()};
	$self->diskinfo->clearcolumn()->set_deferred_refresh(R_DISKINFO);
	foreach (@cmdescapes[0 .. CMDESCAPE_BREAK],
		"$e literal $e",
		@cmdescapes[CMDESCAPE_BREAK+1 .. $#cmdescapes])
	{
		if ($printline <= $self->BASELINE + $self->screenheight) {
			$self->at($printline++, $infocol)
				->puts(sprintf(' %s', ((length) ? $e . $_ : $_)));
		}
	}
	return;
}

=item I<on_after_parse_usecolor(App::PFM::Event $event)>

Applies the 'usecolor' config option to the Term::ScreenColor(3pm) object.

=cut

sub on_after_parse_usecolor {
	my ($self, $event) = @_;
	$self->colorizable($event->{origin}{usecolor});
	return $self;
}

=item I<on_after_parse_config(App::PFM::Event $event)>

Applies the config settings when the config file has been read and parsed.

=cut

sub on_after_parse_config {
	my ($self, $event) = @_;
	my ($keydefs, $lunchboxcolorset, $defaultcolorset, $newcolormode);
	# store config
	my $pfmrc        = $event->{data};
	$self->{_config} = $event->{origin};
	# make cursor very visible
	system ('tput', $pfmrc->{cursorveryvisible} ? 'cvvis' : 'cnorm');
	# check minimum size
	$self->check_minimum_size();
	# set colorizable
	$self->on_after_parse_usecolor($event);
	# additional key definitions 'keydef'
	$keydefs = $pfmrc->{'keydef[*]'};
	if ($pfmrc->{"keydef[$ENV{TERM}]"}) {
		$keydefs .= ':' . $pfmrc->{"keydef[$ENV{TERM}]"};
	}
	$keydefs =~ s/(\\e|\^\[)/\e/gi;
	# see if we have esc_timeout
	if (defined $self->{_config}{esc_timeout}) {
		$self->timeout($self->{_config}{esc_timeout});
	}
	# there can be no colons (:) in escape sequences
	foreach (split /:/, $keydefs) {
		/^(\w+)=(.*)/ and $self->def_key($1, $2);
	}
	# determine color_mode if unset
	$lunchboxcolorset = $event->{lunchbox}{colorset};
	if (!defined($lunchboxcolorset)) {
		$lunchboxcolorset = '';
	}
	$defaultcolorset  = $pfmrc->{defaultcolorset};
	$newcolormode =
		(length($self->{_color_mode})
			? $self->{_color_mode}
			: defined $self->{_config}{dircolors}{$lunchboxcolorset}
				? $lunchboxcolorset
				: (defined($ENV{ANSI_COLORS_DISABLED})
					? 'off'
					: defined $self->{_config}{dircolors}{$defaultcolorset}
						? $defaultcolorset
						: (defined $self->{_config}{dircolors}{ls_colors}
							? 'ls_colors'
							: $self->{_config}{colorsetnames}[0])));
	# init colorsets
	$self->color_mode($newcolormode);
	$self->set_deferred_refresh(R_ALTERNATE);
	$self->diskinfo->on_after_parse_config($event);
	$self->listing->on_after_parse_config($event);
	return $self;
}

=item I<on_shutdown(bool $altscreen_mode [, bool $silent ] )>

Called when the application is shutting down. I<altscreen_mode>
indicates if the State has used the alternate screen buffer.

=cut

sub on_shutdown {
	my ($self, $altscreen_mode, $silent) = @_;
	my $message = 'Goodbye from your Personal File Manager!';
	# reset bracketed paste mode twice: gnome-terminal is shown to have
	# different bracketed paste settings for main and alternate screen buffers
	$self->cooked_echo()
		->mouse_disable()
		->bracketed_paste_off()
		->alternate_off()
		->bracketed_paste_off();
	system qw(tput cnorm) if $self->{_config}{cursorveryvisible};

	# in silent mode, just reset the terminal to its original state;
	# don't clear the screen or print any messages.
	return if $silent;

	if ($altscreen_mode) {
		print "\n";
	} else {
		if ($self->{_config}{clsonexit}) {
			$self->clrscr();
		} else {
			$self->at(0,0)->putcentered($message)->clreol()
				->at(PATHLINE, 0);
		}
	}
	if ($altscreen_mode or !$self->{_config}{clsonexit}) {
		$self->at($self->screenheight + BASELINE + 1, 0)
				->clreol();
	}
	return $self;
}

##########################################################################

=back

=head1 CONSTANTS

This package provides the B<R_*> constants which indicate which
part of the terminal screen needs to be redrawn.
They can be imported with C<use App::PFM::Screen qw(:constants)>.

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

=item R_LISTING

Redisplay the directory listing.

=item R_SCREEN

A combination of R_LISTING, R_DISKINFO and R_FRAME.

=item R_CLEAR

Clear the screen.

=item R_CLRSCR

A combination of R_CLEAR and R_SCREEN.

=item R_NEWDIR

Reinitialize directory-specific variables.

=item R_CHDIR

A combination of R_NEWDIR, R_SCREEN and R_STRIDE.

=back

A refresh need for a screen element may be flagged by providing
one or more of these constants to set_deferred_refresh(), I<e.g.>

	$screen->set_deferred_refresh(R_MENU | R_FOOTER);

The actual refresh will be performed on calling:

	$screen->refresh();

This will also reset the refresh flags.

=head1 SEE ALSO

pfm(1), App::PFM::Screen::Diskinfo(3pm), App::PFM::Screen::Frame(3pm),
App::PFM::Screen::Listing(3pm), Term::ScreenColor(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
