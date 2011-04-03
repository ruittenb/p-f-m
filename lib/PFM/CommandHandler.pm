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
# Description:	PFM class used for handling user commands
#

package PFM::CommandHandler;

use Term::ReadLine;

my ($_bootstrapped, $_keyboard);

##########################################################################
# private subs

sub _credits {
	my ($self, $pfm) = @_;
	$pfm->screen->clrscr();
	$pfm->screen->stty_raw($TERM_COOKED);
	my $name = $pfm->screen->colored('bold', 'pfm');
	print <<"_eoCredits_";


             $name for Unix and Unix-like OS's.  Version $pfm->{VERSION}
             Original idea/design: Paul R. Culley and Henk de Heer
             Author and Copyright (c) 1999-$self->{LASTYEAR} Rene Uittenbogaard


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
	$pfm->screen->stty_raw($TERM_RAW)->getch();
}

##########################################################################
# constructor, getters and setters

sub new {
	my $type = shift;
	$type    = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	return $self;
}

##########################################################################
# public subs

sub bootstrap {
	my $self = shift;
	carp("$self::".(caller(0))[3]."() cannot be called statically")
		unless ref $self;
	$self->{_kbd}          = new Term::ReadLine('pfm');
	$self->{_bootstrapped} = 1;
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
