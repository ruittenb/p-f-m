#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser 0.59
#
# Name:			App::PFM::Browser
# Version:		0.59
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2011-03-12
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

use App::PFM::Screen::Frame qw(:constants); # MENU_*, HEADING_*, and FOOTER_*
use App::PFM::Screen        qw(:constants); # R_*
use App::PFM::Util          qw(min max);

use strict;
use locale;

use constant {
	SHOW_CLOCK        => 1,
	SCREENTYPE        => R_LISTING,
	HEADERTYPE        => HEADING_DISKINFO,
	BROWSE_VOID_LINES => 10,
};

use constant MOTION_COMMANDS_EXCEPT_SPACE =>
	qr/^(?:[-+jk\cF\cB\cD\cU]|ku|kd|pgup|pgdn|home|end)$/io;

##########################################################################
# private subs

=item _init(App::PFM::Screen $screen, App::PFM::Config $config)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $screen, $config) = @_;
	$self->{_screen}		 = $screen;
	$self->{_config}		 = $config;
	$self->{_currentline}	 = 0;
	$self->{_baseindex}		 = 0;
	$self->{_position_at}	 = '';
	$self->{_position_exact} = 0;
	$self->{_mouse_mode}	 = undef;

	my $on_after_resize_window = sub {
#		my ($event) = @_;
		$self->validate_position();
	};
	$screen->register_listener('after_resize_window', $on_after_resize_window);
	return;
}

=item _wait_loop()

Waits for keyboard input. In unused time, poll jobs and update
the on-screen clock.

=cut

sub _wait_loop {
	my ($self) = @_;
	my $screen     = $self->{_screen};
	my $screenline = $self->{_currentline} + $screen->BASELINE;
	my $cursorcol  = $self->cursorcol;
	my $event_idle = App::PFM::Event->new({
		name   => 'browser_idle',
		origin => $self,
		type   => 'soft',
	});
	until ($screen->pending_input(0.4)) {
		$self->fire($event_idle);
		$screen->refresh_headings()
			->at($screenline, $cursorcol);
		return if $screen->pending_input(0.6);
		if ($self->SHOW_CLOCK) {
			$screen->diskinfo->clock_info();
		}
		$screen->at($screenline, $cursorcol);
	}
	return;
}

##########################################################################
# constructor, getters and setters

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
#		$self->{_screen}->set_deferred_refresh($self->{_screen}->R_LISTING);
	}
	return $self->{_baseindex};
}

=item setview(int $lineno, int $index)

Getter/setter for both the cursor line and screen window at once.
Used by handlescroll().

=cut

sub setview {
	my ($self, $line, $index) = @_;
	return 0 unless (defined($line) && defined($index));
	$self->{_currentline} = $line;
	$self->{_baseindex}   = $index;
	$self->validate_position();
	$self->{_screen}->set_deferred_refresh($self->SCREENTYPE);
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

##########################################################################
# public subs

=item validate_position()

Checks if the current cursor position and the current file lie within
the screen window. If not, the screen window is repositioned so that the
cursor is on-screen.

=cut

sub validate_position {
	my ($self) = @_;
	my $screenheight = $self->{_screen}->screenheight;
	my $oldbaseindex = $self->{_baseindex};
	my @browselist   = @{$self->browselist};
	my $browsemax    = $#browselist + $self->BROWSE_VOID_LINES;
	
	# first make sure the currentline is not way beyond the end of the list,
	# otherwise, we would end up with a large empty space
	if ($self->{_currentline} + $self->{_baseindex} > $browsemax) {
		$self->{_currentline} = $browsemax - $self->{_baseindex};
	}
	# if the currentline has moved off the screen, scroll so that
	# it becomes visible again
	if ($self->{_currentline} < 0) {
		$self->{_baseindex}  += $self->{_currentline};
		$self->{_baseindex}   < 0 and $self->{_baseindex} = 0;
		$self->{_currentline} = 0;
	}
	if ($self->{_currentline} > $screenheight) {
		$self->{_baseindex}  += $self->{_currentline} - $screenheight;
		$self->{_currentline} = $screenheight;
	}
	# make sure the browse window is not beyond the end of the list
	if ($self->{_baseindex} > $#browselist) {
		$self->{_currentline} += $self->{_baseindex} - $#browselist;
		$self->{_baseindex}    = $#browselist;
	}
	# make sure the currentline is not beyond the end of the list
	if ($self->{_currentline} + $self->{_baseindex} > $#browselist) {
		$self->{_currentline} = $#browselist - $self->{_baseindex};
	}
	# See if we need to refresh the listing.
	# By limiting the number of listing-refreshes to when the baseindex
	# has been changed, browsing becomes snappier.
	if ($oldbaseindex != $self->{_baseindex}) {
		$self->{_screen}->set_deferred_refresh($self->SCREENTYPE);
	}
	return;
}

=item handlescroll(char $key)

Handles B<CTRL-E> and B<CTRL-Y>, which scroll the current view of
the directory.

=cut

sub handlescroll {
	my ($self, $key) = @_;
	my $up = ($key =~ /^\cE$/o);
	my $screenheight = $self->{_screen}->screenheight;
	my $browselist   = $self->browselist;
	return 0 if ( $up and
				  $self->{_baseindex} == $#$browselist and
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
	my $browselist     = $self->browselist;
	my $wheeljumpsize  = $self->{_config}->{mousewheeljumpsize};
	if ($wheeljumpsize eq 'variable') {
		$wheeljumpsize = sprintf('%d',
			0.5 + $#$browselist / $self->{_config}->{mousewheeljumpratio});
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
			+ (/^end$/o )		* (-$currentline -$baseindex +$#$browselist);
	$self->currentline($currentline + $displacement);
	# return 'handled' flag
	return $displacement ? 1 : 0;
}

=item handle(App::PFM::Event $event)

Attempts to handle the user event (keyboard- or mouse-input).
Returns a hash reference with a member 'handled' indicating if this
was successful, and a member 'data' with additional data (like
the string 'quit' in case the user requested an application quit).

=cut

sub handle {
	my ($self, $event) = @_;
	my $screenheight = $self->{_screen}->screenheight;
	my $res = {};
	my ($BASELINE, $dir);
	if ($event->{type} eq 'key' and
		$event->{data} =~ $self->MOTION_COMMANDS_EXCEPT_SPACE)
	{
		$res->{handled} = $self->handlemove($event->{data});
	} elsif ($event->{type} eq 'key' and
			 $event->{data} =~ /^[\cE\cY]$/o)
	{
		$res->{handled} = $self->handlescroll($event->{data});
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
		$res->{handled} = $self->handlemove($dir);
	} else {
		$res = $self->handle_non_motion_input($event);
	}
	return $res;
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
	my ($choice, $event);
	# prefetch objects
	my $screen  = $self->{_screen};
	my $listing = $screen->listing;
	do {
		$screen->refresh();
		$listing->highlight_on();
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
			$listing->highlight_off();
			$screen->bracketed_paste_off();
			$screen->mouse_disable();
			$choice = $self->handle($event);
			if ($choice->{handled}) {
				# if the received input was valid, then the current
				# cursor position must be validated again
				$screen->set_deferred_refresh($screen->R_STRIDE);
			}
		}
	} until ($choice->{data} eq 'quit');
	return $choice->{data};
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

pfm(1), App::PFM::Browser::Files(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
