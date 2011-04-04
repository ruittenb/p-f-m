#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen::Listing 2010-03-27 v0.01
#
# Name:			PFM::Screen::Listing.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	PFM Listing class, handles the display of a
#				PFM::Directory object on screen
#

##########################################################################
# declarations

package PFM::Screen::Listing;

use base 'PFM::Abstract';

use constant FILETYPEFLAGS => {
	# ls(1)
	x => '*',
	d => '/',
	l => '@',
	p => '|',
   's'=> '=',
	D => '>',
	w => '%',
	# tcsh(1)
	b => '#',
	c => '%',
	n => ':',
	# => '+', # Hidden directory (AIX only) or context dependent (HP/UX only)
};

my ($_pfm, $_layout);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
}

##########################################################################
# constructor, getters and setters

=item layout()

Getter/setter for the current layout.

=cut

sub layout {
	my ($self, $value) = @_;
	if (defined $value) {
		my $screen = $self->_pfm->screen;
		$_layout = $self->validate_layoutnum($value);
		$self->makeformatlines();
		$self->reformat();
		$screen->set_deferred_refresh($screen->R_SCREEN);
	}
	return $_layout;
}

sub show_next_layout {
	my ($self) = @_;
	return $self->layout($_layout + 1);
}

sub validate_layoutnum {
	my ($self, $num) = @_;
	# TODO columnlayouts
	while ($num > $#columnlayouts) {
		$num -= @columnlayouts;
	}
	return $num;
}

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
