#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Browser 0.01
#
# Name:			PFM::Browser.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
#

##########################################################################

=pod

=head1 NAME

PFM::Browser

=head1 DESCRIPTION

This class is responsible for executing the main browsing loop of pfm,
which loops over: waiting for a keypress, dispatching the command to
the CommandHandler, and refreshing the screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Browser;

use base 'PFM::Abstract';

use strict;

my ($_pfm, $_screen,
	$_currentline, $_baseindex, $_position_at);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm			 = $pfm;
	$_screen		 = $pfm->screen;
	$_currentline	 = 0;
	$_baseindex		 = 0;
	$_position_at    = '.';
}

=item _wait_loop()

Waits for keyboard input. In unused time, poll jobs and update
the on-screen clock.

=cut

sub _wait_loop {
	my $self = shift;
	until ($_screen->pending_input(1)) {
		$_screen->diskinfo->clock_info();
		$_pfm->job->pollall();
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

##########################################################################
# public subs

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
	my ($event, $quit);
	until ($quit) {
		$_screen->refresh();
		# normally, the current cursor position must be validated every pass
		$_screen->set_deferred_refresh($_screen->R_STRIDE);
		$_screen->listing->highlight_on();
		# don't send mouse escapes to the terminal if not necessary
		if ($_pfm->state->{mouse_mode} && $_pfm->config->{mouseturnoff}) {
			$_screen->mouse_enable();
		}
		# enter main wait loop
		$event = $self->_wait_loop();
		if ($_screen->wasresized) {
			$_screen->handleresize();
		} else {
			# TODO fetch keypress etc

			$quit = $_pfm->commandhandler->handle($event);
		}
	}
}

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
	my @showncontents = @{$_pfm->directory->showncontents};
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
	$self->validate_position(); # refresh flag
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4: