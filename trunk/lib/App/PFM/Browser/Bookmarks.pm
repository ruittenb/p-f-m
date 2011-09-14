#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::Bookmarks 0.07
#
# Name:			App::PFM::Browser::Bookmarks
# Version:		0.07
# Author:		Rene Uittenbogaard
# Created:		2010-12-01
# Date:			2011-03-12
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
	SHOW_CLOCK  => 1,
	SCREENTYPE  => R_LISTING,
	HEADERTYPE  => HEADING_BOOKMARKS,
	FOOTERTYPE  => FOOTER_NONE,
	SPAWNEDCHAR => '*',
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
	$self->{_prompt} = '';
	$self->SUPER::_init($screen, $config);
	return;
}

##########################################################################
# constructor, getters and setters

=item browselist()

Getter for the key listing (a..z, A..Z) that is to be shown.

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

List the bookmarks from the hash of states.

=cut

sub list_items {
	my ($self)          = @_;
	my $screen          = $self->{_screen};
	my $printline       = $screen->BASELINE;
	my $bookmarkpathcol = $screen->listing->bookmarkpathcol;
	my @heading         = $screen->frame->bookmark_headings;
	my $bookmarkpathlen = $heading[2];
	my $spacing         =
		' ' x ($screen->screenwidth - $screen->diskinfo->infolength);
	my ($dest, $spawned, $overflow, $bookmarkkey);
	# headings
	$screen
		->set_deferred_refresh(R_SCREEN)
		->show_frame({
			headings => $self->HEADERTYPE,
			footer   => $self->FOOTERTYPE,
			prompt   => $self->{_prompt},
		});
	# list bookmarks
	foreach (
		$self->{_baseindex} .. $self->{_baseindex} + $screen->screenheight
	) {
		last if ($printline > $screen->BASELINE + $screen->screenheight);
		$bookmarkkey = ${$self->{_config}->BOOKMARKKEYS}[$_];
		$dest        = ${$self->{_states}}{$bookmarkkey};
		$spawned     = ' ';
		if (ref $dest) {
			$dest    = $dest->directory->path . '/' . $dest->{_position};
			$dest    =~ s{/\.$}{/};
			$dest    =~ s{^//}{/};
			$spawned = SPAWNEDCHAR;
		}
		if (length($dest)) {
			($dest, undef, $overflow) = fitpath($dest, $bookmarkpathlen);
			$dest .= ($overflow ? $screen->listing->NAMETOOLONGCHAR : ' ');
		}
		$screen->at($printline++, $bookmarkpathcol)
			->puts(sprintf($heading[0], $bookmarkkey, $spawned, $dest));
	}
	foreach ($printline .. $screen->BASELINE + $screen->screenheight) {
		$screen->at($printline++, $bookmarkpathcol)->puts($spacing);
	}
	$screen->at($self->{_currentline} + $screen->BASELINE, $bookmarkpathcol);
	return;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Browser(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
