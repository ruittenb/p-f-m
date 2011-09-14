#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::Chooser 0.10
#
# Name:			App::PFM::Browser::Chooser
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		2011-03-11
# Date:			2011-03-20
#

##########################################################################

=pod

=head1 NAME

App::PFM::Browser::Chooser

=head1 DESCRIPTION

This class is derived from App::PFM::Browser to incorporate browsing
functionality. It adds functionality for displaying a list of items and
selecting one.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Browser::Chooser;

use base qw(App::PFM::Browser App::PFM::Abstract);

#use App::PFM::Screen::Frame qw(:constants); # MENU_*, HEADING_*, and FOOTER_*
use App::PFM::Screen        qw(:constants); # R_*

use strict;
use locale;

##########################################################################
# private subs

=item _init(App::PFM::Screen $screen, App::PFM::Config $config)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $screen, $config) = @_;
	$self->{_prompt}     = '';
	$self->{_browselist} = undef;
	$self->{_template}   = undef;
	$self->SUPER::_init($screen, $config);
	return;
}

=item _wait_loop()

Waits for keyboard input. In unused time, flash the cursor and 
update the on-screen clock, if necessary.

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

	if ($self->SHOW_MARKCURRENT) {
		$screen->listing->markcurrentline($self->SHOW_MARKCURRENT);
	}
	$screen->at($screenline, $cursorcol);
	until ($screen->pending_input($cursorjumptime)) {
		$self->fire($event_idle);
		$screen->at(0, length($self->{_prompt})); # jump cursor
		return if $screen->pending_input($cursorjumptime);
		if ($self->SHOW_CLOCK) {
			$screen->diskinfo->clock_info();
		}
		$screen->at($screenline, $cursorcol); # jump cursor
	}
	return;
}

=item _highlight(boolean $value)

Highlights the current item, if I<value> is true. Otherwise, removes
highlight.

=cut

sub _highlight {
	my ($self, $value) = @_;
	$self->show_item($self->{_currentline}, $value);
	return;
}

##########################################################################
# constructor, getters and setters

=item prompt(string $prompt)

Getter/setter for the prompt that is to be displayed.

=cut

sub prompt {
	my ($self, $value) = @_;
	if (defined($value)) {
		$self->{_prompt} = $value;
	}
	return $self->{_prompt};
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
			$event->{mouserow} <= $BASELINE + $screenheight and
			$event->{mousecol} >= $self->{_itemcol} and
			$event->{mousecol} <  $self->{_itemcol} + $self->{_itemlen}
		) {
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

Allows the user to browse through the list of items and
select one item.

=cut

sub choose {
	my ($self, $prompt) = @_;
	my ($choice, $event);
	my $screen       = $self->{_screen};
	$self->{_prompt} = $prompt;
	$screen->set_deferred_refresh(R_SCREEN);
	do {
		$screen->refresh();
		$self->_highlight(1);
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
			$self->_highlight(0);
			$screen->bracketed_paste_off();
			$screen->mouse_disable();
			$choice = $self->handle($event);
			if ($choice->{handled}) {
				# if the received input was valid, then the current
				# cursor position must be validated again
				$screen->set_deferred_refresh(R_STRIDE);
			}
		}
	} until defined $choice->{data};
	$screen->set_deferred_refresh(R_SCREEN)->bracketed_paste_off();
	return $choice->{data};
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Browser(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
