#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser 0.54
#
# Name:			App::PFM::Browser
# Version:		0.54
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-11-17
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

use App::PFM::Util qw(min max);
use App::PFM::Screen qw(:constants);

use strict;
use locale;

use constant MOTION_COMMANDS_EXCEPT_SPACE =>
	qr/^(?:[-+jk\cF\cB\cD\cU]|ku|kd|pgup|pgdn|home|end)$/io;

##########################################################################
# private subs

=item _init(App::PFM::Screen $screen, App::PFM::Config $config,
App::PFM::State $state)

Initializes new instances. Called from the constructor.
Expects to be passed the application object as the first parameter.

=cut

sub _init {
	my ($self, $screen, $config, $state) = @_;
	$self->{_screen}		 = $screen;
	$self->{_config}		 = $config;
	$self->{_state}			 = $state;
	$self->{_currentline}	 = 0;
	$self->{_baseindex}		 = 0;
	$self->{_position_at}	 = '';
	$self->{_position_exact} = 0;
	$self->{_mouse_mode}	 = undef;
	$self->{_swap_mode}		 = 0;

	my $on_after_resize_window = sub {
#		my ($event) = @_;
		$self->validate_position();
	};
	$screen->register_listener('after_resize_window', $on_after_resize_window);
}

=item _wait_loop()

Waits for keyboard input. In unused time, poll jobs and update
the on-screen clock.

=cut

sub _wait_loop {
	my ($self) = @_;
	my $screen     = $self->{_screen};
	my $screenline = $self->{_currentline} + $screen->BASELINE;
	my $cursorcol  = $screen->listing->cursorcol;
	my $event_idle = new App::PFM::Event({
		name   => 'browser_idle',
		origin => $self,
		type   => 'soft',
	});
	until ($screen->pending_input(0.4)) {
		$self->fire($event_idle);
		$screen->refresh_headings()
			->at($screenline, $cursorcol);
		return if $screen->pending_input(0.6);
		$screen->diskinfo->clock_info()
			->at($screenline, $cursorcol);
	}
}

##########################################################################
# constructor, getters and setters

=item currentfile()

Getter for the file at the cursor position.

=cut

sub currentfile {
	my ($self) = @_;
	return $self->{_state}->directory->showncontents
		->[$self->{_currentline} + $self->{_baseindex}];
}

=item currentline( [ int $lineno ] )

Getter/setter for the current line number of the cursor.

=cut

sub currentline {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_currentline} = $value;
		$self->validate_position();
	}
	return $self->{_currentline};
}

=item baseindex( [ int $index ] )

Getter/setter for the start of the screen window in the current directory.

=cut

sub baseindex {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_baseindex} = $value;
		$self->validate_position();
		$self->{_screen}->set_deferred_refresh($self->{_screen}->R_LISTING);
	}
	return $self->{_baseindex};
}

=item setview(int $lineno, int $index)

Getter/setter for both the cursor line and screen window at once.

=cut

sub setview {
	my ($self, $line, $index) = @_;
	return 0 unless (defined($line) && defined($index));
	$self->{_currentline} = $line;
	$self->{_baseindex}   = $index;
	$self->validate_position();
	$self->{_screen}->set_deferred_refresh($self->{_screen}->R_LISTING);
	return ($self->{_currentline}, $self->{_baseindex});
}

=item position_at(string $filename [, hashref { force => bool $force,
exact => bool $exact } ] )

Getter/setter for the I<position_at> variable, which controls to which
file the cursor should go as soon as the main browse loop is resumed.

If the I<force> option is false, the old value of I<position_at>
will only be replaced if it was undefined.
If true, any old value of I<position_at> will be overwritten.

The I<exact> option indicates that exact placement should be used
instead of fuzzy placement.

=cut

sub position_at {
	my ($self, $value, $options) = @_;
	$options ||= {};
	if (defined($value) and
		($options->{force} or $self->{_position_at} eq ''))
	{
		$self->{_position_at}    = $value;
		$self->{_position_exact} = $options->{exact};
	}
	return wantarray
		? ($self->{_position_at}, $self->{_position_exact})
		: $self->{_position_at};
}

=item mouse_mode( [ bool $mouse_mode ] )

Getter/setter for the mouse_mode variable, which indicates if mouse clicks
are to be intercepted by the application.

=cut

sub mouse_mode {
	my ($self, $value) = @_;
	my $screen = $self->{_screen};
	if (defined($value)) {
		# next line is an assignment on purpose
		if ($self->{_mouse_mode} = $value) {
			$screen->mouse_enable();
		} else {
			$screen->mouse_disable();
		}
		$screen->set_deferred_refresh($screen->R_FOOTER);
	}
	return $self->{_mouse_mode};
}

=item swap_mode( [ bool $swap_mode ] )

Getter/setter for the swap_mode variable, which indicates if the browser
considers its current directory as 'swap' directory.

=cut

sub swap_mode {
	my ($self, $value) = @_;
	my $screen = $self->{_screen};
	if (defined($value)) {
		$self->{_swap_mode} = $value;
		$screen->set_deferred_refresh($screen->R_FRAME);
	}
	return $self->{_swap_mode};
}

=item main_state( [ App::PFM::State $state ] )

Getter/setter for the I<_state> member variable, indicating which state
this browser is operating on.

=cut

sub main_state {
	my ($self, $value) = @_;
	if (defined($value)) {
		$self->{_state} = $value;
	}
	return $self->{_state};
}

##########################################################################
# public subs

=item validate_position()

Checks if the current cursor position and the current file lie within
the screen window. If not, the screen window is repositioned so that the
cursor is on-screen.

=cut

sub validate_position {
	my ($self) = @_;
	# requirement:
	# $showncontents[ $self->{_currentline} + $self->{_baseindex} ] is defined
	my $screenheight  = $self->{_screen}->screenheight;
	my $oldbaseindex  = $self->{_baseindex};
	my @showncontents = @{$self->{_state}->directory->showncontents};
	
	if ($self->{_currentline} < 0) {
		$self->{_baseindex}  += $self->{_currentline};
		$self->{_baseindex}   < 0 and $self->{_baseindex} = 0;
		$self->{_currentline} = 0;
	}
	if ($self->{_currentline} > $screenheight) {
		$self->{_baseindex}  += $self->{_currentline} - $screenheight;
		$self->{_currentline} = $screenheight;
	}
	if ($self->{_baseindex} > $#showncontents) {
		$self->{_currentline} += $self->{_baseindex} - $#showncontents;
		$self->{_baseindex}    = $#showncontents;
	}
	if ($self->{_currentline} + $self->{_baseindex} > $#showncontents) {
		$self->{_currentline} = $#showncontents - $self->{_baseindex};
	}
	# See if we need to refresh the listing.
	# By limiting the number of listing-refreshes to when the baseindex
	# is/might have been changed, browsing becomes snappier.
	if ($oldbaseindex != $self->{_baseindex}) {
		$self->{_screen}->set_deferred_refresh($self->{_screen}->R_LISTING);
	}
}

=item position_cursor( [ string $filename ] )

Positions the cursor at a specific file. Specifying a filename here
overrules the I<position_at> variable.

=cut

sub position_cursor {
	my ($self, $target) = @_;
	$self->{_position_at} = $target if (defined $target and $target ne '');
	return if $self->{_position_at} eq '';
	my @showncontents     = @{$self->{_state}->directory->showncontents};
	$self->{_currentline} = 0;
	$self->{_baseindex}   = 0 if $self->{_position_at} eq '..'; # descending
	POSITION_ENTRY: {
		for (0..$#showncontents) {
			if ($self->{_position_at} eq $showncontents[$_]{name}) {
				$self->{_currentline} = $_ - $self->{_baseindex};
				last POSITION_ENTRY;
			}
		}
		$self->{_baseindex} = 0;
	}
	$self->{_position_at}    = '';
	$self->{_position_exact} = 0;
	$self->validate_position();
	$self->{_screen}->set_deferred_refresh($self->{_screen}->R_LISTING);
}

=item position_cursor_fuzzy( [ string $filename ] )

Positions the cursor at the file with the closest matching name.
Used by incremental find.

=cut

sub position_cursor_fuzzy {
	my ($self, $target) = @_;
	$self->{_position_at} = $target if (defined $target and $target ne '');
	return if $self->{_position_at} eq '';

	my @showncontents = @{$self->{_state}->directory->showncontents};
	my ($criterion, $i);

	# don't position fuzzy if sort mode is not by name,
	# or exact positioning was requested
	if ($self->{_position_exact} or $self->{_state}->sort_mode !~ /^[nm]$/io) {
		goto &position_cursor;
	}

	for ($self->{_state}->sort_mode) {
		$_ eq 'n' and do {
			$criterion = sub {
				return ($self->{_position_at} le
						substr($_[0], 0, length($self->{_position_at}))
				);
			};
		};
		$_ eq 'N' and do {
			$criterion = sub {
				return ($self->{_position_at} ge
						substr($_[0], 0, length($self->{_position_at}))
				);
			};
		};
		$_ eq 'm' and do {
			$criterion = sub {
				return (uc($self->{_position_at}) le
						substr(uc($_[0]), 0, length($self->{_position_at}))
				);
			};
		};
		$_ eq 'M' and do {
			$criterion = sub {
				return (uc($self->{_position_at}) ge
						substr(uc($_[0]), 0, length($self->{_position_at}))
				);
			};
		};
	}

	$self->{_currentline} = 0;
	if ($#showncontents > 1) {
		POSITION_ENTRY_FUZZY: {
			for $i (1..$#showncontents) {
				if ($criterion->($showncontents[$i]{name})) {
					$self->{_currentline} =
						$self->find_best_find_match(
							$self->{_position_at},
							$showncontents[$i-1]{name},
							$showncontents[$i  ]{name}
						)
						+ $i - 1 - $self->{_baseindex};
					last POSITION_ENTRY_FUZZY;
				}
			}
			$self->{_currentline} = $#showncontents - $self->{_baseindex};
		}
	}
	$self->{_position_at}    = '';
	$self->{_position_exact} = 0;
	$self->validate_position();
	$self->{_screen}->set_deferred_refresh($self->{_screen}->R_LISTING);
}

=item find_best_find_match(string $seek, string $first, string $second )

Decides which file out of two is the best match, I<e.g.> if there are
two files C<Contractor.php> and C<Dealer.php>, and 'Coz' is searched,
this method decides that C<Contractor.php> is the better match.

Returns 0 (first match is better) or 1 (second is better).

=cut

sub find_best_find_match {
	my ($self, $seek, $first, $second) = @_;
	my $char;
	if (lc $self->{_state}->sort_mode eq 'm') {
		# case-insensitive
		$first  = lc $first;
		$second = lc $second;
		$seek   = lc $seek;
	}
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

=item handlescroll(char $key)

Handles B<CTRL-E> and B<CTRL-Y>, which scroll the current view of
the directory.

=cut

sub handlescroll {
	my ($self, $key) = @_;
	my $up = ($key =~ /^\cE$/o);
	my $screenheight  = $self->{_screen}->screenheight;
	my $showncontents = $self->{_state}->directory->showncontents;
	return 0 if ( $up and
				  $self->{_baseindex} == $#$showncontents and
				  $self->{_currentline} == 0)
			 or (!$up and $self->{_baseindex} == 0);
	my $displacement = $up - ! $up;
	$self->{_baseindex} += $displacement;
	my $newcurrentline = $self->{_currentline} -= $displacement;
	if ($newcurrentline >= 0 and $newcurrentline <= $screenheight) {
		$self->{_currentline} = $newcurrentline;
	}
	$self->setview($self->{_currentline}, $self->{_baseindex});
	return 1;
}

=item handlemove(char $key)

Handles the keys which move around in the current directory.

=cut

sub handlemove {
	my ($self, $key) = @_;
	local $_ = $key;
	my $screenheight   = $self->{_screen}->screenheight;
	my $baseindex      = $self->{_baseindex};
	my $currentline    = $self->{_currentline};
	my $showncontents  = $self->{_state}->directory->showncontents;
	my $wheeljumpsize  = $self->{_config}->{mousewheeljumpsize};
	if ($wheeljumpsize eq 'variable') {
		$wheeljumpsize = sprintf('%d',
			0.5 + $#$showncontents / $self->{_config}->{mousewheeljumpratio});
		$wheeljumpsize = max(
			min(
				$wheeljumpsize,
				$self->{_config}->{mousewheeljumpmax},
			),
			$self->{_config}->{mousewheeljumpmin},
			1,
		);
	}
	my $displacement  =
			- (/^(?:ku|k|mshiftup)$/o    )
			+ (/^(?:kd|j|mshiftdown| )$/o)
			- (/^mup$/o  )		* $wheeljumpsize
			+ (/^mdown$/o)		* $wheeljumpsize
			- (/^-$/o)			* 10
			+ (/^\+$/o)			* 10
			- (/\cB|pgup/o)		* $screenheight
			+ (/\cF|pgdn/o)		* $screenheight
			- (/\cU/o)			* int($screenheight/2)
			+ (/\cD/o)			* int($screenheight/2)
			- (/^home$/o)		* ( $currentline +$baseindex)
			+ (/^end$/o )		* (-$currentline -$baseindex +$#$showncontents);
	$self->currentline($currentline + $displacement);
	# return 'handled' flag
	return $displacement ? 1 : 0;
}

=item handle(App::PFM::Event $event)

Attempts to handle the user event (keyboard- or mouse-input).
If unsuccessful, we return false.

=cut

sub handle {
	my ($self, $event) = @_;
	my $screenheight = $self->{_screen}->screenheight;
	my $handled = 0;
	my ($BASELINE, $dir);
	if ($event->{type} eq 'key' and
		$event->{data} =~ MOTION_COMMANDS_EXCEPT_SPACE)
	{
		$handled = $self->handlemove($event->{data});
	} elsif ($event->{type} eq 'key' and
			 $event->{data} =~ /^[\cE\cY]$/o)
	{
		$handled = $self->handlescroll($event->{data});
	} elsif ($event->{type} eq 'paste') {
#		$self->{_screen}->at(1,0)->puts("Pasted:$event->{data}:");
		$self->{_screen}->flash();
	} elsif ($event->{type} eq 'mouse' and
		$event->{mousebutton} == MOUSE_WHEEL_UP ||
		$event->{mousebutton} == MOUSE_WHEEL_DOWN
	) {
		if ($event->{mousebutton} == MOUSE_WHEEL_UP) {
			$dir = $event->{mousemodifier} == MOUSE_MODIFIER_SHIFT
				? 'mshiftup' : 'mup';
		} else { # MOUSE_WHEEL_DOWN
			$dir = $event->{mousemodifier} == MOUSE_MODIFIER_SHIFT
				? 'mshiftdown' : 'mdown';
		}
		$handled = $self->handlemove($dir);
	} else {
		if ($event->{type} eq 'mouse') {
			$BASELINE = $self->{_screen}->BASELINE;
			if ($event->{mouserow} >= $BASELINE and
				$event->{mouserow} <= $BASELINE + $screenheight)
			{
				# potentially on a fileline (might be diskinfo column though)
				$event->{mouseitem} =
					${$self->{_state}->directory->showncontents}[
						$self->{_baseindex} + $event->{mouserow} - $BASELINE
					];
			}
		}
		# pass it to the commandhandler
		$event->{name} = 'after_receive_non_motion_input';
		$event->{currentfile}             = $self->currentfile;
		$event->{lunchbox}{baseindex}     = $self->{_baseindex};
		$event->{lunchbox}{currentline}   = $self->{_currentline};
		# TODO
#		$event->{lunchbox}{showncontents} = $self->{_showncontents};
		$handled = $self->fire($event);
		# a space needs to be handled by both the CommandHandler
		# and the Browser
		if ($event->{type} eq 'key' and
			$event->{data} eq ' ')
		{
			$handled = $self->handlemove($event->{data});
		}
	}
	return $handled;
}

=item browse()

This sub, the main browse loop, is the heart of pfm. It has the
following structure:

  do {
    refresh the screen;
    wait for keypress-, mousedown- or resize-event;
    handle the request;
  } until quit was requested.

=cut

sub browse {
	my ($self) = @_;
	my ($event, $command_result);
	# prefetch objects
	my $screen  = $self->{_screen};
	my $listing = $screen->listing;
	until ($command_result eq 'quit') {
		$screen->refresh();
		$listing->highlight_on();
		# don't send mouse escapes to the terminal if not necessary
		$screen->bracketed_paste_on() if $self->{_config}{paste_protection};
		$screen->mouse_enable()
			if $self->{_mouse_mode} && $self->{_config}{mouseturnoff};
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
			$listing->highlight_off();
			$screen->bracketed_paste_off();
			$screen->mouse_disable() if $self->{_config}->{mouseturnoff};
			# the next line contains an assignment on purpose
			if ($command_result = $self->handle($event))
			{
				# if the received input was valid, then the current
				# cursor position must be validated again
				$screen->set_deferred_refresh($screen->R_STRIDE);
			}
		}
	}
}

##########################################################################

=back

=head1 EVENTS

This package implements the following events:

=over 2

=item after_receive_non_motion_input

Called when the input event is not a browsing event. Probably
the CommandHandler knows how to handle it.

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4: