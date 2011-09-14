#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::YourCommands 0.04
#
# Name:			App::PFM::Browser::YourCommands
# Version:		0.04
# Author:		Rene Uittenbogaard
# Created:		2011-03-09
# Date:			2011-03-09
#

##########################################################################

=pod

=head1 NAME

App::PFM::Browser::YourCommands

=head1 DESCRIPTION

This class is responsible for the browsing functionality that is specific
for browsing through Your commands and selecting one.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Browser::YourCommands;

use base qw(App::PFM::Browser App::PFM::Abstract);

use App::PFM::Screen::Frame qw(:constants); # MENU_*, HEADING_*, and FOOTER_*
use App::PFM::Screen        qw(:constants); # R_*
use App::PFM::Util          qw(alphabetically);

use strict;
use locale;

use constant {
	SHOW_CLOCK => 0,
};

use constant MOTION_COMMANDS_EXCEPT_SPACE =>
	qr/^(?:[-+\cF\cB\cD\cU]|ku|kd|pgup|pgdn|home|end)$/io; # no 'j', 'k'

##########################################################################
# private subs

=item _init(App::PFM::Screen $screen, App::PFM::Config $config,
App::PFM::State $state)

Initializes new instances. Called from the constructor.
Stores the application's current state internally.

=cut

sub _init {
	my ($self, $screen, $config, $state) = @_;
	$self->{_state}      = $state;
	$self->{_prompt}     = '';
	$self->SUPER::_init($screen, $config);
	return;
}

=item _list_items()

List the Your commands from the App::PFM::Config object.

=cut

sub _list_items {
	my ($self)     = @_;
	my $screen     = $self->{_screen};
	my $printline  = $screen->BASELINE;
	my $infocol    = $screen->diskinfo->infocol;
	my $infolength = $screen->diskinfo->infolength;
	my $spacing    = ' ' x $infolength;
	my $browselist = $self->browselist;
	my ($commandkey, $printstr);
	# headings
	$screen
		->set_deferred_refresh(R_DISKINFO | R_FRAME)
		->show_frame({
			headings => HEADING_YCOMMAND,
			footer   => FOOTER_NONE,
			prompt   => $self->{_prompt},
		});
	# list bookmarks
	foreach (
		$self->{_baseindex} .. $self->{_baseindex} + $screen->screenheight
	) {
		last if ($printline > $screen->BASELINE + $screen->screenheight);
		$commandkey = $browselist->[$_];
		$printstr = $self->{_config}->your($commandkey);
		$printstr =~ s/\e/^[/g; # in case real escapes are used
		$screen->at($printline++, $infocol)
			->puts(sprintf('%1s %s',
					$commandkey,
					substr($printstr . $spacing, 0, $infolength - 2)));
	}
	foreach ($printline .. $screen->BASELINE + $screen->screenheight) {
		$screen->at($printline++, $infocol)->puts($spacing);
	}
	$screen->at($self->{_currentline} + $screen->BASELINE, $infocol);
	return;
}

=item _wait_loop()

Waits for keyboard input. In unused time, flash the cursor.

=cut

sub _wait_loop {
	my ($self) = @_;
	my $screen         = $self->{_screen};
	my $screenline     = $self->{_currentline} + $screen->BASELINE;
	my $cursorcol      = $self->cursorcol;
	my $cursorjumptime = $self->{_config}{cursorjumptime};
	my $event_idle     = App::PFM::Event->new({
		name   => 'browser_idle',
		origin => $self,
		type   => 'soft',
	});

	$screen->at($screenline, $cursorcol);
	until ($screen->pending_input($cursorjumptime)) {
		$self->fire($event_idle);
		# note: fire() called in vain. nobody has had the chance to register.
		$screen->at(0, length($self->{_prompt})); # jump cursor
		return if $screen->pending_input($cursorjumptime);
		if ($self->SHOW_CLOCK) {
			$screen->diskinfo->clock_info();
		}
		$screen->at($screenline, $cursorcol); # jump cursor
	}
	return;
}

##########################################################################
# constructor, getters and setters

=item browselist()

Getter for the key listing (A, a, B, b, ... Z, z) that is to be shown.

=cut

sub browselist {
	my ($self) = @_;
	return [
		sort { alphabetically($a, $b) } $self->{_config}->your_commands
	];
}

=item cursorcol()

Getter for the cursor column to be used in this browser.

=cut

sub cursorcol {
	my ($self) = @_;
	return $self->{_screen}->diskinfo->infocol;
}

=item currentitem()

Getter for the Your command at the cursor position.

=cut

sub currentitem {
	my ($self) = @_;
	my $index  = $self->{_currentline} + $self->{_baseindex};
	my $key    = $self->browselist->[$index];
	return $self->{_config}->your_commands->{$key};
}

##########################################################################
# public subs

=item handle_non_motion_input(App::PFM::Event $event)

Attempts to handle the non-motion event (keyboard- or mouse-input).
Returns a hash reference with a member 'handled' indicating if this
was successful, and a member 'data' with additional data (like
the string 'quit' in case the user requested an application quit).

=cut

sub handle_non_motion_input {
	my ($self, $event) = @_;
	my $screenheight = $self->{_screen}->screenheight;
	my $BASELINE     = $self->{_screen}->BASELINE;
	my $browselist   = $self->browselist;
	my $res          = {};
	if ($event->{type} eq 'mouse') {
		if ($event->{mouserow} >= $BASELINE and
			$event->{mouserow} <= $BASELINE + $screenheight)
		{
			# potentially on an item, regardless of column
			$res->{data} = $browselist->[
				$self->{_baseindex} + $event->{mouserow} - $BASELINE
			];
		}
	} elsif ($event->{data} eq "\r") {
		# ENTER key
		$res->{data} = $browselist->[
			$self->{_currentline} + $self->{_baseindex}
		];
	} else {
		# other key events
		$res->{data} = $event->{data};
	}
	return $res;
}

=item choose(string $prompt)

Allows the user to browse through the listing of Your commands and
make their choice.

=cut

sub choose {
	my ($self, $prompt) = @_;
	my ($choice, $event);
	my $screen       = $self->{_screen};
	my $listing      = $screen->listing;
	$self->{_prompt} = $prompt;
	do {
		$self->_list_items();
#TODO		$listing->highlight_on();
		# don't send mouse escapes to the terminal if not necessary
		$screen->bracketed_paste_on() if $self->{_config}{paste_protection};
		$screen->mouse_enable()       if $self->{_mouse_mode};
		# enter main wait loop, which is exited on a resize event
		# or on keyboard/mouse input.
		$self->_wait_loop();
		# find out what happened
		$event = $screen->get_event();
		# was it a resize?
		if ($event->{name} eq 'resize_window') {
			$screen->handleresize();
		} else {
			# must be keyboard/mouse input here
#TODO			$listing->highlight_off();
			$screen->bracketed_paste_off();
			$screen->mouse_disable();
			$choice = $self->handle($event);
			if ($choice->{handled}) {
				# if the received input was valid, then the current
				# cursor position must be validated again
				$screen->set_deferred_refresh($screen->R_STRIDE); # TODO
			}
		}
	} until defined $choice->{data};
	$self->{_screen}->bracketed_paste_off();
	return $choice->{data};
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Browser(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
