#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::Files 0.10
#
# Name:			App::PFM::Browser::Files
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		2010-11-29
# Date:			2011-03-09
#

##########################################################################

=pod

=head1 NAME

App::PFM::Browser::Files

=head1 DESCRIPTION

This class is responsible for the file-specific part of browsing through
the filesystem.
It provides the Browser class with the necessary file data.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Browser::Files;

use base qw(App::PFM::Browser App::PFM::Abstract);

use strict;
use locale;

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
	$self->{_swap_mode}  = 0;
	$self->SUPER::_init($screen, $config);
	return;
}

##########################################################################
# constructor, getters and setters

=item browselist()

Getter for the listing that is to be shown.

=cut

sub browselist {
	my ($self) = @_;
	return $self->{_state}->directory->showncontents;
}

=item cursorcol()

Getter for the cursor column to be used in this browser.

=cut

sub cursorcol {
	my ($self) = @_;
	return $self->{_screen}->listing->cursorcol;
}

=item currentitem()

Getter for the file at the cursor position.

=cut

sub currentitem {
	my ($self) = @_;
	return $self->currentfile;
}

=item currentfile()

Getter for the file at the cursor position.

=cut

sub currentfile {
	my ($self) = @_;
	my $index  = $self->{_currentline} + $self->{_baseindex};
	return $self->browselist->[$index];
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

=item position_cursor( [ string $filename ] )

Positions the cursor at a specific file. Specifying a filename here
overrules the I<position_at> variable.

=cut

sub position_cursor {
	my ($self, $target) = @_;
	$self->{_position_at} = $target if (defined $target and $target ne '');
	return if $self->{_position_at} eq '';
	my @browselist        = @{$self->browselist};
	$self->{_currentline} = 0;
	$self->{_baseindex}   = 0 if $self->{_position_at} eq '..'; # descending
	POSITION_ENTRY: {
		for (0..$#browselist) {
			if ($self->{_position_at} eq $browselist[$_]{name}) {
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
	return;
}

=item position_cursor_fuzzy( [ string $filename ] )

Positions the cursor at the file with the closest matching name.
Used by incremental find.

=cut

sub position_cursor_fuzzy {
	my ($self, $target) = @_;
	$self->{_position_at} = $target if (defined $target and $target ne '');
	return if $self->{_position_at} eq '';

	my @browselist = @{$self->browselist};
	my ($criterion);

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
	if ($#browselist > 1) {
		POSITION_ENTRY_FUZZY: {
			for my $i (1..$#browselist) {
				if ($criterion->($browselist[$i]{name})) {
					$self->{_currentline} =
						$self->find_best_find_match(
							$self->{_position_at},
							$browselist[$i-1]{name},
							$browselist[$i  ]{name}
						)
						+ $i - 1 - $self->{_baseindex};
					last POSITION_ENTRY_FUZZY;
				}
			}
			$self->{_currentline} = $#browselist - $self->{_baseindex};
		}
	}
	$self->{_position_at}    = '';
	$self->{_position_exact} = 0;
	$self->validate_position();
	$self->{_screen}->set_deferred_refresh($self->{_screen}->R_LISTING);
	return;
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
			$event->{mouseitem} = ${$self->browselist}[
				$self->{_baseindex} + $event->{mouserow} - $BASELINE
			];
		}
	}
	# pass it to the commandhandler
	$event->{name} = 'after_receive_non_motion_input';
	$event->{currentfile}             = $self->currentfile;
	$event->{lunchbox}{baseindex}     = $self->{_baseindex};
	$event->{lunchbox}{currentline}   = $self->{_currentline};
	$res->{data}    = $self->fire($event);
	$res->{handled} = $res->{data} ? 1 : 0;
	# a space needs to be handled by both the CommandHandler
	# and the Browser
	if ($event->{type} eq 'key' and
		$event->{data} eq ' ')
	{
		$res->{handled} = $self->handlemove($event->{data});
	}
	return $res;
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

pfm(1), App::PFM::Browser(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
