#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::YourCommands 0.09
#
# Name:			App::PFM::Browser::YourCommands
# Version:		0.09
# Author:		Rene Uittenbogaard
# Created:		2011-03-09
# Date:			2011-03-18
#

##########################################################################

=pod

=head1 NAME

App::PFM::Browser::YourCommands

=head1 DESCRIPTION

This class is responsible for the browsing functionality that is specific
for browsing through Your commands and selecting one.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Browser::YourCommands;

use base qw(App::PFM::Browser::Chooser App::PFM::Abstract);

use App::PFM::Screen::Frame qw(:constants); # MENU_*, HEADING_*, and FOOTER_*
use App::PFM::Screen        qw(:constants); # R_*
use App::PFM::Util          qw(alphabetically letters_then_numbers);

use strict;
use locale;

use constant {
	SHOW_MARKCURRENT => 'Y',
	SHOW_CLOCK       => 0,
	SCREENTYPE       => R_DISKINFO,
	HEADERTYPE       => HEADING_YCOMMAND,
	FOOTERTYPE       => FOOTER_NONE,
};

use constant MOTION_COMMANDS_EXCEPT_SPACE =>
	qr/^(?:[-+\cF\cB\cD\cU]|ku|kd|pgup|pgdn|home|end)$/io; # no 'j', 'k'

##########################################################################
# private subs

=item _init(App::PFM::Screen $screen, App::PFM::Config $config,
App::PFM::State $state)

Initializes new instances. Called from the constructor.
Stores the application's current state internally.

=cut

sub _init {
	my ($self, $screen, $config, $state) = @_;
	$self->{_state} = $state;
	$self->SUPER::_init($screen, $config);
	return;
}

##########################################################################
# constructor, getters and setters

=item browselist()

Getter for the key listing (A, a, B, b, ... Z, z) that is to be shown.

=cut

sub browselist {
	my ($self) = @_;
	return [
		sort {
			letters_then_numbers($a, $b)
		} $self->{_config}->your_commands
	];
}

=item cursorcol()

Getter for the cursor column to be used in this browser.

=cut

sub cursorcol {
	my ($self) = @_;
	return $self->{_screen}->diskinfo->infocol;
}

=item currentitem()

Getter for the Your command at the cursor position.

=cut

sub currentitem {
	my ($self) = @_;
	my $index  = $self->{_currentline} + $self->{_baseindex};
	my $key    = $self->browselist->[$index];
	return $self->{_config}->your_commands->{$key};
}

##########################################################################
# public subs

=item list_items()

List the Your commands from the App::PFM::Config object.

=cut

sub list_items {
	my ($self)  = @_;
	my $screen  = $self->{_screen};

	$self->{_browselist} = $self->browselist;
	$self->{_itemcol}    = $screen->diskinfo->infocol;
	$self->{_itemlen}    = $screen->diskinfo->infolength;
	my $fieldlen         = $self->{_itemlen} - 2;
	$self->{_template}   = "%1s %-${fieldlen}.${fieldlen}s";
	my $spacing          = ' ' x $self->{_itemlen};
	my $total            = @{$self->{_browselist}};

	# headings
	$screen
		->set_deferred_refresh(R_DISKINFO | R_FRAME)
		->show_frame({
			headings => $self->HEADERTYPE,
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

Shows one Your command item. Applies highlighting if the I<highlight> argument
is true.

=cut

sub show_item {
	my ($self, $which, $highlight) = @_;
	my ($commandkey, $printstring);
	my $screen    = $self->{_screen};
	my $linecolor = $highlight
		? $self->{_config}{framecolors}{$screen->color_mode}{highlight}
		: '';

	$commandkey  = $self->{_browselist}[$self->{_baseindex} + $which];
	$printstring = $self->{_config}->your($commandkey);
	$printstring =~ s/\e/^[/g; # in case real escapes are used
	$printstring = sprintf($self->{_template}, $commandkey, $printstring);
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
