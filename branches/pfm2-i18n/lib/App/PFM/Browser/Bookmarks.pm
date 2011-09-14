#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::Bookmarks 0.10
#
# Name:			App::PFM::Browser::Bookmarks
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		2010-12-01
# Date:			2011-03-20
#

##########################################################################

=pod

=head1 NAME

App::PFM::Browser::Bookmarks

=head1 DESCRIPTION

This class is responsible for the browsing functionality that is specific
for browsing through bookmarks and selecting one.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Browser::Bookmarks;

use base qw(App::PFM::Browser::Chooser App::PFM::Abstract);

use App::PFM::Screen::Frame qw(:constants); # MENU_*, HEADING_*, and FOOTER_*
use App::PFM::Screen        qw(:constants); # R_*
use App::PFM::Util			qw(fitpath);

use strict;
use locale;

use constant {
	SHOW_MARKCURRENT => '',
	SHOW_CLOCK       => 1,
	SCREENTYPE       => R_LISTING,
	HEADINGTYPE      => HEADING_BOOKMARKS,
	FOOTERTYPE       => FOOTER_NONE,
	SPAWNEDCHAR      => '*',
};

use constant MOTION_COMMANDS_EXCEPT_SPACE =>
	qr/^(?:[-+\cF\cB\cD\cU]|ku|kd|pgup|pgdn|home|end)$/io; # no 'j', 'k'

##########################################################################
# private subs

=item _init(App::PFM::Screen $screen, App::PFM::Config $config,
hashref $states)

Initializes new instances. Called from the constructor.
Stores the application's array of states internally.

=cut

sub _init {
	my ($self, $screen, $config, $states) = @_;
	$self->{_states} = $states;
	$self->SUPER::_init($screen, $config);
	return;
}

##########################################################################
# constructor, getters and setters

=item browselist()

Getter for the key listing (a..z, A..Z, 0..9) that is to be shown.

=cut

sub browselist {
	my ($self) = @_;
	return $self->{_config}->BOOKMARKKEYS;
}

=item cursorcol()

Getter for the cursor column to be used in this browser.

=cut

sub cursorcol {
	my ($self) = @_;
	return $self->{_screen}->listing->bookmarkpathcol;
}

=item currentitem()

Getter for the bookmark at the cursor position.

=cut

sub currentitem {
	my ($self) = @_;
	my $index  = $self->{_currentline} + $self->{_baseindex};
	my $key    = $self->browselist->[$index];
	return $self->{_states}{$key};
}

##########################################################################
# public subs

=item list_items()

Lists the bookmarks from the hash of states. Calls show_item() to display
each item.

=cut

sub list_items {
	my ($self)  = @_;
	my $screen  = $self->{_screen};
	my @heading = $screen->frame->bookmark_headings;

	$self->{_browselist} = $self->browselist;
	$self->{_itemcol}    = $screen->listing->bookmarkpathcol;
	$self->{_itemlen}    = $heading[2];
	$self->{_template}   = $heading[0];
	my $spacing          = ' ' x $self->{_itemlen};
	my $total            = @{$self->{_browselist}};

	# headings
	$screen
		->set_deferred_refresh(R_SCREEN)
		->show_frame({
			headings => $self->HEADINGTYPE,
			footer   => $self->FOOTERTYPE,
			prompt   => $self->{_prompt},
		});
	# list bookmarks
	foreach (0 .. $screen->screenheight) {
		if ($self->{_baseindex} + $_ <= $total) {
			$self->show_item($_);
		} else {
			$screen->at($screen->BASELINE + $_, $self->{_itemcol})
				->puts($spacing);
		}
	}
	$screen->at($self->{_currentline} + $screen->BASELINE, $self->cursorcol);
	return;
}

=item show_item(int $which, boolean $highlight)

Shows one bookmark item. Applies highlighting if the I<highlight> argument
is true.

=cut

sub show_item {
	my ($self, $which, $highlight) = @_;
	my ($dest, $spawned, $overflow, $bookmarkkey, $printstring);
	my $screen    = $self->{_screen};
	my $linecolor = $highlight
		? $self->{_config}{framecolors}{$screen->color_mode}{highlight}
		: '';

	$bookmarkkey = $self->{_browselist}[$self->{_baseindex} + $which];
	$dest        = ${$self->{_states}}{$bookmarkkey};
	$spawned     = ' ';
	if (ref $dest) {
		$dest    = $dest->directory->path . '/' . $dest->{_position};
		$dest    =~ s{/\.$}{/};
		$dest    =~ s{^//}{/};
		$spawned = SPAWNEDCHAR;
	}
	if (length($dest)) {
		($dest, undef, $overflow) = fitpath($dest, $self->{_itemlen});
		$dest .= ($overflow ? $screen->listing->NAMETOOLONGCHAR : ' ');
	}
	$printstring = sprintf($self->{_template}, $bookmarkkey, $spawned, $dest);
	$screen->at($screen->BASELINE + $which, $self->{_itemcol})
		->putcolored($linecolor, $printstring);
	return;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Browser(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
