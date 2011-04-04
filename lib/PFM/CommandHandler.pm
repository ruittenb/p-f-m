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

my ($_pfm, $_keyboard);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm      = $pfm;
	$_keyboard = new Term::ReadLine('pfm');
}

=item _credits()

Prints elaborate info about pfm. Called from help().

=cut

sub _credits {
	my $self = shift;
	$_pfm->screen->clrscr();
	$_pfm->screen->stty_raw($TERM_COOKED);
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
	$_pfm->screen->stty_raw($TERM_RAW)->getch();
}

=item handlepan()

Handle the pan keys B<E<lt>> and B<E<gt>>.

=cut

sub handlepan {
	my ($self, $key, $mode) = @_;
	$_pfm->screen->frame->pan($key, $mode);
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
