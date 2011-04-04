#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Browser 2010-03-27 v0.01
#
# Name:			PFM::Browser.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Browser class. This class is responsible for
#				executing the main browsing loop:
#				- wait for keypress
#				- dispatch command to CommandHandler
#				- refresh screen
#

##########################################################################
# declarations

package PFM::Browser;

use base 'PFM::Abstract';

my ($_pfm, $_currentline, $_baseindex);
my $position_at = '.';   # start with cursor here # TODO???

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm)	= @_;
	$_pfm				= $pfm;
	$_currentline		= 0;
	$_baseindex			= 0;
}

sub _wait_loop {
}

##########################################################################
# constructor, getters and setters

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
		$quit  = $_pfm->commandhandler($event);
	}
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
