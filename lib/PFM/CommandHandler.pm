#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::CommandHandler 2010-03-27 v0.01
#
# Name:			PFM::CommandHandler.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM class used for executing user commands
#

##########################################################################
# declarations

package PFM::CommandHandler;

use base 'PFM::Abstract';

use Term::ReadLine;
use Config;

my ($_pfm,
	@_signame, $_white_cmd, @_unwo_cmd);

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
	$_pfm->screen->clrscr();
	$_pfm->screen->stty_raw($_pfm->screen->TERM_COOKED);
	my $name = $_pfm->screen->colored('bold', 'pfm');
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
	$_pfm->screen->stty_raw($_pfm->screen->TERM_RAW)->getch();
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item whitesupport()

Returns a boolean indicating if this system supports whiteout commands.

=cut

sub whitesupport {
	return ($_white_cmd ne '');
}

=item handlepan()

Handle the pan keys B<E<lt>> and B<E<gt>>.

=cut

sub handlepan {
	my ($self, $key, $mode) = @_;
	$_pfm->screen->frame->pan($key, $mode);
}

sub handlelayouts {
	my $self = shift;
	$_pfm->screen->listing->show_next_layout();
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
