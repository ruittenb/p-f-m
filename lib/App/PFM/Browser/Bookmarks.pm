#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::Bookmarks 0.04
#
# Name:			App::PFM::Browser::Bookmarks
# Version:		0.04
# Author:		Rene Uittenbogaard
# Created:		2010-12-01
# Date:			2010-12-05
#

##########################################################################

=pod

=head1 NAME

App::PFM::Browser::Bookmarks

=head1 DESCRIPTION

This class is responsible for the bookmark-specific part of browsing
through bookmarks and selecting one.
It provides the Browser class with the necessary file data.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Browser::Bookmarks;

use base qw(App::PFM::Browser App::PFM::Abstract);

use App::PFM::Screen::Frame qw(:constants); # MENU_*, HEADING_*, and FOOTER_*
use App::PFM::Screen        qw(:constants); # R_*
use App::PFM::Util			qw(fitpath);

use strict;
use locale;

use constant SPAWNEDCHAR => '*';

use constant MOTION_COMMANDS_EXCEPT_SPACE =>
	qr/^(?:[-+\cF\cB\cD\cU]|ku|kd|pgup|pgdn|home|end)$/io; # no 'j', 'k'

##########################################################################
# private subs

=item _init(App::PFM::Screen $screen, App::PFM::Config $config,
hashref $states)

Initializes new instances. Called from the constructor.
Stores the application's array of states internally.

=cut

sub _init {
	my ($self, $screen, $config, $states) = @_;
	$self->{_states} = $states;
	$self->{_prompt} = '';
	$self->SUPER::_init($screen, $config);
	return;
}

=item _listbookmarks()

List the bookmarks from the hash of states.

=cut

sub _listbookmarks {
	my ($self)          = @_;
	my $screen          = $self->{_screen};
	my $printline       = $screen->BASELINE;
	my $bookmarkpathcol = $screen->listing->bookmarkpathcol;
	my @heading         = $screen->frame->bookmark_headings;
	my $bookmarkpathlen = $heading[2];
	my $spacing         =
		' ' x ($screen->screenwidth - $screen->diskinfo->infolength);
	my ($dest, $spawned, $overflow, $bookmarkkey);
	# headings
	$screen
		->set_deferred_refresh(R_SCREEN)
		->show_frame({
			headings => HEADING_BOOKMARKS,
			footer   => FOOTER_NONE,
			prompt   => $self->{_prompt},
		});
	# list bookmarks
	foreach (
		$self->{_baseindex} .. $self->{_baseindex} + $screen->screenheight
	) {
		last if ($printline > $screen->BASELINE + $screen->screenheight);
		$bookmarkkey = ${$self->{_config}->BOOKMARKKEYS}[$_];
		$dest        = ${$self->{_states}}{$bookmarkkey};
		$spawned     = ' ';
		if (ref $dest) {
			$dest    = $dest->directory->path . '/' . $dest->{_position};
			$dest    =~ s{/\.$}{/};
			$dest    =~ s{^//}{/};
			$spawned = SPAWNEDCHAR;
		}
		if (length($dest)) {
			($dest, undef, $overflow) = fitpath($dest, $bookmarkpathlen);
			$dest .= ($overflow ? $screen->listing->NAMETOOLONGCHAR : ' ');
		}
		$screen->at($printline++, $bookmarkpathcol)
			->puts(sprintf($heading[0], $bookmarkkey, $spawned, $dest));
	}
	foreach ($printline .. $screen->BASELINE + $screen->screenheight) {
		$screen->at($printline++, $bookmarkpathcol)->puts($spacing);
	}
	$screen->at($self->{_currentline} + $screen->BASELINE, $bookmarkpathcol);
	return;
}

=item _wait_loop()

Waits for keyboard input. In unused time, update the on-screen clock
and flash the cursor.

=cut

sub _wait_loop {
	my ($self) = @_;
	my $screen     = $self->{_screen};
	my $screenline = $self->{_currentline} + $screen->BASELINE;
	my $cursorcol  = $screen->listing->bookmarkpathcol;
	my $cursorjumptime = $self->{_config}{cursorjumptime};
	my $event_idle = App::PFM::Event->new({
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
		$screen->diskinfo->clock_info()
			->at($screenline, $cursorcol); # jump cursor
	}
	return;
}

##########################################################################
# constructor, getters and setters

=item browselist()

Getter for the key listing (a..z, A..Z) that is to be shown.

=cut

sub browselist {
	my ($self) = @_;
	return $self->{_config}->BOOKMARKKEYS;
}

=item currentbookmark()

Getter for the bookmark at the cursor position.

=cut

sub currentbookmark {
	my ($self)   = @_;
	my $index    = $self->{_currentline} + $self->{_baseindex};
	my $key      = ${$self->{_config}->BOOKMARKKEYS}[$index];
	my $bookmark = ${$self->{_states}}{$key};
	return $bookmark;
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
	my $res          = {};
	if ($event->{type} eq 'mouse') {
		if ($event->{mouserow} >= $BASELINE and
			$event->{mouserow} <= $BASELINE + $screenheight)
		{
			# potentially on a fileline (might be diskinfo column though)
			$res->{data} = ${$self->{_config}->BOOKMARKKEYS}[
				$self->{_baseindex} + $event->{mouserow} - $BASELINE
			];
		}
	} elsif ($event->{data} eq "\r") {
		# ENTER key
		$res->{data} = ${$self->{_config}->BOOKMARKKEYS}[
			$self->{_currentline} + $self->{_baseindex}
		];
	} else {
		# other key events
		$res->{data} = $event->{data};
	}
	return $res;
}

=item choose(string $prompt)

Allows the user to browse through the listing of bookmarks and
make their choice.

=cut

sub choose {
	my ($self, $prompt) = @_;
	my ($choice, $event);
	my $screen       = $self->{_screen};
	my $listing      = $screen->listing;
	$self->{_prompt} = $prompt;
	do {
		$self->_listbookmarks();
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
