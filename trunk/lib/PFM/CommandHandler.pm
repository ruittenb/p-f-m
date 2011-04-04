#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::CommandHandler 0.01
#
# Name:			PFM::CommandHandler.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
#

##########################################################################

=pod

=head1 NAME

PFM::CommandHandler

=head1 DESCRIPTION

PFM Class for executing user commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::CommandHandler;

use base 'PFM::Abstract';

use POSIX qw(strftime mktime);
use Config;

use strict;

my ($_pfm,
	@_signame, $_white_cmd, @_unwo_cmd, $_clobber_mode);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
	$self->_init_signames();
	$self->_init_white_commands();
}

=item _init_signames()

Initializes the array of signal names. Called from _init().

=cut

sub _init_signames {
	my $self = shift;
	my $i = 0;
	foreach (split(/ /, $Config{sig_name})) {
		$_signame[$i++] = $_;
	}
}

=item _init_white_commands()

Finds out which commands should be used for listing and deleting whiteouts.
Called from _init().

=cut

sub _init_white_commands {
	my $self = shift;
	my $white_cmd = '';
	my @unwo_cmd  = ();
	foreach (split /:/, $ENV{PATH}) {
		if (!@unwo_cmd) {
			if (-f "$_/unwhiteout") {
				@unwo_cmd = qw(unwhiteout);
			} elsif (-f "$_/unwo") {
				@unwo_cmd = qw(unwo);
			}
		}
		if (!$white_cmd) {
			if (-f "$_/listwhite") {
				$white_cmd = 'listwhite';
			} elsif (-f "$_/lsw") {
				$white_cmd = 'lsw';
			}
		}
	}
	unless (@unwo_cmd) {
		@unwo_cmd = qw(rm -W);
	}
	$_white_cmd = $white_cmd;
	@_unwo_cmd  = @unwo_cmd;
}

=item _credits()

Prints elaborate info about pfm. Called from help().

=cut

sub _credits {
	my $self = shift;
	my $screen = $_pfm->screen;
	$screen->clrscr();
	$screen->stty_raw($screen->TERM_COOKED);
	my $name = $screen->colored('bold', 'pfm');
	print <<"_eoCredits_";


             $name for Unix and Unix-like OS's.  Version $_pfm->{VERSION}
             Original idea/design: Paul R. Culley and Henk de Heer
             Author and Copyright (c) 1999-$_pfm->{LASTYEAR} Rene Uittenbogaard


       $name is distributed under the GNU General Public License version 2.
                    $name is distributed without any warranty,
             even without the implied warranties of merchantability
                      or fitness for a particular purpose.
                   Please read the file COPYING for details.

      You are encouraged to copy and share this program with other users.
   Any bug, comment or suggestion is welcome in order to update this product.

    New versions may be obtained from http://sourceforge.net/projects/p-f-m/

                For questions, remarks or suggestions about $name,
                 send email to: ruittenb\@users.sourceforge.net


                                                         any key to exit to $name
_eoCredits_
	$screen->stty_raw($screen->TERM_RAW)->getch();
}

##########################################################################
# constructor, getters and setters

=item whitecommand()

Getter for the command for listing whiteouts.

=cut

sub whitecommand {
	return $_white_cmd;
}

=item clobber_mode()

Getter/setter for the clobber mode, which determines if files will be
overwritten without confirmation.

=cut

sub clobber_mode {
	my ($self, $value) = @_;
	$_clobber_mode = $value if defined $value;
	return $_clobber_mode;
}

##########################################################################
# public subs

=item handle()

Finds out how an event should be handled, and acts on it.

=cut

sub handle {
	# TODO
}

=item handlepan()

Handles the pan keys B<E<lt>> and B<E<gt>>.

=cut

sub handlepan {
	my ($self, $key, $mode) = @_;
	$_pfm->screen->frame->pan($key, $mode);
}

=item handlelayouts()

Handles moving on to the next configured layout.

=cut

sub handlelayouts {
	my $self = shift;
	$_pfm->screen->listing->show_next_layout();
}

=item handlefit()

Recalculate the screen size and adjust the layouts.

=cut

sub handlefit {
	my $self = shift;
	$_pfm->screen->fit();
}


##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
