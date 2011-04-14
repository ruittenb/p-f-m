#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser 0.36
#
# Name:			App::PFM::Browser
# Version:		0.36
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-13
#

##########################################################################

=pod

=head1 NAME

App::PFM::Browser

=head1 DESCRIPTION

This class is responsible for executing the main browsing loop of pfm,
which loops over: waiting for a keypress, dispatching the command to
the command handler, and refreshing the screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Browser;

use base 'App::PFM::Abstract';

use strict;

our $FIONREAD = 0;
#eval {
#	# suppresses the warnings by changing line 3 in
#	# /usr/lib/perl/5.8.8/features.ph from
#	# no warnings 'redefine';
#	# to
#	# no warnings qw(redefine misc);
#	require 'sys/ioctl.ph';
#	$FIONREAD = FIONREAD();
#};

my ($_pfm, $_screen,
	$_currentline, $_baseindex, $_position_at);

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
	$self->{_mouse_mode} = undef;
	$self->{_swap_mode}  = 0;
}

=item _wait_loop()

Waits for keyboard input. In unused time, poll jobs and update
the on-screen clock.

=cut

sub _wait_loop {
#	my ($self) = @_;
	my $screenline = $_currentline + $_screen->BASELINE;
	my $cursorcol  = $_screen->listing->cursorcol;
	until ($_screen->pending_input(0.4)) {
		$_pfm->jobhandler->pollall();
		return if $_screen->pending_input(0.6);
		$_screen->diskinfo->clock_info()
			->at($screenline, $cursorcol);
	}
}

=item _burst_size()

Checks how many characters are waiting for input. This could be used
to filter out unwanted paste actions when commands are expected.

=cut

sub _burst_size {
#	my ($self) = @_;
	return 0 unless $FIONREAD;
	my $size = pack("L", 0);
	ioctl(STDIN, $FIONREAD, $size);
	return unpack("L", $size);
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
		$self->validate_position(1);
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
	$self->validate_position(1);
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
		if ($self->{_mouse_mode} = $value) {
			$_screen->mouse_enable();
		} else {
			$_screen->mouse_disable();
		}
		$_screen->set_deferred_refresh($_screen->R_FOOTER);
	}
	return $self->{_mouse_mode};
}

=item swap_mode()

Getter/setter for the swap_mode variable, which indicates if the browser
considers its current directory as 'swap' directory.

=cut

sub swap_mode {
	my ($self, $value) = @_;
	if (defined($value)) {
		$self->{_swap_mode} = $value;
		$_screen->set_deferred_refresh($_screen->R_FRAME);
	}
	return $self->{_swap_mode};
}

##########################################################################
# public subs

=item validate_position()

Checks if the current cursor position and the current file lie within
the screen window. If not, the screen window is repositioned so that the
cursor is on-screen.

=cut

sub validate_position {
	my ($self, $force_list) = @_;
	# requirement: $showncontents[$_currentline+$_baseindex] is defined
	my $screen        = $_pfm->screen;
	my $screenheight  = $screen->screenheight;
	my $oldbaseindex  = $_baseindex;
	my @showncontents = @{$_pfm->state->directory->showncontents};
	
	if ($_currentline < 0) {
		$_baseindex  += $_currentline;
		$_baseindex   < 0 and $_baseindex = 0;
		$_currentline = 0;
#		$screen->set_deferred_refresh($screen->R_DIRLIST);
	}
	if ($_currentline > $screenheight) {
		$_baseindex  += $_currentline - $screenheight;
		$_currentline = $screenheight;
#		$screen->set_deferred_refresh($screen->R_DIRLIST);
	}
	if ($_currentline + $_baseindex > $#showncontents) {
		$_currentline = $#showncontents - $_baseindex;
#		$screen->set_deferred_refresh($screen->R_DIRLIST);
	}
	# See if we need to refresh the listing.
	# By limiting the number of listing-refreshes to when the baseindex
	# is/might have been changed, browsing becomes snappier.
	if ($force_list or $oldbaseindex != $_baseindex) {
		$screen->set_deferred_refresh($screen->R_DIRLIST);
	}
}

=item position_cursor()

Positions the cursor at a specific file.

=cut

sub position_cursor {
	my ($self, $target) = @_;
	$_position_at = $target if (defined $target and $target ne '');
	return if $_position_at eq '';
	my @showncontents = @{$_pfm->state->directory->showncontents};
	$_currentline     = 0;
	$_baseindex       = 0 if $_position_at eq '..'; # descending into this dir
	POSITION_ENTRY: {
		for (0..$#showncontents) {
			if ($_position_at eq $showncontents[$_]{name}) {
				$_currentline = $_ - $_baseindex;
				last POSITION_ENTRY;
			}
		}
		$_baseindex = 0;
	}
	$_position_at = '';
	$self->validate_position(1);
}

=item position_cursor_fuzzy()

Positions the cursor at the file with the closest matching name.
Used by incremental find.

=cut

sub position_cursor_fuzzy {
	my ($self, $target) = @_;
	$_position_at = $target if (defined $target and $target ne '');
	return if $_position_at eq '';

	my @showncontents = @{$_pfm->state->directory->showncontents};
	my ($criterion, $i);

	if ($_pfm->state->{sort_mode} eq 'n') {
		$criterion = sub {
			return ($_position_at le substr($_[0], 0, length($_position_at)));
		};
	} elsif ($_pfm->state->{sort_mode} eq 'N') {
		$criterion = sub {
			return ($_position_at ge substr($_[0], 0, length($_position_at)));
		};
	} else {
		goto &position_cursor;
	}

	$_currentline = 0;
	if ($#showncontents > 1) {
		POSITION_ENTRY_FUZZY: {
			for $i (1..$#showncontents) {
				if ($criterion->($showncontents[$i]{name})) {
					$_currentline =
						$self->find_best_find_match(
							$_position_at,
							$showncontents[$i-1]{name},
							$showncontents[$i  ]{name}
						)
						+ $i - 1 - $_baseindex;
					last POSITION_ENTRY_FUZZY;
				}
			}
			$_currentline = $#showncontents - $_baseindex;
		}
	}
	$_position_at = '';
	$self->validate_position(1);
}

=item find_best_find_match()

Decides which file out of two is the best match, I<e.g.> if there are
two files C<Contractor.php> and C<Dealer.php>, and 'Coz' is given,
this method decides that C<Contractor.php> is the better match.

=cut

sub find_best_find_match {
	my ($self, $seek, $first, $second) = @_;
	my $char;
	for ($char = length($seek); $char > 0; $char--) {
		if (substr($first,  0, $char) eq substr($seek, 0, $char)) {
			return 0;
		}
		if (substr($second, 0, $char) eq substr($seek, 0, $char)) {
			return 1;
		}
	}
	return 1;
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
	my ($self) = @_;
	my ($event, $valid_input);
	# prefetch objects
	my $commandhandler = $_pfm->commandhandler;
	my $listing        = $_screen->listing;
	until ($valid_input eq 'quit') {
		$_screen->refresh();
		$listing->highlight_on();
		# don't send mouse escapes to the terminal if not necessary
		$_screen->mouse_enable()
			if $self->{_mouse_mode} && $_pfm->config->{mouseturnoff};
		# enter main wait loop
		$self->_wait_loop();
		# the main wait loop is exited on a resize event or
		# on keyboard/mouse input
		if ($_screen->wasresized) {
			$_screen->handleresize();
		} else {
			# the next block is highly experimental - maybe this
			# could be used to suppress paste actions in command mode
			if ($self->_burst_size > 30) {		  # experimental
				$_screen->flush_input()->flash(); # experimental
				redo;							  # experimental
			}								      # experimental
			# must be keyboard/mouse input here
			$event = $_screen->getch();
			$listing->highlight_off();
			$_screen->mouse_disable() if $_pfm->config->{mouseturnoff};
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
