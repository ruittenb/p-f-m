#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Browser::YourCommands 0.08
#
# Name:			App::PFM::Browser::YourCommands
# Version:		0.08
# Author:		Rene Uittenbogaard
# Created:		2011-03-09
# Date:			2011-03-13
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
	SHOW_CLOCK => 0,
	SCREENTYPE => R_DISKINFO,
	HEADERTYPE => HEADING_YCOMMAND,
	FOOTERTYPE => FOOTER_NONE,
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
	$self->{_state}      = $state;
	$self->{_prompt}     = '';
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
	my ($self)     = @_;
	my $screen     = $self->{_screen};
	my $printline  = $screen->BASELINE;
	my $infocol    = $screen->diskinfo->infocol;
	my $infolength = $screen->diskinfo->infolength;
	my $spacing    = ' ' x $infolength;
	my $browselist = $self->browselist;
	my ($commandkey, $printstr);
	# headings
	$screen
		->set_deferred_refresh(R_DISKINFO | R_FRAME)
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
		$commandkey = $browselist->[$_];
		$printstr = $self->{_config}->your($commandkey);
		$printstr =~ s/\e/^[/g; # in case real escapes are used
		$screen->at($printline++, $infocol)
			->puts(sprintf('%1s %s',
					$commandkey,
					substr($printstr . $spacing, 0, $infolength - 2)));
	}
	foreach ($printline .. $screen->BASELINE + $screen->screenheight) {
		$screen->at($printline++, $infocol)->puts($spacing);
	}
	$screen->at($self->{_currentline} + $screen->BASELINE, $infocol);
	return;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::Browser(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
