#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Browser 0.36
#
# Name:			PFM::Browser.pm
# Version:		0.36
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-13
#

##########################################################################

=pod

=head1 NAME

PFM::Browser

=head1 DESCRIPTION

This class is responsible for executing the main browsing loop of pfm,
which loops over: waiting for a keypress, dispatching the command to
the command handler, and refreshing the screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Browser;

use base 'PFM::Abstract';

use strict;

my ($_pfm, $_screen,
	$_currentline, $_baseindex, $_position_at, $_mouse_mode, $_swap_mode);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm		  = $pfm;
	$_screen	  = $pfm->screen;
	$_currentline = 0;
	$_baseindex	  = 0;
	$_position_at = '';
	$_mouse_mode  = undef;
	$_swap_mode   = 0;
}

=item _wait_loop()

Waits for keyboard input. In unused time, poll jobs and update
the on-screen clock.

=cut

sub _wait_loop {
	my $self = shift;
	until ($_screen->pending_input(1)) {
		$_screen->diskinfo->clock_info();
		$_pfm->jobhandler->pollall();
		$_screen->at(
			$_currentline + $_screen->BASELINE, $_screen->listing->cursorcol);
	}
}

##########################################################################
# constructor, getters and setters

=item currentfile()

Getter for the file at the cursor position.

=cut

sub currentfile {
	my ($self) = @_;
	return $_pfm->state->directory->showncontents
		->[$_currentline + $_baseindex];
}

=item currentline()

Getter/setter for the current line number of the cursor.

=cut

sub currentline {
	my ($self, $value) = @_;
	if (defined $value) {
		$_currentline = $value;
		$self->validate_position();
	}
	return $_currentline;
}

=item baseindex()

Getter/setter for the start of the screen window in the current directory.

=cut

sub baseindex {
	my ($self, $value) = @_;
	if (defined $value) {
		$_baseindex = $value;
		$self->validate_position();
	}
	return $_baseindex;
}

=item setview()

Setter for both the cursor line and screen window at once.

=cut

sub setview {
	my ($self, $line, $index) = @_;
	return 0 unless (defined($line) && defined($index));
	$_currentline = $line;
	$_baseindex   = $index;
	$self->validate_position();
	$_screen->set_deferred_refresh($_screen->R_DIRLIST);
}

=item position_at()

Getter/setter for the position_at variable, which controls to which file
the cursor should go as soon as the main browse loop is resumed.

=cut

sub position_at {
	my ($self, $value, $force) = @_;
	if (defined($value) and ($force or $_position_at eq '')) {
		$_position_at = $value;
	}
	return $_position_at;
}

=item mouse_mode()

Getter/setter for the mouse_mode variable, which indicates if mouse clicks
are to be intercepted by the application.

=cut

sub mouse_mode {
	my ($self, $value) = @_;
	if (defined($value)) {
		$_mouse_mode = $value;
		$_screen->set_deferred_refresh($_screen->R_FOOTER);
	}
	return $_mouse_mode;
}

=item swap_mode()

Getter/setter for the swap_mode variable, which indicates if the browser
considers its current directory as 'swap' directory.

=cut

sub swap_mode {
	my ($self, $value) = @_;
	if (defined($value)) {
		$_swap_mode = $value;
		$_screen->set_deferred_refresh($_screen->R_FRAME);
	}
	return $_swap_mode;
}

##########################################################################
# public subs

=item validate_position()

Checks if the current cursor position and the current file lie within
the screen window. If not, the screen window is repositioned so that the
cursor is on-screen.

=cut

sub validate_position {
	my $self = shift;
	# requirement: $showncontents[$_currentline+$_baseindex] is defined
	my $screen        = $_pfm->screen;
	my $screenheight  = $screen->screenheight;
	my @showncontents = @{$_pfm->state->directory->showncontents};
	
	if ($_currentline < 0) {
		$_baseindex  += $_currentline;
		$_baseindex   < 0 and $_baseindex = 0;
		$_currentline = 0;
		$screen->set_deferred_refresh($screen->R_DIRLIST);
	}
	if ($_currentline > $screenheight) {
		$_baseindex  += $_currentline - $screenheight;
		$_currentline = $screenheight;
		$screen->set_deferred_refresh($screen->R_DIRLIST);
	}
	if ($_currentline + $_baseindex > $#showncontents) {
		$_currentline = $#showncontents - $_baseindex;
		$screen->set_deferred_refresh($screen->R_DIRLIST);
	}
}

=item position_cursor()

Position the cursor at a specific file.

=cut

sub position_cursor {
	my ($self, $target) = @_;
	$_position_at = $target if (defined $target and $target ne '');
	return if $_position_at eq '';
	my @showncontents = @{$_pfm->state->directory->showncontents};
	$_currentline     = 0;
	$_baseindex       = 0 if $_position_at eq '..'; # descending into this dir
	ANYENTRY: {
		for (0..$#showncontents) {
			if ($_position_at eq $showncontents[$_]{name}) {
				$_currentline = $_ - $_baseindex;
				last ANYENTRY;
			}
		}
		$_baseindex = 0;
	}
	$_position_at = '';
	$self->validate_position();
}

=item browse()

This sub, the main browse loop, is the heart of pfm. It has the
following structure:

  do {
    refresh everything flagged for refreshing;
    wait for keypress-, mousedown- or resize-event;
    handle the request;
  } until quit was requested.

=cut

sub browse {
	my $self = shift;
	my ($event, $valid_input);
	# optimize by fetching used objects
	my $commandhandler = $_pfm->commandhandler;
	my $listing        = $_screen->listing;
	my $mouseturnoff   = $_pfm->config->{mouseturnoff};
	until ($valid_input eq 'quit') {
		$_screen->refresh();
		$listing->highlight_on();
		# don't send mouse escapes to the terminal if not necessary
		$_screen->mouse_enable() if ($_mouse_mode && $mouseturnoff);
		# enter main wait loop
		$event = $self->_wait_loop();
		# the main wait loop is exited on a resize event or
		# on keyboard/mouse input
		if ($_screen->wasresized) {
			$_screen->handleresize();
		} else {
			# must be keyboard/mouse input here
			$event = $_screen->getch();
			$listing->highlight_off();
			$_screen->mouse_disable() if $mouseturnoff;
			# the next line contains an assignment on purpose
			if ($valid_input = $commandhandler->handle($event)) {
				# if the received input was valid, then the current
				# cursor position must be validated again
				$_screen->set_deferred_refresh($_screen->R_STRIDE);
			}
		}
	}
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
