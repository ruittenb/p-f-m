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

my ($_pfm, $_currentline, $_baseindex, $_position_at);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm			 = $pfm;
	$_currentline	 = 0;
	$_baseindex		 = 0;
	$_position_at    = '.';
}

sub _wait_loop {
}

##########################################################################
# constructor, getters and setters

=item position_at()

Getter/setter for the position_at variable, which controls to which file
the cursor should go as soon as the main browse loop is resumed.

=cut

sub position_at {
	my ($self, $value) = @_;
	$_position_at = $value if defined $value;
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
		$_pfm->screen->refresh();
		$event = $self->_wait_loop();
		$quit  = $_pfm->commandhandler->handle($event);
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

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
