#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen::Listing 0.01
#
# Name:			PFM::Screen::Listing.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
#

##########################################################################

=pod

=head1 NAME

PFM::Screen::Listing

=head1 DESCRIPTION

PFM class for displaying a PFM::Directory object on the screen.

=head1 METHODS

=over

=cut

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

my ($_pfm, $_layout, $_cursorcol);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
}

# TODO
sub _validate_layoutnum {
	my ($self, $num) = @_;
	# TODO columnlayouts
	while ($num > $#columnlayouts) {
		$num -= @columnlayouts;
	}
	return $num;
}

##########################################################################
# constructor, getters and setters

=item layout()

Getter for the current layout number.

=cut

sub layout {
	return $_layout;
}

=item show_next_layout()

Switch the directory listing to the next configured layout.

=cut

sub show_next_layout {
	my ($self) = @_;
	my $screen = $self->_pfm->screen;
	$_layout   = $self->_validate_layoutnum($_layout + 1);
	$self->makeformatlines();
	$self->reformat();
	$screen->set_deferred_refresh($screen->R_SCREEN);
}

=item cursorcol()

Getter/setter for the current cursor column on-screen.

=cut

sub cursorcol {
	my ($self, $value) = @_;
	$_cursorcol = $value if defined $value;
	return $_cursorcol;
}

##########################################################################
# public subs

=item show()

Displays the directory listing.

=cut

# TODO massage
sub show {
	my $self = shift;
	my $contents = $_pfm->directory->showncontents;
	foreach my $i ($baseindex .. $baseindex+$screenheight) {
		unless ($i > $#contents) {
			$scr->at($i+$BASELINE-$baseindex,$filerecordcol)
				->puts(fileline($contents[$i], @layoutfields));
			applycolor($i+$BASELINE-$baseindex, $FILENAME_SHORT, %{$contents[$i]});
		} else {
			$scr->at($i+$BASELINE-$baseindex,$filerecordcol)
				->puts(' 'x($screenwidth - $infolength));
		}
	}
}
}
##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
