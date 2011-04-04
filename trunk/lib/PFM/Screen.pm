#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen 2010-03-27 v0.01
#
# Name:			PFM::Screen.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Requires:		Term::ScreenColor
# Description:	PFM class used for controlling the screen.
#

##########################################################################
# declarations

package PFM::Screen;

use base qw(PFM::Abstract Term::ScreenColor);

use PFM::Screen::Frame;
use PFM::Screen::Listing;

use constant {
	PATHLINE		=> 1,
	BASELINE		=> 3,
	DISKINFOLINE	=> 4,
	DIRINFOLINE		=> 9,
	MARKINFOLINE	=> 15,
	USERINFOLINE	=> 21,
	DATEINFOLINE	=> 22,
	R_NOP			=> 0,
	R_STRIDE		=> 1,
	R_MENU			=> 2,
	R_PATHINFO		=> 4,
	R_HEADINGS		=> 8,
	R_FOOTER		=> 16,
	R_DIRFILTER		=> 32,
	R_DIRLIST		=> 64,
	R_DISKINFO		=> 128,
	R_DIRSORT		=> 256,
	R_CLEAR			=> 512,
	R_DIRCONTENTS	=> 1024,
	R_NEWDIR		=> 2048,
	R_INIT_SWAP		=> 4096,
	R_QUIT			=> 1048576,
};

# needs a second invocation because of the calculations
use constant {
	R_FRAME		=> R_MENU | R_PATHINFO | R_TITLE | R_FOOTER,
	R_SCREEN	=> R_DIRFILTER | R_DIRLIST | R_DISKINFO | R_FRAME,
	R_CLRSCR	=> R_CLEAR | R_SCREEN,
	R_CHDIR		=> R_NEWDIR | R_DIRCONTENTS | R_DIRSORT | R_SCREEN | R_STRIDE,
};

my ($_pfm, $_frame, $_screenwidth, $_screenheight, $_deferred_refresh);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm     = $pfm;
	$_frame   = new PFM::Screen::Frame($pfm);
	$_listing = new PFM::Screen::Listing($pfm);
}

##########################################################################
# constructor, getters and setters

sub screenwidth {
	my ($self, $value) = @_;
	$_screenwidth = $value if defined $value;
	return $_screenwidth;
}

sub screenheight {
	my ($self, $value) = @_;
	$_screenheight = $value if defined $value;
	return $_screenheight;
}

=item frame()

Getter for the PFM::Screen::Frame object.

=cut

sub frame {
	return $_frame;
}

=item listing()

Getter for the PFM::Screen::Listing object.

=cut

sub listing {
	return $_listing;
}

##########################################################################
# public subs

sub recalculate_dimensions {
	my $self = shift;
	if ($self->rows()) { $_screenheight = $self->rows() - BASELINE - 2 }
	if ($self->cols()) { $_screenwidth  = $self->cols() }
	return $self;
}

sub stty_raw {
	my $self = shift;
	system qw(stty raw -echo);
	$self->noecho();
}

sub stty_cooked {
	my $self = shift;
	system qw(stty -raw echo);
	$self->echo();
}

sub mouse_enable {
	my $self = shift;
	print "\e[?9h";
	return $self;
}

sub mouse_disable {
	my $self = shift;
	print "\e[?9l";
	return $self;
}

sub alternate_on {
	my $self = shift;
	print "\e[?47h";
	return $self;
}

sub alternate_off {
	my $self = shift;
	print "\e[?47l";
	return $self;
}

sub putcentered {
	my ($self, $string) = @_;
	$self->puts(' ' x (($_screenwidth - length $string)/2) . $string);
}

sub draw_frame {
	my $self = shift;
	$_frame->draw();
	return $self;
}

sub set_deferred_refresh {
	my ($self, $bits) = @_;
	$_deferred_refresh |= $bits;
	return $self;
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
